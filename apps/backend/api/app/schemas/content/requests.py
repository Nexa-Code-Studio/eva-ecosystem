from pydantic import BaseModel, Field, field_validator


class UpdateCrisisConfigRequest(BaseModel):
    hotline_number: str = Field(..., min_length=2, max_length=50)
    hotline_label: str = Field(..., min_length=3, max_length=150)
    extreme_depression_threshold: int = Field(..., ge=1, le=42)
    extreme_anxiety_threshold: int = Field(..., ge=1, le=42)
    auto_safety_net_modal: bool = True
    allow_direct_independent_referral: bool = True

    @field_validator("hotline_number")
    @classmethod
    def _normalize_hotline_number(cls, value: str) -> str:
        cleaned = value.strip().upper()
        if len(cleaned) < 2:
            raise ValueError("Nomor hotline darurat minimal 2 karakter.")
        return cleaned

    @field_validator("hotline_label")
    @classmethod
    def _normalize_hotline_label(cls, value: str) -> str:
        cleaned = value.strip()
        if len(cleaned) < 3:
            raise ValueError("Label layanan darurat minimal 3 karakter.")
        return cleaned


class _FaqBaseRequest(BaseModel):
    category: str = Field(..., min_length=2, max_length=100)
    question: str = Field(..., min_length=5, max_length=500)
    answer: str = Field(..., min_length=5, max_length=5000)

    @field_validator("category")
    @classmethod
    def _normalize_category(cls, value: str) -> str:
        cleaned = value.strip().upper()
        if len(cleaned) < 2:
            raise ValueError("Kategori FAQ minimal 2 karakter.")
        return cleaned

    @field_validator("question", "answer")
    @classmethod
    def _normalize_text(cls, value: str) -> str:
        cleaned = value.strip()
        if len(cleaned) < 5:
            raise ValueError("Pertanyaan dan jawaban FAQ minimal 5 karakter.")
        return cleaned


class CreateFaqRequest(_FaqBaseRequest):
    sort_order: int | None = Field(default=None, ge=0, le=9999)
    is_published: bool = True


class UpdateFaqRequest(_FaqBaseRequest):
    sort_order: int | None = Field(default=None, ge=0, le=9999)
    is_published: bool | None = None
