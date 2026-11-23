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

