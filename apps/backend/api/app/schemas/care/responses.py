from typing import Any
from pydantic import BaseModel, ConfigDict, Field


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


class CallStatusResponse(BaseModel):
    """Response returned upon consultation session call status update."""

    model_config = ConfigDict(from_attributes=True)

    success: bool
    session_id: str
    status: str


class ClinicalShareResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    share_receipt_id: str
    booking_id: str
    psychologist_id: str
    status: str
    authorized_categories: list[str] = Field(default_factory=list)
    expires_at: str | None = None
    created_at: str


class RevokeClinicalShareResponse(BaseModel):
    share_receipt_id: str
    status: str = "revoked"
    revoked_at: str
    message: str


class SharedClinicalBundleResponse(BaseModel):
    share_receipt_id: str
    booking_id: str
    psychologist_id: str
    status: str
    authorized_categories: list[str]
    items: dict[str, Any]
    created_at: str
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


class SessionActionResponse(BaseModel):
    """Response returned upon starting or ending a consultation session."""

    model_config = ConfigDict(from_attributes=True)

    success: bool
    session_id: str
    status: str


class ClinicalShareResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    share_receipt_id: str
    booking_id: str
    psychologist_id: str
    status: str
    authorized_categories: list[str] = Field(default_factory=list)
    expires_at: str | None = None
    created_at: str


class RevokeClinicalShareResponse(BaseModel):
    share_receipt_id: str
    status: str = "revoked"
    revoked_at: str
    message: str


class SharedClinicalBundleResponse(BaseModel):
    share_receipt_id: str
    booking_id: str
    psychologist_id: str
    status: str
    authorized_categories: list[str]
    items: dict[str, Any]
    created_at: str

