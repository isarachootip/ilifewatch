"""ระบบเชื่อมต่อ LINE Official Account (1-Click Connect, Auto OAuth Token, Broadcast & Webhook Auto-Group)"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import urllib.parse
import urllib.request

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session

from .db import get_db
from .deps import current_staff
from .models import AuditLog, Organization, StaffUser
from .schemas import LineConnectIn

router = APIRouter()


def exchange_access_token(channel_id: str, channel_secret: str) -> str:
    """แลก Channel ID + Channel Secret เป็น Short-lived Access Token อัตโนมัติ"""
    data = urllib.parse.urlencode(
        {
            "grant_type": "client_credentials",
            "client_id": channel_id.strip(),
            "client_secret": channel_secret.strip(),
        }
    ).encode()
    req = urllib.request.Request(
        "https://api.line.me/v2/oauth/accessToken",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(req, timeout=8) as resp:
        body = json.loads(resp.read().decode())
    token = body.get("access_token")
    if not token:
        raise ValueError("ไม่สามารถขอ Access Token จาก LINE ได้")
    return token


def fetch_bot_info(token: str) -> dict:
    """ดึงข้อมูลโปรไฟล์ LINE OA (displayName, basicId) เพื่อยืนยันการเชื่อมต่อ"""
    req = urllib.request.Request(
        "https://api.line.me/v2/bot/info",
        headers={"Authorization": f"Bearer {token.strip()}"},
    )
    with urllib.request.urlopen(req, timeout=8) as resp:
        return json.loads(resp.read().decode())


def _resolve_token(cfg: dict) -> str:
    token = (cfg.get("line_channel_token") or "").strip()
    if token:
        return token
    cid = (cfg.get("line_channel_id") or "").strip()
    csec = (cfg.get("line_channel_secret") or "").strip()
    if cid and csec:
        return exchange_access_token(cid, csec)
    return ""


def send_line_message(cfg: dict, text: str) -> str:
    """ส่งข้อความแจ้งเตือนผ่าน LINE OA (Push ถ้าระบุกลุ่ม/ผู้ใช้ หรือ Broadcast หาทุกคนที่แอดเพื่อน)"""
    token = _resolve_token(cfg)
    if not token:
        return "skipped"
    target_id = (cfg.get("line_target_id") or "").strip()
    if target_id:
        url = "https://api.line.me/v2/bot/message/push"
        payload = {"to": target_id, "messages": [{"type": "text", "text": text}]}
        mode = "push_sent"
    else:
        url = "https://api.line.me/v2/bot/message/broadcast"
        payload = {"messages": [{"type": "text", "text": text}]}
        mode = "broadcast_sent"
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {token}"},
    )
    urllib.request.urlopen(req, timeout=6).close()
    return mode


@router.post("/v1/staff/org/line/connect")
def connect_line_oa(
    body: LineConnectIn, s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)
):
    if s.role != "admin":
        raise HTTPException(403, "เฉพาะผู้ดูแลระบบเท่านั้น")
    org = db.get(Organization, s.org_id)
    cfg = dict(org.alert_thresholds or {})

    cid = (body.channel_id or cfg.get("line_channel_id") or "").strip()
    csec = (body.secret_key or cfg.get("line_channel_secret") or "").strip()
    tok = (body.channel_token or "").strip()

    try:
        if not tok:
            if not (cid and csec):
                raise HTTPException(400, "กรุณากรอก Channel ID และ Secret Key (หรือ Channel Access Token)")
            tok = exchange_access_token(cid, csec)
        bot = fetch_bot_info(tok)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(400, f"เชื่อมต่อ LINE OA ไม่สำเร็จ: {e}") from e

    oa_name = (body.line_oa_name or "").strip() or bot.get("displayName") or "LINE OA"
    basic_id = bot.get("basicId") or ""
    tid = (body.target_id or "").strip()

    cfg["line_oa_name"] = oa_name
    cfg["line_basic_id"] = basic_id
    cfg["line_channel_token"] = tok
    if cid:
        cfg["line_channel_id"] = cid
    if csec:
        cfg["line_channel_secret"] = csec
    if tid:
        cfg["line_target_id"] = tid
    else:
        cfg.pop("line_target_id", None)

    org.alert_thresholds = cfg
    db.add(AuditLog(actor=f"staff:{s.id}", action="connect_line_oa"))
    db.commit()
    return {
        "ok": True,
        "connected": True,
        "line_oa_name": oa_name,
        "line_basic_id": basic_id,
        "line_target_id": tid,
        "line_mode": "group" if tid else "broadcast",
    }


@router.post("/v1/staff/org/line/disconnect")
def disconnect_line_oa(s: StaffUser = Depends(current_staff), db: Session = Depends(get_db)):
    if s.role != "admin":
        raise HTTPException(403, "เฉพาะผู้ดูแลระบบเท่านั้น")
    org = db.get(Organization, s.org_id)
    cfg = dict(org.alert_thresholds or {})
    for k in ("line_oa_name", "line_basic_id", "line_channel_id", "line_channel_secret", "line_channel_token", "line_target_id"):
        cfg.pop(k, None)
    org.alert_thresholds = cfg
    db.add(AuditLog(actor=f"staff:{s.id}", action="disconnect_line_oa"))
    db.commit()
    return {"ok": True, "connected": False}


@router.post("/v1/webhooks/line/{org_id}")
async def line_webhook_callback(
    org_id: int,
    request: Request,
    x_line_signature: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    """รับ Webhook จาก LINE เมื่อเชิญบอทเข้ากลุ่มพยาบาลเพื่อจับ Group ID อัตโนมัติ"""
    org = db.get(Organization, org_id)
    if not org:
        raise HTTPException(404, "Organization not found")
    raw = await request.body()
    cfg = dict(org.alert_thresholds or {})
    secret = (cfg.get("line_channel_secret") or "").strip()
    if secret:
        expected = base64.b64encode(hmac.new(secret.encode(), raw, hashlib.sha256).digest()).decode()
        if not x_line_signature or not hmac.compare_digest(expected, x_line_signature):
            raise HTTPException(401, "Invalid X-Line-Signature")

    payload = json.loads(raw.decode() or "{}")
    captured = None
    for ev in payload.get("events", []):
        src = ev.get("source") or {}
        tid = src.get("groupId") or src.get("roomId") or src.get("userId")
        if tid:
            captured = tid
            cfg["line_target_id"] = tid
            org.alert_thresholds = cfg
            db.commit()
            break
    return {"ok": True, "captured_target_id": captured}
