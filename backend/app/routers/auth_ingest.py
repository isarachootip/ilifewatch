"""Router สำหรับเข้าสู่ระบบและรับข้อมูลจากแอปมือถือ (Ingest & Patient Summary)"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import alerts as alert_rules
from ..db import get_db
from ..deps import CONSENT_VERSION, build_patient_summary, current_patient, utc
from ..models import AuditLog, BpReading, Device, EcgRecord, Organization, Patient, SleepSession, StaffUser, VitalSample
from ..schemas import IngestIn, LoginIn, StaffLoginIn
from ..security import make_token, verify_secret

router = APIRouter()


@router.post("/v1/auth/login")
def patient_login(body: LoginIn, db: Session = Depends(get_db)):
    p = db.execute(select(Patient).where(Patient.enrollment_code == body.enrollment_code.strip().upper())).scalar()
    if not p or not p.active or not verify_secret(body.pin, p.pin_hash):
        raise HTTPException(401, "รหัสลงทะเบียนหรือ PIN ไม่ถูกต้อง")
    if p.consent_at is None:  # แอปบังคับติ๊กยินยอมก่อนกดเข้าสู่ระบบ
        p.consent_at = datetime.now(timezone.utc)
        p.consent_version = CONSENT_VERSION
    db.add(AuditLog(actor=f"patient:{p.id}", action="login", patient_id=p.id))
    db.commit()
    return {
        "token": make_token("patient", p.id, p.org_id),
        "patient": {
            "id": p.id,
            "display_name": p.display_name,
            "sex": p.sex,
            "birth_year": p.birth_year,
            "height_cm": p.height_cm,
            "weight_kg": p.weight_kg,
        },
        "org": {"name": p.org.name, "type": p.org.type},
    }


@router.post("/v1/staff/login")
def staff_login(body: StaffLoginIn, db: Session = Depends(get_db)):
    s = db.execute(select(StaffUser).where(StaffUser.email == body.email.strip().lower())).scalar()
    if not s or not s.active or not verify_secret(body.password, s.password_hash):
        raise HTTPException(401, "อีเมลหรือรหัสผ่านไม่ถูกต้อง")
    org = db.get(Organization, s.org_id)
    return {
        "token": make_token("staff", s.id, s.org_id, s.role),
        "staff": {"id": s.id, "name": s.name, "role": s.role},
        "org": {"id": org.id, "name": org.name, "type": org.type},
    }


@router.post("/v1/ingest")
def ingest(body: IngestIn, p: Patient = Depends(current_patient), db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    if body.device.mac:
        d = db.execute(select(Device).where(Device.patient_id == p.id, Device.mac == body.device.mac)).scalar()
        if not d:
            d = Device(patient_id=p.id, mac=body.device.mac)
            db.add(d)
        d.firmware = body.device.firmware or d.firmware
        d.model = body.device.model or d.model
        d.last_seen = now

    # ---- ความดัน: กันซ้ำ (ค่าที่วัดจากแอปอาจถูกอ่านซ้ำจากนาฬิกาอีกรอบ) ภายใน ±3 นาที ค่าเดียวกัน
    new_bp: list[BpReading] = []
    if body.bp:
        times = [utc(b.measured_at) for b in body.bp]
        lo, hi = min(times) - timedelta(minutes=3), max(times) + timedelta(minutes=3)
        existing = db.execute(
            select(BpReading).where(BpReading.patient_id == p.id, BpReading.measured_at >= lo, BpReading.measured_at <= hi)
        ).scalars().all()
        pool = [(utc(e.measured_at), e.systolic, e.diastolic) for e in existing]
        for b in body.bp:
            t = utc(b.measured_at)
            if b.systolic <= b.diastolic:
                continue
            if any(
                abs((t - et).total_seconds()) <= 180 and s == b.systolic and d_ == b.diastolic
                for et, s, d_ in pool
            ):
                continue
            r = BpReading(
                patient_id=p.id,
                measured_at=t,
                systolic=b.systolic,
                diastolic=b.diastolic,
                pulse=b.pulse,
                method=b.method,
                source=b.source,
                status=b.status,
                credibility=b.credibility,
            )
            db.add(r)
            new_bp.append(r)
            pool.append((t, b.systolic, b.diastolic))

    # ---- ค่าอนุกรมเวลา
    new_vitals: list[VitalSample] = []
    if body.vitals:
        times = [utc(v.at) for v in body.vitals]
        have = {
            (m, utc(a))
            for m, a in db.execute(
                select(VitalSample.metric, VitalSample.at).where(
                    VitalSample.patient_id == p.id, VitalSample.at >= min(times), VitalSample.at <= max(times)
                )
            ).all()
        }
        for v in body.vitals:
            key = (v.metric, utc(v.at))
            if key in have:
                continue
            have.add(key)
            s = VitalSample(patient_id=p.id, at=key[1], metric=v.metric, value=v.value)
            db.add(s)
            new_vitals.append(s)

    # ---- ECG
    n_ecg = 0
    for e in body.ecg:
        t = utc(e.measured_at)
        lo, hi = t - timedelta(seconds=90), t + timedelta(seconds=90)
        dup = db.execute(
            select(EcgRecord.id).where(EcgRecord.patient_id == p.id, EcgRecord.measured_at >= lo, EcgRecord.measured_at <= hi)
        ).first()
        if dup or not e.waveform:
            continue
        db.add(
            EcgRecord(
                patient_id=p.id,
                measured_at=t,
                duration_sec=e.duration_sec,
                sample_rate_hz=e.sample_rate_hz,
                avg_heart_rate=e.avg_heart_rate,
                avg_hrv=e.avg_hrv,
                avg_qt=e.avg_qt,
                avg_resp_rate=e.avg_resp_rate,
                waveform=e.waveform,
                source=e.source,
            )
        )
        n_ecg += 1

    # ---- การนอน
    n_sleep = 0
    for s in body.sleep:
        start = utc(s.start)
        if db.execute(select(SleepSession.id).where(SleepSession.patient_id == p.id, SleepSession.start == start)).first():
            continue
        db.add(
            SleepSession(
                patient_id=p.id,
                start=start,
                end=utc(s.end),
                deep_minutes=s.deep_minutes,
                light_minutes=s.light_minutes,
                wake_count=s.wake_count,
                quality=s.quality,
                curve=s.curve,
            )
        )
        n_sleep += 1

    db.flush()
    created = alert_rules.evaluate(db, p, new_bp, new_vitals)
    db.commit()
    alert_rules.notify(p, created)
    return {
        "accepted": {"bp": len(new_bp), "vitals": len(new_vitals), "ecg": n_ecg, "sleep": n_sleep},
        "alerts": [{"level": a.level, "kind": a.kind, "message": a.message} for a in created],
    }


@router.get("/v1/me/summary")
def my_summary(p: Patient = Depends(current_patient), db: Session = Depends(get_db)):
    return build_patient_summary(db, p)
