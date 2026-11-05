import base64
import hashlib
import hmac
import json

from app import line_oa
from tests.test_api import client, staff_token  # noqa: F401


def test_one_click_line_oa_connect_and_auto_group_webhook(client, monkeypatch):
    ha = staff_token(client, "admin.care@demo.local")

    monkeypatch.setattr(line_oa, "exchange_access_token", lambda cid, sec: f"auto-tok-{cid}")
    monkeypatch.setattr(
        line_oa,
        "fetch_bot_info",
        lambda tok: {"displayName": "ศูนย์ดูแลบ้านอุ่นใจ Official", "basicId": "@baanaunjai"},
    )

    # 1. Connect with LINE OA Name + Channel ID + Secret Key (no target_id needed -> broadcast mode)
    rc = client.post(
        "/v1/staff/org/line/connect",
        headers=ha,
        json={
            "line_oa_name": "บ้านอุ่นใจ แจ้งเตือน",
            "channel_id": "2001234567",
            "secret_key": "my-channel-secret-xyz",
        },
    )
    assert rc.status_code == 200
    body = rc.json()
    assert body["connected"] is True
    assert body["line_oa_name"] == "บ้านอุ่นใจ แจ้งเตือน"
    assert body["line_basic_id"] == "@baanaunjai"
    assert body["line_mode"] == "broadcast"

    rg = client.get("/v1/staff/org/notifications", headers=ha).json()
    assert rg["line_connected"] is True
    assert rg["line_mode"] == "broadcast"
    org_id = rg["org_id"]

    # 2. Simulate LINE Webhook when bot is invited to nurse group (valid HMAC signature)
    webhook_payload = json.dumps(
        {"events": [{"type": "join", "source": {"type": "group", "groupId": "C9988776655"}}]}
    ).encode()
    sig = base64.b64encode(
        hmac.new(b"my-channel-secret-xyz", webhook_payload, hashlib.sha256).digest()
    ).decode()

    rw = client.post(
        f"/v1/webhooks/line/{org_id}",
        content=webhook_payload,
        headers={"Content-Type": "application/json", "X-Line-Signature": sig},
    )
    assert rw.status_code == 200
    assert rw.json()["captured_target_id"] == "C9988776655"

    # Verify mode switched automatically to "group" with captured groupId
    rg2 = client.get("/v1/staff/org/notifications", headers=ha).json()
    assert rg2["line_target_id"] == "C9988776655"
    assert rg2["line_mode"] == "group"

    # 3. Invalid signature must be rejected with 401
    rw_bad = client.post(
        f"/v1/webhooks/line/{org_id}",
        content=webhook_payload,
        headers={"Content-Type": "application/json", "X-Line-Signature": "bad-sig"},
    )
    assert rw_bad.status_code == 401

    # 4. Disconnect LINE OA
    rd = client.post("/v1/staff/org/line/disconnect", headers=ha)
    assert rd.status_code == 200
    assert rd.json()["connected"] is False
    rg3 = client.get("/v1/staff/org/notifications", headers=ha).json()
    assert rg3["line_connected"] is False
