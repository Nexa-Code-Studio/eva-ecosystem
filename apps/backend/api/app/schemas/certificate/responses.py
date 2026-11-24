from datetime import datetime
from pydantic import BaseModel, ConfigDict


class CertificateTemplateResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    code: str
    title: str
    subtitle: str
    category_code: str
    category_label: str
    milestone_criteria: str
    description: str
    badge_color: str
    trigger_type: str
    min_completed_sessions: int
    min_average_rating: float | None = None
    auto_issue_enabled: bool
    is_active: bool
    svg_body_template: str | None = None
    created_at: datetime
    updated_at: datetime


class PsychologistCertificateResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    certificate_number: str
    sequence_number: int
    issue_year: int
    category_code: str
    counselor_id: str
    template_id: str | None = None
    title: str
    subtitle: str
    recipient_name: str
    str_number: str
    milestone_criteria: str
    category_label: str
    description: str
    badge_color: str
    trigger_source: str
    status: str
    issue_date_label: str
    issued_at: datetime
    revoked_at: datetime | None = None
    revocation_reason: str | None = None


class CounselorCertificateEligibilityResponse(BaseModel):
    counselor_id: str
    full_name: str
    str_number: str
    verification_status: str
    completed_sessions_count: int
    average_rating: float | None = None
    active_certificates_count: int


class CertificateEvaluationSummaryResponse(BaseModel):
    evaluated_counselors: int
    newly_issued_count: int
    issued_certificates: list[PsychologistCertificateResponse]
