"""ITE Watch Care — backend รับข้อมูลจากนาฬิกา F520Pro ผ่านแอปมือถือ

รัน (dev):  uvicorn app.main:app --reload
เอกสาร API อัตโนมัติ: http://localhost:8000/docs
แดชบอร์ดเจ้าหน้าที่:   http://localhost:8000/dashboard
"""
from __future__ import annotations

from contextlib import asynccontextmanager
import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from .db import init_db
from .routers import auth_ingest, staff_ops, staff_patients


@asynccontextmanager
async def lifespan(_app: FastAPI):
    init_db()
    yield


_DEFAULT_ORIGINS = "https://ilifewatch.online,http://localhost:8000,http://127.0.0.1:8000"
_CORS_ORIGINS = [
    o.strip() for o in os.environ.get("CORS_ORIGINS", _DEFAULT_ORIGINS).split(",") if o.strip()
]

app = FastAPI(title="ITE Watch Care API", version="0.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(auth_ingest.router)
app.include_router(staff_patients.router)
app.include_router(staff_ops.router)

_STATIC = Path(__file__).parent / "static"
app.mount("/static", StaticFiles(directory=_STATIC), name="static")


@app.get("/", include_in_schema=False)
@app.get("/dashboard", include_in_schema=False)
def dashboard():
    return FileResponse(_STATIC / "dashboard.html")


@app.get("/healthz", include_in_schema=False)
def healthz():
    return {"ok": True}
