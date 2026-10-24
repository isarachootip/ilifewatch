"""Router สำหรับเจ้าหน้าที่: ข้อมูลผู้ใช้นาฬิกา, กราฟสุขภาพ และคิวตรวจคลื่นไฟฟ้าหัวใจ (ECG)"""
from __future__ import annotations

from collections import Counter
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import bp_json, build_patient_summary, current_staff, iso, patient_for_staff, require_individual_access
from ..models import Alert, AuditLog, BpReading, Device, EcgRecord, Organization, Patient, SleepSession, StaffUser, VitalSample
from ..schemas import EcgReviewIn, PatientCreate
from ..security import hash_secret, new_enrollment_code, new_pin

router = APIRouter()


@router.get("/v1/staff/patients")
def list_patients(s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    require_individual_access(s)
    org = db.get(Organization, s.org_id)
    if org.type == "corporate" and s.role != "clinician":
        raise HTTPException(403, "ข้อมูลรายบุคคลของพนักงานเปิดให้เฉพาะบุคลากรทางการแพทย์")
    patients = db.execute(
        select(Patient).where(Patient.org_id == s.org_id, Patient.active).order_by(Patient.display_name)
    ).scalars().all()
    open_alerts = Counter(
        pid
        for (pid,) in db.execute(
            select(Alert.patient_id).join(Patient).where(Patient.org_id == s.org_id, Alert.acknowledged_at.is_(None))
        )
    )
    out = []
    for p in patients:
        lb = db.execute(
            select(BpReading).where(BpReading.patient_id == p.id).order_by(BpReading.measured_at.desc()).limit(1)
        ).scalar()
        last_seen = db.execute(select(func.max(Device.last_seen)).where(Device.patient_id == p.id)).scalar()
        out.append(
            {
                "id": p.id,
                "display_name": p.display_name,
                "sex": p.sex,
                "birth_year": p.birth_year,
                "latest_bp": bp_json(lb) if lb else None,
                "open_alerts": open_alerts.get(p.id, 0),
                "last_sync": iso(last_seen),
                "consent_at": iso(p.consent_at),
            }
        )
    db.add(AuditLog(actor=f"staff:{s.id}", action="list_patients"))
    db.commit()
    return out


@router.post("/v1/staff/patients")
def create_patient(body: PatientCreate, s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    if s.role != "admin":
        raise HTTPException(403, "เฉพาะผู้ดูแลระบบของหน่วยงาน")
    pin = new_pin()
    code = new_enrollment_code()
    while db.execute(select(Patient.id).where(Patient.enrollment_code == code)).first():
        code = new_enrollment_code()
    p = Patient(
        org_id=s.org_id,
        display_name=body.display_name,
        sex=body.sex,
        birth_year=body.birth_year,
        height_cm=body.height_cm,
        weight_kg=body.weight_kg,
        emergency_contact=body.emergency_contact,
        enrollment_code=code,
        pin_hash=hash_secret(pin),
    )
    db.add(p)
    db.commit()
    # PIN แสดงครั้งเดียว ให้เจ้าหน้าที่ส่งให้ผู้ใช้
    return {"id": p.id, "enrollment_code": code, "pin": pin}


@router.get("/v1/staff/patients/{pid}/summary")
def patient_summary(pid: int, s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    p = patient_for_staff(db, s, pid)
    return {
        "patient": {
            "id": p.id,
            "display_name": p.display_name,
            "sex": p.sex,
            "birth_year": p.birth_year,
            "emergency_contact": p.emergency_contact,
        },
        **build_patient_summary(db, p),
    }


@router.get("/v1/staff/patients/{pid}/bp")
def patient_bp(
    pid: int, days: int = Query(30, le=365), s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)
):
    p = patient_for_staff(db, s, pid)
    since = datetime.now(timezone.utc) - timedelta(days=days)
    rows = db.execute(
        select(BpReading).where(BpReading.patient_id == p.id, BpReading.measured_at >= since).order_by(BpReading.measured_at)
    ).scalars().all()
    return [bp_json(b) for b in rows]


@router.get("/v1/staff/patients/{pid}/vitals")
def patient_vitals(
    pid: int, metric: str, days: int = Query(3, le=31), s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)
):
    p = patient_for_staff(db, s, pid)
    since = datetime.now(timezone.utc) - timedelta(days=days)
    rows = db.execute(
        select(VitalSample)
        .where(VitalSample.patient_id == p.id, VitalSample.metric == metric, VitalSample.at >= since)
        .order_by(VitalSample.at)
    ).scalars().all()
    return [{"at": iso(v.at), "value": v.value} for v in rows]


@router.get("/v1/staff/patients/{pid}/sleep")
def patient_sleep(
    pid: int, days: int = Query(14, le=90), s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)
):
    p = patient_for_staff(db, s, pid)
    since = datetime.now(timezone.utc) - timedelta(days=days)
    rows = db.execute(
        select(SleepSession).where(SleepSession.patient_id == p.id, SleepSession.start >= since).order_by(SleepSession.start)
    ).scalars().all()
    return [
        {
            "start": iso(r.start),
            "end": iso(r.end),
            "deep_minutes": r.deep_minutes,
            "light_minutes": r.light_minutes,
            "wake_count": r.wake_count,
            "quality": r.quality,
        }
        for r in rows
    ]


@router.get("/v1/staff/patients/{pid}/ecg")
def patient_ecg_list(pid: int, s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    p = patient_for_staff(db, s, pid)
    rows = db.execute(
        select(EcgRecord).where(EcgRecord.patient_id == p.id).order_by(EcgRecord.measured_at.desc()).limit(100)
    ).scalars().all()
    return [_ecg_json(e, waveform=False) for e in rows]


@router.get("/v1/staff/ecg/{eid}")
def ecg_detail(eid: int, s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    e = db.get(EcgRecord, eid)
    if not e:
        raise HTTPException(404, "ไม่พบข้อมูล")
    patient_for_staff(db, s, e.patient_id)
    return _ecg_json(e, waveform=True)


@router.post("/v1/staff/ecg/{eid}/review")
def ecg_review(eid: int, body: EcgReviewIn, s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    if s.role != "clinician":
        raise HTTPException(403, "เฉพาะแพทย์/พยาบาล")
    e = db.get(EcgRecord, eid)
    if not e:
        raise HTTPException(404, "ไม่พบข้อมูล")
    patient_for_staff(db, s, e.patient_id)
    e.review_status, e.reviewed_by, e.review_note = "reviewed", s.id, body.note
    db.commit()
    return _ecg_json(e, waveform=False)


@router.get("/v1/staff/ecg-queue")
def ecg_queue(s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    require_individual_access(s)
    rows = db.execute(
        select(EcgRecord, Patient.display_name)
        .join(Patient, Patient.id == EcgRecord.patient_id)
        .where(Patient.org_id == s.org_id, EcgRecord.review_status == "pending")
        .order_by(EcgRecord.measured_at)
    ).all()
    return [{**_ecg_json(e, waveform=False), "patient_name": n} for e, n in rows]


def _ecg_json(e: EcgRecord, waveform: bool) -> dict:
    d = {
        "id": e.id, "patient_id": e.patient_id, "measured_at": iso(e.measured_at),
        "duration_sec": e.duration_sec, "sample_rate_hz": e.sample_rate_hz,
        "avg_heart_rate": e.avg_heart_rate, "avg_hrv": e.avg_hrv, "avg_qt": e.avg_qt,
        "avg_resp_rate": e.avg_resp_rate, "source": e.source,
        "review_status": e.review_status, "review_note": e.review_note,
    }
    if waveform:
        d["waveform"] = e.waveform or []
    return d
