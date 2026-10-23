"""โครงสร้างฐานข้อมูล (SQLAlchemy 2) — รองรับหลายหน่วยงาน (multi-tenant)

organization.type:
  elder_care  ศูนย์/บริการดูแลผู้สูงอายุ — ผู้ดูแลเห็นข้อมูลรายบุคคล + แจ้งเตือน
  clinic      คลินิก/โรงพยาบาล        — แพทย์/พยาบาลเห็นรายบุคคล + คิวตรวจ ECG
  corporate   ดูแลสุขภาพพนักงาน        — HR เห็นเฉพาะภาพรวมแบบไม่ระบุตัวตน
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (JSON, Boolean, DateTime, Float, ForeignKey, Index, Integer, String, Text,
                        UniqueConstraint)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class Organization(Base):
    __tablename__ = "organizations"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200))
    type: Mapped[str] = mapped_column(String(20))  # elder_care | clinic | corporate
    # เกณฑ์แจ้งเตือนของหน่วยงาน (ทับค่าเริ่มต้นใน alerts.py ได้)
    alert_thresholds: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    # URL รับแจ้งเตือน (เช่น LINE OA / ระบบของหน่วยงาน)
    alert_webhook_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class StaffUser(Base):
    __tablename__ = "staff_users"
    id: Mapped[int] = mapped_column(primary_key=True)
    org_id: Mapped[int] = mapped_column(ForeignKey("organizations.id"), index=True)
    email: Mapped[str] = mapped_column(String(200), unique=True)
    name: Mapped[str] = mapped_column(String(200))
    # admin | caregiver | clinician | hr_viewer
    role: Mapped[str] = mapped_column(String(20))
    password_hash: Mapped[str] = mapped_column(String(300))
    active: Mapped[bool] = mapped_column(Boolean, default=True)


class Patient(Base):
    """ผู้ใช้นาฬิกา (ผู้สูงอายุ / ผู้ป่วย / พนักงาน)"""
    __tablename__ = "patients"
    id: Mapped[int] = mapped_column(primary_key=True)
    org_id: Mapped[int] = mapped_column(ForeignKey("organizations.id"), index=True)
    display_name: Mapped[str] = mapped_column(String(200))
    sex: Mapped[str] = mapped_column(String(1))  # M | F
    birth_year: Mapped[int] = mapped_column(Integer)
    height_cm: Mapped[int] = mapped_column(Integer)
    weight_kg: Mapped[int] = mapped_column(Integer)
    enrollment_code: Mapped[str] = mapped_column(String(20), unique=True)
    pin_hash: Mapped[str] = mapped_column(String(300))
    # PDPA: วันเวลาและเวอร์ชันของความยินยอม
    consent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    consent_version: Mapped[str | None] = mapped_column(String(20), nullable=True)
    emergency_contact: Mapped[str | None] = mapped_column(String(200), nullable=True)
    alert_thresholds: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    org: Mapped[Organization] = relationship()


class Device(Base):
    __tablename__ = "devices"
    id: Mapped[int] = mapped_column(primary_key=True)
    patient_id: Mapped[int] = mapped_column(ForeignKey("patients.id"), index=True)
    mac: Mapped[str] = mapped_column(String(40))
    model: Mapped[str | None] = mapped_column(String(50), nullable=True)
    firmware: Mapped[str | None] = mapped_column(String(50), nullable=True)
    last_seen: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    __table_args__ = (UniqueConstraint("patient_id", "mac"),)


class BpReading(Base):
    __tablename__ = "bp_readings"
    id: Mapped[int] = mapped_column(primary_key=True)
    patient_id: Mapped[int] = mapped_column(ForeignKey("patients.id"))
    measured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    systolic: Mapped[int] = mapped_column(Integer)
    diastolic: Mapped[int] = mapped_column(Integer)
    pulse: Mapped[int | None] = mapped_column(Integer, nullable=True)
    method: Mapped[str] = mapped_column(String(10))  # cuff | ppg
    source: Mapped[str] = mapped_column(String(10))  # live | watch | auto
    status: Mapped[str | None] = mapped_column(String(40), nullable=True)
    credibility: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    __table_args__ = (Index("ix_bp_patient_time", "patient_id", "measured_at"),)


class EcgRecord(Base):
    __tablename__ = "ecg_records"
    id: Mapped[int] = mapped_column(primary_key=True)
    patient_id: Mapped[int] = mapped_column(ForeignKey("patients.id"))
    measured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    duration_sec: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sample_rate_hz: Mapped[int | None] = mapped_column(Integer, nullable=True)
    avg_heart_rate: Mapped[int | None] = mapped_column(Integer, nullable=True)
    avg_hrv: Mapped[int | None] = mapped_column(Integer, nullable=True)
    avg_qt: Mapped[int | None] = mapped_column(Integer, nullable=True)
    avg_resp_rate: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # ระบบจริงควรย้าย waveform ไปเก็บใน object storage แบบเข้ารหัส แล้วเก็บแค่ key ไว้ที่นี่
    waveform: Mapped[list | None] = mapped_column(JSON, nullable=True)
    source: Mapped[str] = mapped_column(String(10), default="live")
    review_status: Mapped[str] = mapped_column(String(20), default="pending")  # pending | reviewed
    reviewed_by: Mapped[int | None] = mapped_column(ForeignKey("staff_users.id"), nullable=True)
    review_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    __table_args__ = (UniqueConstraint("patient_id", "measured_at"),)


class VitalSample(Base):
    """อนุกรมเวลา: heart_rate, spo2, steps, temperature, stress"""
    __tablename__ = "vital_samples"
    id: Mapped[int] = mapped_column(primary_key=True)
    patient_id: Mapped[int] = mapped_column(ForeignKey("patients.id"))
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    metric: Mapped[str] = mapped_column(String(20))
    value: Mapped[float] = mapped_column(Float)
    __table_args__ = (UniqueConstraint("patient_id", "metric", "at"),)


class SleepSession(Base):
    __tablename__ = "sleep_sessions"
    id: Mapped[int] = mapped_column(primary_key=True)
    patient_id: Mapped[int] = mapped_column(ForeignKey("patients.id"))
    start: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    end: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    deep_minutes: Mapped[int] = mapped_column(Integer)
    light_minutes: Mapped[int] = mapped_column(Integer)
    wake_count: Mapped[int] = mapped_column(Integer)
    quality: Mapped[int | None] = mapped_column(Integer, nullable=True)
    curve: Mapped[str | None] = mapped_column(Text, nullable=True)
    __table_args__ = (UniqueConstraint("patient_id", "start"),)


class Alert(Base):
    __tablename__ = "alerts"
    id: Mapped[int] = mapped_column(primary_key=True)
    patient_id: Mapped[int] = mapped_column(ForeignKey("patients.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    level: Mapped[str] = mapped_column(String(10))  # critical | warning | info
    kind: Mapped[str] = mapped_column(String(30))  # bp_very_high, bp_high, bp_low, spo2_low, hr_high, hr_low
    message: Mapped[str] = mapped_column(String(500))
    data: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    acknowledged_by: Mapped[int | None] = mapped_column(ForeignKey("staff_users.id"), nullable=True)
    acknowledged_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)


class AuditLog(Base):
    """PDPA: บันทึกว่าใครเข้าดูข้อมูลสุขภาพของใคร เมื่อไร"""
    __tablename__ = "audit_log"
    id: Mapped[int] = mapped_column(primary_key=True)
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    actor: Mapped[str] = mapped_column(String(100))  # staff:12 | patient:5
    action: Mapped[str] = mapped_column(String(100))
    patient_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
