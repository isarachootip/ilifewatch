"""รหัสผ่าน (scrypt) และ token แบบลงลายเซ็น HMAC — ใช้ไลบรารีมาตรฐานเท่านั้น

ระบบจริง: ตั้ง SECRET_KEY ผ่าน environment และพิจารณาใช้ OAuth2/OIDC สำหรับเจ้าหน้าที่
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import time

SECRET_KEY = os.environ.get("SECRET_KEY", "dev-only-change-me")
PATIENT_TOKEN_DAYS = 90
STAFF_TOKEN_HOURS = 12


def hash_secret(raw: str) -> str:
    salt = secrets.token_bytes(16)
    dk = hashlib.scrypt(raw.encode(), salt=salt, n=2**14, r=8, p=1)
    return f"scrypt${base64.b64encode(salt).decode()}${base64.b64encode(dk).decode()}"


def verify_secret(raw: str, stored: str) -> bool:
    try:
        _, salt_b64, dk_b64 = stored.split("$")
        dk = hashlib.scrypt(raw.encode(), salt=base64.b64decode(salt_b64), n=2**14, r=8, p=1)
        return hmac.compare_digest(dk, base64.b64decode(dk_b64))
    except Exception:
        return False


def _b64(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).decode().rstrip("=")


def _unb64(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def make_token(kind: str, subject_id: int, org_id: int, role: str | None = None) -> str:
    ttl = PATIENT_TOKEN_DAYS * 86400 if kind == "patient" else STAFF_TOKEN_HOURS * 3600
    payload = {"k": kind, "sub": subject_id, "org": org_id, "role": role, "exp": int(time.time()) + ttl}
    body = _b64(json.dumps(payload, separators=(",", ":")).encode())
    sig = _b64(hmac.new(SECRET_KEY.encode(), body.encode(), hashlib.sha256).digest())
    return f"{body}.{sig}"


def read_token(token: str) -> dict | None:
    try:
        body, sig = token.split(".")
        expected = _b64(hmac.new(SECRET_KEY.encode(), body.encode(), hashlib.sha256).digest())
        if not hmac.compare_digest(sig, expected):
            return None
        payload = json.loads(_unb64(body))
        if payload["exp"] < time.time():
            return None
        return payload
    except Exception:
        return None


def new_enrollment_code() -> str:
    # ตัดตัวอักษรที่สับสนง่าย (0/O, 1/I)
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return "".join(secrets.choice(alphabet) for _ in range(8))


def new_pin() -> str:
    return f"{secrets.randbelow(10**6):06d}"
