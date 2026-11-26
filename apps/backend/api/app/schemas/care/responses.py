from pydantic import BaseModel, ConfigDict, Field


class IceServerConfig(BaseModel):
    """WebRTC ICE server configuration supporting STUN and TURN credentials."""

    urls: list[str] | str
    username: str | None = None
    credential: str | None = None


class VideoTokenResponse(BaseModel):
    """Response containing room signaling credentials and ICE servers for WebRTC video call."""

    model_config = ConfigDict(from_attributes=True)

    session_id: str
    room_id: str
    token: str
    participant_id: str | None = None
    status: str
    ice_servers: list[str] = Field(
        default_factory=lambda: [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
        ]
    )
    ice_server_configs: list[IceServerConfig] = Field(default_factory=list)
    ws_url: str | None = None


class CallStatusResponse(BaseModel):
    """Response returned upon consultation session call status update."""

    model_config = ConfigDict(from_attributes=True)

    success: bool
    session_id: str
    status: str
    message: str


class CounselorSessionDetailResponse(BaseModel):
    """Detail response for counselor video consultation screen."""

    model_config = ConfigDict(from_attributes=True)

    session_id: str
    patient_id: str
    patient_name: str
    scheduled_time: str
    status: str
    signaling_token: str | None = None
    channel_name: str | None = None
    ice_servers: list[str] = Field(
        default_factory=lambda: ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]
    )
    ice_server_configs: list[IceServerConfig] = Field(default_factory=list)
    ws_url: str | None = None


class SessionActionResponse(BaseModel):
    """Response returned upon starting or ending a consultation session."""

    model_config = ConfigDict(from_attributes=True)

    success: bool
    session_id: str
    status: str


class PatientReviewTagSchema(BaseModel):
    label: str
    sentiment: str = "positive"


class PatientReviewItemSchema(BaseModel):
    id: str
    patient_name: str
    sentiment: str = "positive"
    label: str
    description: str
    rating: float = 5.0
    time_ago: str = "Baru saja"


class PatientStatsSchema(BaseModel):
    total_sessions: int = 0
    satisfaction_percentage: int = 0
    repeat_patient_rate: int = 0
    recovery_rate: int = 0


class CertificateItemSchema(BaseModel):
    title: str
    image_url: str


class PsychologistItemResponse(BaseModel):
    """Full psychologist model conforming to Eva Mobile's PsychologistModel schema."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    title: str
    registration_number: str
    avatar_url: str
    rating: float = 0.0
    review_count: int = 0
    experience_years: int = 1
    specialties: list[str] = Field(default_factory=list)
    patient_review_tags: list[str] = Field(default_factory=list)
    patient_reviews: list[str] = Field(default_factory=list)
    review_tags: list[PatientReviewTagSchema] = Field(default_factory=list)
    testimonials: list[PatientReviewItemSchema] = Field(default_factory=list)
    patient_stats: PatientStatsSchema = Field(default_factory=PatientStatsSchema)
    certifications: list[str] = Field(default_factory=list)
    certificate_items: list[CertificateItemSchema] = Field(default_factory=list)
    coins_per_session: int = 50
    fee_per_session: int = 50
    duration_minutes: int = 30
    available_online: bool = True
    clinic_affiliation: str | None = None
    bio: str = ""
    practitioner_type: str = "professional"
    has_psychologist_certificate: bool = True
    is_volunteer: bool = False
    level_tier: int | None = None
    level_name: str | None = None
    level_badge_icon: str | None = None


class ClinicItemResponse(BaseModel):
    """Partner clinic and mental health center response."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    address: str
    city: str
    distance_km: float = 1.0
    photo_url: str
    phone: str
    facilities: list[str] = Field(default_factory=list)
    rating: float = 4.8


class CommunityStatusResponse(BaseModel):
    """Discord Safe Space community status response."""

    model_config = ConfigDict(from_attributes=True)

    is_member: bool = False
    is_vip_active: bool = False
    vip_remaining_days: int = 0
    joined_at: str | None = None
    server_name: str = "Eva Safe Space ID"
    invite_url: str = "https://discord.gg/evasafespace"
    member_count: int = 1420


class OperatingHoursSchema(BaseModel):
    start: str = "08:00"
    end: str = "17:00"


class BlockedRangeSchema(BaseModel):
    start: str
    end: str
    type: str = "break"
    label: str | None = None


class TimeRangeSchema(BaseModel):
    start: str
    end: str


class CounselorTimelineResponse(BaseModel):
    """Availability timeline progress bar schema for dynamic booking in Eva Mobile."""

    model_config = ConfigDict(from_attributes=True)

    counselor_id: str
    date: str
    operating_hours: OperatingHoursSchema
    blocked_ranges: list[BlockedRangeSchema] = Field(default_factory=list)
    available_windows: list[TimeRangeSchema] = Field(default_factory=list)


class SessionReviewSummarySchema(BaseModel):
    """Summary of the patient's submitted review attached to a completed consultation session."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    session_id: str
    rating: float
    highlight_label: str | None = None
    review_text: str | None = None
    is_anonymous: bool = False
    created_at: str


class CareSessionResponse(BaseModel):
    """Consultation session response matching ConsultationSessionModel in Eva Mobile."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    psychologist: PsychologistItemResponse
    session_datetime: str
    status: str
    type: str = "onlineVideo"
    meeting_url: str | None = None
    location_name: str | None = None
    notes: str | None = None
    diagnosis_summary: str | None = None
    session_number: int = 1
    advice_list: list[str] = Field(default_factory=list)
    action_items: list[str] = Field(default_factory=list)
    mood_before: str | None = None
    mood_after: str | None = None
    duration_minutes: int = 30
    session_summary: str | None = None
    share_ai_chat_history: bool = False
    is_extended: bool = False
    has_review: bool = False
    my_review: SessionReviewSummarySchema | None = None


class CareRatingResponse(BaseModel):
    success: bool = True
    message: str = "Ulasan dan rating berhasil dikirim."


