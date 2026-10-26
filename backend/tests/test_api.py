import os
import tempfile
from datetime import datetime, timedelta, timezone

_tmp = tempfile.mkdtemp()
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp}/test.db"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app import seed  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture(scope="module")
def client():
    seed.run()
    with TestClient(app) as c:
        yield c


def now(minutes=0):
    return (datetime.now(timezone.utc) + timedelta(minutes=minutes)).isoformat()


def patient_token(c, code="CARE0001"):
    r = c.post("/v1/auth/login", json={"enrollment_code": code, "pin": "123456"})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}


def staff_token(c, email):
    r = c.post("/v1/staff/login", json={"email": email, "password": seed.DEMO_PASSWORD})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}


def test_login_rejects_wrong_pin(client):
    r = client.post("/v1/auth/login", json={"enrollment_code": "CARE0001", "pin": "000000"})
    assert r.status_code == 401


def test_ingest_dedupe_and_alerts(client):
    h = patient_token(client)
    payload = {
        "device": {"mac": "AA:BB:CC:DD:EE:FF", "firmware": "1.0", "model": "F520Pro"},
        "bp": [
            {"measured_at": now(-1), "systolic": 185, "diastolic": 112, "pulse": 80, "method": "cuff", "source": "live"},
            # ค่าเดียวกันที่อ่านซ้ำจากนาฬิกา ห่างกัน 1 นาที -> ต้องไม่บันทึกซ้ำ
            {"measured_at": now(0), "systolic": 185, "diastolic": 112, "method": "cuff", "source": "watch"},
            # ข้อมูลเก่า -> บันทึกได้แต่ไม่แจ้งเตือน
            {"measured_at": now(-60 * 48), "systolic": 120, "diastolic": 78, "method": "ppg", "source": "auto"},
        ],
        "vitals": [{"at": now(-i * 5), "metric": "spo2", "value": 86} for i in range(4)]
                  + [{"at": now(-5), "metric": "heart_rate", "value": 72}],
        "ecg": [{"measured_at": now(-2), "duration_sec": 30, "sample_rate_hz": 512, "avg_heart_rate": 74,
                 "waveform": list(range(100)), "source": "live"}],
        "sleep": [{"start": now(-600), "end": now(-120), "deep_minutes": 120, "light_minutes": 300, "wake_count": 2}],
    }
    r = client.post("/v1/ingest", json=payload, headers=h)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["accepted"] == {"bp": 2, "vitals": 5, "ecg": 1, "sleep": 1}
    kinds = {a["kind"] for a in body["alerts"]}
    assert kinds == {"bp_very_high", "spo2_low"}

    # ส่งชุดเดิมซ้ำ (เช่น คิวส่งซ้ำ) -> ไม่มีอะไรใหม่ และไม่แจ้งเตือนซ้ำ
    r2 = client.post("/v1/ingest", json=payload, headers=h)
    assert r2.json()["accepted"] == {"bp": 0, "vitals": 0, "ecg": 0, "sleep": 0}
    assert r2.json()["alerts"] == []

    s = client.get("/v1/me/summary", headers=h).json()
    assert s["latest_bp"]["systolic"] == 185
    assert s["latest_spo2"]["value"] == 86


def test_rejects_invalid_values(client):
    h = patient_token(client)
    r = client.post("/v1/ingest", json={"bp": [{"measured_at": now(), "systolic": 999, "diastolic": 80}]}, headers=h)
    assert r.status_code == 422
    for bad_vital in (
        {"at": now(), "metric": "spo2", "value": -5},
        {"at": now(), "metric": "spo2", "value": 105},
        {"at": now(), "metric": "heart_rate", "value": 10},
        {"at": now(), "metric": "heart_rate", "value": 300},
        {"at": now(), "metric": "temperature", "value": 25.0},
        {"at": now(), "metric": "steps", "value": -1},
        {"at": now(), "metric": "stress", "value": 120},
        {"at": now(), "metric": "hrv", "value": 400},
    ):
        rv = client.post("/v1/ingest", json={"vitals": [bad_vital]}, headers=h)
        assert rv.status_code == 422, f"Expected 422 for {bad_vital}, got {rv.status_code}"


