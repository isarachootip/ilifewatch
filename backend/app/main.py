"""ITE Watch Care — backend รับข้อมูลจากนาฬิกา F520Pro ผ่านแอปมือถือ

รัน (dev):  uvicorn app.main:app --reload
เอกสาร API อัตโนมัติ: http://localhost:8000/docs
แดชบอร์ดเจ้าหน้าที่:   http://localhost:8000/dashboard
"""
from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from .db import init_db
from .routers import auth_ingest, staff_ops, staff_patients


@asynccontextmanager
async def lifespan(_app: FastAPI):
    init_db()
    yield


app = FastAPI(title="ITE Watch Care API", version="0.1.0", lifespan=lifespan)
# ระบบจริง: จำกัด allow_origins ให้เหลือเฉพาะโดเมนแดชบอร์ดของหน่วยงาน
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

app.include_router(auth_ingest.router)
app.include_router(staff_patients.router)
app.include_router(staff_ops.router)

_STATIC = Path(__file__).parent / "static"


@app.get("/", include_in_schema=False)
@app.get("/dashboard", include_in_schema=False)
def dashboard():
    return FileResponse(_STATIC / "dashboard.html")


@app.get("/healthz", include_in_schema=False)
def healthz():
    return {"ok": True}
