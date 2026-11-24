import re
from typing import Literal

from pydantic import BaseModel, Field, field_validator


TriggerType = Literal["sessions_milestone", "rating_milestone", "manual"]
_HEX_COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")
_CATEGORY_CODE_RE = re.compile(r"^[A-Z0-9_-]{2,16}$")


class UpsertCertificateTemplateRequest(BaseModel):
    code: str = Field(..., min_length=3, max_length=40)
    title: str = Field(..., min_length=4, max_length=200)
    subtitle: str = Field(..., min_length=4, max_length=250)
    category_code: str = Field(default="PRO", min_length=2, max_length=16)
    category_label: str = Field(default="Psikolog Mandiri", min_length=2, max_length=100)
    milestone_criteria: str = Field(..., min_length=3, max_length=250)
    description: str = Field(..., min_length=10, max_length=3000)
    badge_color: str = Field(default="#2563EB")
    trigger_type: TriggerType = "sessions_milestone"
    min_completed_sessions: int = Field(default=25, ge=0, le=10000)
    min_average_rating: float | None = Field(default=None, ge=1.0, le=5.0)
    auto_issue_enabled: bool = True
    is_active: bool = True
    svg_body_template: str | None = Field(default=None, max_length=15000)

    @field_validator("code")
    @classmethod
    def _normalize_code(cls, value: str) -> str:
        cleaned = value.strip().upper().replace(" ", "-")
        if len(cleaned) < 3:
            raise ValueError("Kode template sertifikat minimal 3 karakter.")
        return cleaned

    @field_validator("category_code")
    @classmethod
    def _normalize_category_code(cls, value: str) -> str:
        cleaned = value.strip().upper()
        if not _CATEGORY_CODE_RE.match(cleaned):
            raise ValueError("Kode kategori nomor sertifikat hanya boleh huruf/angka/tanda hubung (2-16 karakter).")
        return cleaned

    @field_validator("badge_color")
    @classmethod
    def _validate_hex_color(cls, value: str) -> str:
        cleaned = value.strip()
        if not _HEX_COLOR_RE.match(cleaned):
            raise ValueError("Warna lencana harus format hex #RRGGBB.")
        return cleaned.upper()


class IssueCertificateRequest(BaseModel):
    counselor_id: str = Field(..., min_length=8)
    template_id: str | None = None
    custom_title: str | None = Field(default=None, min_length=4, max_length=200)
    custom_subtitle: str | None = Field(default=None, min_length=3, max_length=250)
    custom_category_code: str | None = Field(default=None, min_length=2, max_length=16)
    custom_category_label: str | None = Field(default=None, min_length=2, max_length=100)
    custom_milestone_criteria: str | None = Field(default=None, min_length=3, max_length=250)
    custom_description: str | None = Field(default=None, min_length=10, max_length=3000)
    custom_badge_color: str | None = None

    @field_validator("custom_category_code")
    @classmethod
    def _normalize_custom_category(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip().upper()
        if not _CATEGORY_CODE_RE.match(cleaned):
            raise ValueError("Kode kategori sertifikat hanya boleh huruf/angka/tanda hubung.")
        return cleaned

    @field_validator("custom_badge_color")
    @classmethod
    def _validate_custom_hex(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not _HEX_COLOR_RE.match(cleaned):
            raise ValueError("Warna lencana harus format hex #RRGGBB.")
        return cleaned.upper()


class RevokeCertificateRequest(BaseModel):
    reason: str = Field(..., min_length=3, max_length=500)
