"""Router สำหรับการแจ้งเตือน (Alerts) และภาพรวมองค์กรแบบไม่ระบุตัวตน (Corporate Aggregate)"""
from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import alerts as alert_rules
from ..db import get_db
from ..deps import MIN_GROUP_SIZE, current_staff, iso, patient_for_staff, require_individual_access, utc
from ..models import Alert, AuditLog, BpReading, Device, Organization, Patient, StaffUser, VitalSample
from ..schemas import AckIn, NotificationSettingsIn

router = APIRouter()


@router.get("/v1/staff/alerts")
def list_alerts(open_only: bool = True, s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    require_individual_access(s)
    q = (
        select(Alert, Patient.display_name)
        .join(Patient, Patient.id == Alert.patient_id)
        .where(Patient.org_id == s.org_id)
        .order_by(Alert.created_at.desc())
        .limit(200)
    )
    if open_only:
        q = q.where(Alert.acknowledged_at.is_(None))
    return [
        {
            "id": a.id,
            "patient_id": a.patient_id,
            "patient_name": n,
            "level": a.level,
            "kind": a.kind,
            "message": a.message,
            "created_at": iso(a.created_at),
            "acknowledged_at": iso(a.acknowledged_at),
            "note": a.note,
        }
        for a, n in db.execute(q).all()
    ]


@router.post("/v1/staff/alerts/{aid}/ack")
def ack_alert(aid: int, body: AckIn, s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    a = db.get(Alert, aid)
    if not a:
        raise HTTPException(404, "ไม่พบการแจ้งเตือน")
    patient_for_staff(db, s, a.patient_id)
    a.acknowledged_by, a.acknowledged_at, a.note = s.id, datetime.now(timezone.utc), body.note
    db.commit()
    return {"ok": True}


@router.get("/v1/staff/org/aggregate")
def org_aggregate(s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    if s.role not in ("admin", "hr_viewer", "clinician"):
        raise HTTPException(403, "ไม่มีสิทธิ์")
    now = datetime.now(timezone.utc)
    pids = [i for (i,) in db.execute(select(Patient.id).where(Patient.org_id == s.org_id, Patient.active))]
    n = len(pids)
    if n < MIN_GROUP_SIZE:
        return {
            "participants": n,
            "suppressed": True,
            "message": f"มีผู้เข้าร่วมน้อยกว่า {MIN_GROUP_SIZE} คน จึงไม่แสดงสถิติเพื่อปกป้องความเป็นส่วนตัว",
        }

    active7 = (
        db.execute(
            select(func.count(func.distinct(Device.patient_id))).where(
                Device.patient_id.in_(pids), Device.last_seen >= now - timedelta(days=7)
            )
        ).scalar()
        or 0
    )

    cats = Counter()
    for pid in pids:
        b = db.execute(
            select(BpReading)
            .where(BpReading.patient_id == pid, BpReading.measured_at >= now - timedelta(days=30))
            .order_by(BpReading.measured_at.desc())
            .limit(1)
        ).scalar()
        if not b:
            cats["no_data"] += 1
        elif b.systolic >= 140 or b.diastolic >= 90:
            cats["high"] += 1
        elif b.systolic >= 130 or b.diastolic >= 85:
            cats["elevated"] += 1
        else:
            cats["normal"] += 1

    steps = defaultdict(float)
    for pid, at, v in db.execute(
        select(VitalSample.patient_id, VitalSample.at, VitalSample.value).where(
            VitalSample.patient_id.in_(pids), VitalSample.metric == "steps", VitalSample.at >= now - timedelta(days=7)
        )
    ):
        steps[(pid, utc(at).date())] += v
    avg_steps = round(sum(steps.values()) / len(steps)) if steps else None

    db.add(AuditLog(actor=f"staff:{s.id}", action="org_aggregate"))
    db.commit()
    # ไม่แสดงหมวดที่มีจำนวนน้อย (1-4 คน) เพื่อไม่ให้เดาตัวบุคคลได้
    safe = {k: (v if v == 0 or v >= MIN_GROUP_SIZE else f"<{MIN_GROUP_SIZE}") for k, v in cats.items()}
    return {
        "participants": n,
        "active_last_7d": active7,
        "bp_latest_30d": safe,
        "avg_daily_steps_7d": avg_steps,
        "suppressed": False,
    }


@router.get("/v1/staff/org/notifications")
def get_notification_settings(s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    if s.role != "admin":
        raise HTTPException(403, "เฉพาะผู้ดูแลระบบเท่านั้น")
    org = db.get(Organization, s.org_id)
    cfg = org.alert_thresholds or {}
    token = cfg.get("line_channel_token") or ""
    return {
        "webhook_url": org.alert_webhook_url or "",
        "line_target_id": cfg.get("line_target_id") or "",
        "has_line_token": bool(token),
        "line_token_masked": (token[:6] + "..." + token[-4:]) if len(token) > 12 else ("***" if token else ""),
    }


@router.put("/v1/staff/org/notifications")
def update_notification_settings(
    body: NotificationSettingsIn, s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)
):
    if s.role != "admin":
        raise HTTPException(403, "เฉพาะผู้ดูแลระบบเท่านั้น")
    org = db.get(Organization, s.org_id)
    org.alert_webhook_url = (body.webhook_url or "").strip() or None
    cfg = dict(org.alert_thresholds or {})
    if body.line_channel_token is not None:
        tok = body.line_channel_token.strip()
        if tok:
            cfg["line_channel_token"] = tok
        else:
            cfg.pop("line_channel_token", None)
    if body.line_target_id is not None:
        tid = body.line_target_id.strip()
        if tid:
            cfg["line_target_id"] = tid
        else:
            cfg.pop("line_target_id", None)
    org.alert_thresholds = cfg
    db.add(AuditLog(actor=f"staff:{s.id}", action="update_notifications"))
    db.commit()
    return {"ok": True}


@router.post("/v1/staff/org/notifications/test")
def test_notification_settings(s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    if s.role != "admin":
        raise HTTPException(403, "เฉพาะผู้ดูแลระบบเท่านั้น")
    org = db.get(Organization, s.org_id)
    return alert_rules.send_test_notification(org)

