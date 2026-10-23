"""Router สำหรับการแจ้งเตือน (Alerts) และภาพรวมองค์กรแบบไม่ระบุตัวตน (Corporate Aggregate)"""
from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import MIN_GROUP_SIZE, current_staff, iso, patient_for_staff, require_individual_access, utc
from ..models import Alert, AuditLog, BpReading, Device, Patient, StaffUser, VitalSample
from ..schemas import AckIn

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
