"""สร้างข้อมูลตัวอย่างสำหรับทดลอง: python -m app.seed

ได้หน่วยงาน 3 แบบ พร้อมบัญชีเจ้าหน้าที่ และผู้ใช้นาฬิกาตัวอย่าง (พิมพ์รหัส/PIN ออกมาให้)
"""
from sqlalchemy import select

from .db import SessionLocal, init_db
from .models import Organization, Patient, StaffUser
from .security import hash_secret

DEMO_PASSWORD = "demo1234"


def run() -> None:
    init_db()
    db = SessionLocal()
    if db.execute(select(Organization.id)).first():
        print("มีข้อมูลอยู่แล้ว ข้ามการ seed")
        return
    orgs = [
        ("บ้านสุขใจ ดูแลผู้สูงอายุ", "elder_care", [("care@demo.local", "คุณพยาบาลดูแล", "caregiver"),
                                                   ("admin.care@demo.local", "แอดมินศูนย์", "admin")]),
        ("คลินิกหัวใจตัวอย่าง", "clinic", [("doctor@demo.local", "นพ.ตัวอย่าง", "clinician"),
                                          ("admin.clinic@demo.local", "แอดมินคลินิก", "admin")]),
        ("บริษัทตัวอย่าง จำกัด", "corporate", [("hr@demo.local", "ฝ่ายบุคคล", "hr_viewer"),
                                              ("nurse@demo.local", "พยาบาลประจำบริษัท", "clinician"),
                                              ("admin.corp@demo.local", "แอดมินบริษัท", "admin")]),
    ]
    for name, typ, staff in orgs:
        o = Organization(name=name, type=typ)
        db.add(o)
        db.flush()
        for email, sname, role in staff:
            db.add(StaffUser(org_id=o.id, email=email, name=sname, role=role, password_hash=hash_secret(DEMO_PASSWORD)))
        code = {"elder_care": "CARE0001", "clinic": "CLIN0001", "corporate": "CORP0001"}[typ]
        db.add(Patient(org_id=o.id, display_name=f"ผู้ใช้ตัวอย่าง ({typ})", sex="F", birth_year=1955,
                       height_cm=158, weight_kg=60, enrollment_code=code, pin_hash=hash_secret("123456")))
    db.commit()
    print("สร้างข้อมูลตัวอย่างแล้ว")
    print(f"  เจ้าหน้าที่: care@demo.local / doctor@demo.local / hr@demo.local / nurse@demo.local  รหัสผ่าน {DEMO_PASSWORD}")
    print("  แอปมือถือ: รหัส CARE0001 / CLIN0001 / CORP0001  PIN 123456")


if __name__ == "__main__":
    run()
