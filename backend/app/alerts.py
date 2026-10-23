"""กฎการแจ้งเตือน — เป็นการคัดกรองเบื้องต้นให้เจ้าหน้าที่ติดตาม ไม่ใช่การวินิจฉัย

ค่าเกณฑ์เริ่มต้นอ้างอิงแนวทางความดันโลหิตสูงของไทย (ระดับ 2 และ 3)
หน่วยงานปรับได้ที่ organizations.alert_thresholds และรายบุคคลที่ patients.alert_thresholds
(แพทย์ของหน่วยงานควรเป็นผู้กำหนดเกณฑ์จริง)
"""
from __future__ import annotations

import json
import logging
import urllib.request
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Alert, Patient

log = logging.getLogger("alerts")

DEFAULT_THRESHOLDS = {
    "bp_critical_sys": 180, "bp_critical_dia": 110,
    "bp_high_sys": 160, "bp_high_dia": 100,
    "bp_low_sys": 90,
    "spo2_low": 90,          # ต่ำกว่านี้นับเป็นค่าต่ำ
    "spo2_low_count": 3,     # ต้องพบอย่างน้อยกี่ครั้งใน 1 ชุดข้อมูลจึงแจ้ง
    "hr_high": 130, "hr_low": 40, "hr_count": 3,
    "recent_hours": 24,      # ไม่แจ้งเตือนจากข้อมูลย้อนหลังที่เก่ากว่านี้
    "cooldown_hours": 6,     # ไม่แจ้งเรื่องเดิมซ้ำภายในช่วงนี้
}


def thresholds_for(p: Patient) -> dict:
    t = dict(DEFAULT_THRESHOLDS)
    t.update(p.org.alert_thresholds or {})
    t.update(p.alert_thresholds or {})
    return t


def _recent(at: datetime, t: dict) -> bool:
    if at.tzinfo is None:
        at = at.replace(tzinfo=timezone.utc)
    return at >= datetime.now(timezone.utc) - timedelta(hours=t["recent_hours"])


def _cooldown_ok(db: Session, p: Patient, kind: str, t: dict) -> bool:
    since = datetime.now(timezone.utc) - timedelta(hours=t["cooldown_hours"])
    q = select(Alert.id).where(Alert.patient_id == p.id, Alert.kind == kind, Alert.created_at >= since)
    return db.execute(q).first() is None


def evaluate(db: Session, p: Patient, bp: list, vitals: list) -> list[Alert]:
    """bp / vitals คือรายการที่เพิ่งบันทึกใหม่ในรอบนี้ (กันซ้ำแล้ว)"""
    t = thresholds_for(p)
    out: list[Alert] = []

    def add(level: str, kind: str, message: str, data: dict):
        if _cooldown_ok(db, p, kind, t) and all(a.kind != kind for a in out):
            out.append(Alert(patient_id=p.id, level=level, kind=kind, message=message, data=data))

    for r in sorted(bp, key=lambda r: r.measured_at, reverse=True):
        if not _recent(r.measured_at, t):
            continue
        d = {"systolic": r.systolic, "diastolic": r.diastolic, "method": r.method,
             "measured_at": r.measured_at.isoformat()}
        if r.systolic >= t["bp_critical_sys"] or r.diastolic >= t["bp_critical_dia"]:
            add("critical", "bp_very_high", f"ความดันสูงมาก {r.systolic}/{r.diastolic} mmHg", d)
        elif r.systolic >= t["bp_high_sys"] or r.diastolic >= t["bp_high_dia"]:
            add("warning", "bp_high", f"ความดันสูง {r.systolic}/{r.diastolic} mmHg", d)
        elif r.systolic < t["bp_low_sys"]:
            add("warning", "bp_low", f"ความดันต่ำ {r.systolic}/{r.diastolic} mmHg", d)

    recent = [v for v in vitals if _recent(v.at, t)]
    low_spo2 = [v for v in recent if v.metric == "spo2" and 0 < v.value < t["spo2_low"]]
    if len(low_spo2) >= t["spo2_low_count"]:
        add("warning", "spo2_low", f"ออกซิเจนในเลือดต่ำกว่า {t['spo2_low']}% จำนวน {len(low_spo2)} ครั้ง "
            f"(ต่ำสุด {min(v.value for v in low_spo2):.0f}%)", {"count": len(low_spo2)})
    hr = [v for v in recent if v.metric == "heart_rate" and v.value > 0]
    high = [v for v in hr if v.value > t["hr_high"]]
    low = [v for v in hr if v.value < t["hr_low"]]
    if len(high) >= t["hr_count"]:
        add("warning", "hr_high", f"ชีพจรสูงกว่า {t['hr_high']} ครั้ง/นาที จำนวน {len(high)} ครั้ง", {"count": len(high)})
    if len(low) >= t["hr_count"]:
        add("warning", "hr_low", f"ชีพจรต่ำกว่า {t['hr_low']} ครั้ง/นาที จำนวน {len(low)} ครั้ง", {"count": len(low)})

    for a in out:
        db.add(a)
    return out


def notify(p: Patient, alerts: list[Alert]) -> None:
    """ส่งต่อแจ้งเตือนไปยัง webhook ของหน่วยงาน (เช่น LINE OA, ระบบ nurse call)

    ส่งเฉพาะข้อความที่จำเป็น ไม่ส่งข้อมูลสุขภาพดิบ เพื่อลดความเสี่ยงด้าน PDPA
    ระบบจริงควรส่งผ่านคิว (เช่น Celery/Cloud Tasks) ไม่ส่งตรงใน request
    """
    url = p.org.alert_webhook_url
    if not url or not alerts:
        return
    for a in alerts:
        body = json.dumps({"patient_id": p.id, "patient_name": p.display_name, "level": a.level,
                           "message": a.message}).encode()
        try:
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
            urllib.request.urlopen(req, timeout=5).close()
        except Exception as e:  # ไม่ให้การแจ้งเตือนล้มเหลวทำให้การบันทึกข้อมูลล้มเหลว
            log.warning("webhook failed: %s", e)
