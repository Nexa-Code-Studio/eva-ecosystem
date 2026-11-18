from pydantic import BaseModel, EmailStr, Field


class RegisterPsychologistRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=200)
    title_degree: str = Field(default="M.Psi., Psikolog", max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=8)
    str_number: str = Field(..., min_length=3, max_length=100)
    sip_number: str | None = Field(default=None, max_length=100)
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
    certificate_doc_url: str = Field(..., min_length=5)
    str_number: str | None = None
    sip_number: str | None = None


class UpdateBankDetailsRequest(BaseModel):
    bank_name: str = Field(..., min_length=2, max_length=100)
    bank_account_number: str = Field(..., min_length=5, max_length=50)
    bank_account_holder: str = Field(..., min_length=2, max_length=200)


class VerifyPsychologistRequest(BaseModel):
    status: str = Field(..., pattern="^(verified|rejected|need_revision)$")
    notes: str | None = None


class ToggleAvailabilityRequest(BaseModel):
    is_online: bool
