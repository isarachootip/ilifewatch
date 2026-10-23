"""Dependencies และฟังก์ชันช่วยเหลือกลางสำหรับตรวจสอบสิทธิ์และการแปลงข้อมูล"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import Depends, Header, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from .db import get_db
from .models import AuditLog, BpReading, Patient, StaffUser, VitalSample
from .security import read_token

CONSENT_VERSION = "1.0"
MIN_GROUP_SIZE = 5  # รายงานภาพรวมองค์กร: ไม่แสดงกลุ่มที่เล็กกว่านี้ เพื่อไม่ให้ระบุตัวบุคคลได้


def utc(dt: datetime) -> datetime:
    """แปลงเป็น UTC แบบมี timezone (SQLite คืนค่าแบบไม่มี tz ให้ถือว่าเป็น UTC)"""
    return dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)


def iso(dt: datetime | None) -> str | None:
    return utc(dt).isoformat() if dt else None


def _bearer(authorization: str | None) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "ต้องเข้าสู่ระบบ")
    claims = read_token(authorization[7:])
    if not claims:
        raise HTTPException(401, "token ไม่ถูกต้องหรือหมดอายุ")
    return claims


def current_patient(authorization: str | None = Header(None), db: Session = Depends(get_db)) -> Patient:
    c = _bearer(authorization)
    if c["k"] != "patient":
        raise HTTPException(403, "ใช้ได้เฉพาะแอปผู้ใช้นาฬิกา")
    p = db.get(Patient, c["sub"])
    if not p or not p.active:
        raise HTTPException(401, "ไม่พบผู้ใช้")
    return p


def current_staff(authorization: str | None = Header(None), db: Session = Depends(get_db)) -> StaffUser:
    c = _bearer(authorization)
    if c["k"] != "staff":
        raise HTTPException(403, "ใช้ได้เฉพาะเจ้าหน้าที่")
    s = db.get(StaffUser, c["sub"])
    if not s or not s.active:
        raise HTTPException(401, "ไม่พบผู้ใช้")
    return s


def require_individual_access(s: StaffUser) -> None:
    """HR ขององค์กรห้ามเห็นข้อมูลสุขภาพรายบุคคล (PDPA)"""
    if s.role not in ("admin", "caregiver", "clinician"):
        raise HTTPException(403, "สิทธิ์นี้ดูได้เฉพาะข้อมูลภาพรวม")


def patient_for_staff(db: Session, s: StaffUser, patient_id: int) -> Patient:
    require_individual_access(s)
    p = db.get(Patient, patient_id)
    if not p or p.org_id != s.org_id:
        raise HTTPException(404, "ไม่พบผู้ใช้")
    if p.org.type == "corporate" and s.role != "clinician":
        # องค์กร: ข้อมูลรายบุคคลเปิดให้เฉพาะบุคลากรทางการแพทย์ (เช่น พยาบาลประจำบริษัท)
        raise HTTPException(403, "ข้อมูลรายบุคคลของพนักงานเปิดให้เฉพาะบุคลากรทางการแพทย์")
    db.add(AuditLog(actor=f"staff:{s.id}", action="view_patient", patient_id=p.id))
    db.commit()
    return p


def bp_json(b: BpReading) -> dict:
    return {
        "id": b.id,
        "measured_at": iso(b.measured_at),
        "systolic": b.systolic,
        "diastolic": b.diastolic,
        "pulse": b.pulse,
        "method": b.method,
        "source": b.source,
    }


def build_patient_summary(db: Session, p: Patient) -> dict:
    since = datetime.now(timezone.utc) - timedelta(days=30)
    bps = db.execute(
        select(BpReading)
        .where(BpReading.patient_id == p.id, BpReading.measured_at >= since)
        .order_by(BpReading.measured_at.desc())
    ).scalars().all()

    def latest(metric: str):
        v = db.execute(
            select(VitalSample)
            .where(VitalSample.patient_id == p.id, VitalSample.metric == metric)
            .order_by(VitalSample.at.desc())
            .limit(1)
        ).scalar()
        return {"value": v.value, "at": iso(v.at)} if v else None

    avg7 = [b for b in bps if utc(b.measured_at) >= datetime.now(timezone.utc) - timedelta(days=7)]
    return {
        "latest_bp": bp_json(bps[0]) if bps else None,
        "bp_7d_avg": (
            {
                "systolic": round(sum(b.systolic for b in avg7) / len(avg7)),
                "diastolic": round(sum(b.diastolic for b in avg7) / len(avg7)),
                "n": len(avg7),
            }
            if avg7
            else None
        ),
        "latest_heart_rate": latest("heart_rate"),
        "latest_spo2": latest("spo2"),
    }