def test_caregiver_sees_patient_and_acks_alert(client):
    h = staff_token(client, "care@demo.local")
    pts = client.get("/v1/staff/patients", headers=h).json()
    assert len(pts) == 1 and pts[0]["open_alerts"] == 2
    pid = pts[0]["id"]
    assert len(client.get(f"/v1/staff/patients/{pid}/bp", headers=h).json()) == 2
    alerts = client.get("/v1/staff/alerts", headers=h).json()
    r = client.post(f"/v1/staff/alerts/{alerts[0]['id']}/ack", json={"note": "โทรติดตามแล้ว"}, headers=h)
    assert r.status_code == 200
    assert len(client.get("/v1/staff/alerts", headers=h).json()) == 1
    ecg = client.get(f"/v1/staff/patients/{pid}/ecg", headers=h).json()
    assert len(ecg) == 1 and "waveform" not in ecg[0]
    assert len(client.get(f"/v1/staff/ecg/{ecg[0]['id']}", headers=h).json()["waveform"]) == 100


def test_staff_cannot_see_other_org(client):
    h = staff_token(client, "doctor@demo.local")  # คลินิก
    care = staff_token(client, "care@demo.local")
    pid = client.get("/v1/staff/patients", headers=care).json()[0]["id"]
    assert client.get(f"/v1/staff/patients/{pid}/bp", headers=h).status_code == 404


def test_hr_only_sees_suppressed_aggregate(client):
    h = staff_token(client, "hr@demo.local")
    assert client.get("/v1/staff/patients", headers=h).status_code == 403
    agg = client.get("/v1/staff/org/aggregate", headers=h).json()
    assert agg["suppressed"] is True  # มีพนักงานแค่ 1 คน


def test_corporate_admin_cannot_view_individual(client):
    h = staff_token(client, "admin.corp@demo.local")
    assert client.get("/v1/staff/patients", headers=h).status_code == 403
    nurse = staff_token(client, "nurse@demo.local")
    assert client.get("/v1/staff/patients", headers=nurse).status_code == 200


def test_admin_creates_patient(client):
    h = staff_token(client, "admin.care@demo.local")
    r = client.post("/v1/staff/patients", headers=h, json={
        "display_name": "คุณยายทดสอบ", "sex": "F", "birth_year": 1948, "height_cm": 150, "weight_kg": 52})
    assert r.status_code == 200
    d = r.json()
    lr = client.post("/v1/auth/login", json={"enrollment_code": d["enrollment_code"], "pin": d["pin"]})
    assert lr.status_code == 200
    assert lr.json()["org"]["type"] == "elder_care"
    # caregiver สร้างผู้ใช้ไม่ได้
    care = staff_token(client, "care@demo.local")
    assert client.post("/v1/staff/patients", headers=care, json={
        "display_name": "x", "sex": "M", "birth_year": 1950, "height_cm": 160, "weight_kg": 60}).status_code == 403


def test_patient_token_cannot_call_staff_api(client):
    h = patient_token(client)
    assert client.get("/v1/staff/alerts", headers=h).status_code == 403


def test_dashboard_extended_summary_and_static_assets(client):
    hp = patient_token(client)
    r = client.post(
        "/v1/ingest",
        headers=hp,
        json={
            "vitals": [
                {"at": now(-3), "metric": "temperature", "value": 36.7},
                {"at": now(-2), "metric": "steps", "value": 5420},
            ]
        },
    )
    assert r.status_code == 200
    hs = staff_token(client, "care@demo.local")
    pts = client.get("/v1/staff/patients", headers=hs).json()
    pid = next(p["id"] for p in pts if p["latest_bp"] is not None)
    summary = client.get(f"/v1/staff/patients/{pid}/summary", headers=hs).json()
    assert summary["latest_temperature"]["value"] == 36.7
    assert summary["latest_steps"]["value"] == 5420
    assert summary["latest_sleep"]["deep_minutes"] == 120

    dash = client.get("/dashboard")
    assert dash.status_code == 200
    assert "langSelect" in dash.text
    for asset in ("/static/i18n.js", "/static/charts.js", "/static/dashboard.js"):
        res = client.get(asset)
        assert res.status_code == 200, asset
    i18n_txt = client.get("/static/i18n.js").text
    for lang in ("th:", "en:", "zh:", "ar:", "de:"):
        assert lang in i18n_txt

