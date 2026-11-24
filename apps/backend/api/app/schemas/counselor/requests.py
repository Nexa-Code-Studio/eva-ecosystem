from pydantic import BaseModel, EmailStr, Field


class RegisterPsychologistRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=200)
    title_degree: str = Field(default="M.Psi., Psikolog", max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=8)
    str_number: str | None = Field(default=None, max_length=100)
    str_issuing_institution: str | None = Field(default=None, max_length=150)
    str_expiry_date: str | None = Field(default=None, max_length=50)
    str_doc_url: str | None = None
    sip_number: str | None = Field(default=None, max_length=100)
    sip_issuing_institution: str | None = Field(default=None, max_length=150)
    sip_expiry_date: str | None = Field(default=None, max_length=50)
    sip_doc_url: str | None = None
    document_type: str = Field(default="str", max_length=20)
    issuing_institution: str | None = Field(default="Kemenkes RI", max_length=150)
    document_expiry_date: str | None = Field(default="Seumur Hidup", max_length=50)
    education: str | None = Field(default=None, max_length=200)
    last_education: str | None = Field(default="S2 Magister Psikologi Profesi", max_length=150)
    association: str = Field(default="Himpunan Psikologi Indonesia (HIMPSI)", max_length=150)
    specializations: list[str] = Field(default_factory=list)
    years_of_experience: int = Field(default=1, ge=0)
    bio: str | None = None
    certificate_doc_url: str | None = None


class UpdatePsychologistProfileRequest(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=200)
    title_degree: str | None = Field(default=None, max_length=100)
    association: str | None = Field(default=None, max_length=150)
    specializations: list[str] | None = None
    years_of_experience: int | None = Field(default=None, ge=0)
    bio: str | None = None
    profile_photo_url: str | None = None
    buffer_time_minutes: int | None = Field(default=None, ge=0, le=60)


class ResubmitVerificationRequest(BaseModel):
    certificate_doc_url: str | None = Field(default=None, min_length=5)
    str_number: str | None = None
    str_issuing_institution: str | None = Field(default=None, max_length=150)
    str_expiry_date: str | None = Field(default=None, max_length=50)
    str_doc_url: str | None = None
    sip_number: str | None = None
    sip_issuing_institution: str | None = Field(default=None, max_length=150)
    sip_expiry_date: str | None = Field(default=None, max_length=50)
    sip_doc_url: str | None = None
    education: str | None = Field(default=None, max_length=200)


class UpdateBankDetailsRequest(BaseModel):
    bank_name: str = Field(..., min_length=2, max_length=100)
    bank_account_number: str = Field(..., min_length=5, max_length=50)
    bank_account_holder: str = Field(..., min_length=2, max_length=200)


class VerifyPsychologistRequest(BaseModel):
    status: str = Field(..., pattern="^(verified|rejected)$")
    notes: str | None = None


class ToggleDocumentVerificationRequest(BaseModel):
    verified: bool | None = None


class UpdateCounselorStatusRequest(BaseModel):
    status: str = Field(..., pattern="^(verified|suspended)$")
    notes: str | None = None


class ToggleAvailabilityRequest(BaseModel):
    is_online: bool


class DayBreakItem(BaseModel):
    start: str = Field(..., pattern=r"^\d{2}:\d{2}$", description="HH:MM format")
    end: str = Field(..., pattern=r"^\d{2}:\d{2}$", description="HH:MM format")
    label: str = Field(default="Istirahat", max_length=100)


class DayScheduleConfig(BaseModel):
    is_active: bool = True
    operating_hours: dict[str, str] = Field(
        default_factory=lambda: {"start": "08:00", "end": "17:00"}
    )
    breaks: list[DayBreakItem] = Field(default_factory=list)


class UpdateScheduleConfigRequest(BaseModel):
    schedule_config: dict[str, DayScheduleConfig] = Field(
        ...,
        description="Day-by-day practice schedule config keyed by lowercase day name (monday..sunday)",
    )
    buffer_time_minutes: int | None = Field(default=None, ge=0, le=60)


class UpdatePricingRequest(BaseModel):
    custom_price_per_session: float = Field(..., ge=10000.0, description="Custom consultation fee per 30-min session")


class SubmitSessionReviewRequest(BaseModel):
    rating: float = Field(..., ge=1.0, le=5.0, description="Star rating from 1.0 to 5.0")
    label: str | None = Field(default=None, max_length=150, description="Short review highlight label")
    review_text: str | None = Field(default=None, max_length=1000, description="Qualitative feedback comments")
    is_anonymous: bool = Field(default=True, description="Whether to hide patient identity")
