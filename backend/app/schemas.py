from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, model_validator


class LoginIn(BaseModel):
    enrollment_code: str
    pin: str


class StaffLoginIn(BaseModel):
    email: str
    password: str


class DeviceIn(BaseModel):
    mac: str | None = None
    firmware: str | None = None
    model: str | None = None


class BpIn(BaseModel):
    measured_at: datetime
    systolic: int = Field(ge=40, le=300)
    diastolic: int = Field(ge=20, le=200)
    pulse: int | None = Field(default=None, ge=0, le=250)
    method: Literal["cuff", "ppg"] = "ppg"
    source: Literal["live", "watch", "auto"] = "live"
    status: str | None = None
    credibility: int | None = None


class EcgIn(BaseModel):
    measured_at: datetime
    duration_sec: int | None = None
    sample_rate_hz: int | None = None
    avg_heart_rate: int | None = None
    avg_hrv: int | None = None
    avg_qt: int | None = None
    avg_resp_rate: int | None = None
    waveform: list[int] = Field(default_factory=list, max_length=200_000)
    source: Literal["live", "watch"] = "live"


_VITAL_RANGES: dict[str, tuple[float, float]] = {
    "heart_rate": (20.0, 260.0),
    "spo2": (50.0, 100.0),
    "temperature": (30.0, 45.0),
    "steps": (0.0, 200_000.0),
    "stress": (0.0, 100.0),
    "hrv": (0.0, 300.0),
}


class VitalIn(BaseModel):
    at: datetime
    metric: Literal["heart_rate", "spo2", "steps", "temperature", "stress", "hrv"]
    value: float

    @model_validator(mode="after")
    def _validate_vital_range(self) -> VitalIn:
        lo, hi = _VITAL_RANGES[self.metric]
        if not (lo <= self.value <= hi):
            raise ValueError(f"{self.metric} value {self.value} out of valid range [{lo}, {hi}]")
        return self


class SleepIn(BaseModel):
    start: datetime
    end: datetime
    deep_minutes: int = 0
    light_minutes: int = 0
    wake_count: int = 0
    quality: int | None = None
    curve: str | None = None


class IngestIn(BaseModel):
    device: DeviceIn = Field(default_factory=DeviceIn)
    bp: list[BpIn] = Field(default_factory=list, max_length=5000)
    ecg: list[EcgIn] = Field(default_factory=list, max_length=50)
    vitals: list[VitalIn] = Field(default_factory=list, max_length=50_000)
    sleep: list[SleepIn] = Field(default_factory=list, max_length=100)


class PatientCreate(BaseModel):
    display_name: str
    sex: Literal["M", "F"]
    birth_year: int = Field(ge=1900, le=2030)
    height_cm: int = Field(ge=80, le=250)
    weight_kg: int = Field(ge=20, le=300)
    emergency_contact: str | None = None


class AckIn(BaseModel):
    note: str | None = None


class EcgReviewIn(BaseModel):
    note: str
