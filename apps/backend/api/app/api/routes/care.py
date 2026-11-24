import uuid

from fastapi import APIRouter, Depends, Query, WebSocket, status

from app.api.dependencies import (
    get_care_service,
    get_current_user,
    get_webrtc_signaling_manager,
)
from app.models.user import User
from app.schemas.care import (
    CallStatusResponse,
    CareSessionResponse,
    ClinicItemResponse,
    CommunityStatusResponse,
    PsychologistItemResponse,
    UpdateCallStatusRequest,
    VideoTokenResponse,
)
from app.services.care import CareService, WebRtcSignalingManager

router = APIRouter(prefix="/care", tags=["Care"])
community_router = APIRouter(prefix="/community", tags=["Community"])


@router.get("/psychologists", response_model=list[PsychologistItemResponse])
async def list_care_psychologists(
    category: str | None = Query(default=None),
    q: str | None = Query(default=None),
    service: CareService = Depends(get_care_service),
) -> list[PsychologistItemResponse]:
    """Retrieve verified psychologists, psychiatrists, and volunteer counselors."""
    return await service.get_psychologists(category=category, query=q)


@router.get("/clinics", response_model=list[ClinicItemResponse])
async def list_partner_clinics(
    q: str | None = Query(default=None),
    service: CareService = Depends(get_care_service),
) -> list[ClinicItemResponse]:
    """Retrieve verified mental health clinics and consultation centers."""
    return await service.get_clinics(query=q)


@router.get("/sessions", response_model=list[CareSessionResponse])
async def list_user_care_sessions(
    user: User = Depends(get_current_user),
    service: CareService = Depends(get_care_service),
) -> list[CareSessionResponse]:
    """Retrieve upcoming and historical consultation sessions for authenticated patient."""
    return await service.get_user_sessions(user.id)


@router.get("/community/status", response_model=CommunityStatusResponse)
@community_router.get("/status", response_model=CommunityStatusResponse)
async def get_community_status(
    service: CareService = Depends(get_care_service),
) -> CommunityStatusResponse:
    """Retrieve Discord Safe Space community status and VIP trial availability."""
    return await service.get_community_status()


@router.post("/community/join", response_model=CommunityStatusResponse)
@community_router.post("/join", response_model=CommunityStatusResponse)
async def join_community(
    user: User = Depends(get_current_user),
    service: CareService = Depends(get_care_service),
) -> CommunityStatusResponse:
    """Join community and activate 30-day VIP Community Pass trial."""
    return await service.join_community_vip_trial(user.id)


@router.post(
    "/sessions/{session_id}/video-token",
    response_model=VideoTokenResponse,
    status_code=status.HTTP_201_CREATED,
)
async def generate_video_token(
    session_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: CareService = Depends(get_care_service),
) -> VideoTokenResponse:
    """Generate authenticated WebRTC / signaling room token for teleconsultation video call."""
    return await service.get_video_token(session_id, user.id)


@router.post("/sessions/{session_id}/status", response_model=CallStatusResponse)
async def update_call_status(
    session_id: uuid.UUID,
    payload: UpdateCallStatusRequest,
    user: User = Depends(get_current_user),
    service: CareService = Depends(get_care_service),
) -> CallStatusResponse:
    """Update call session connection status, duration, and completion event."""
    return await service.update_call_status(session_id, user.id, payload)


@router.websocket("/ws/{session_id}")
async def care_webrtc_signaling_ws(
    websocket: WebSocket,
    session_id: str,
    token: str | None = Query(default=None),
    signaling_manager: WebRtcSignalingManager = Depends(get_webrtc_signaling_manager),
) -> None:
    """Real-time P2P WebRTC signaling endpoint backed by Redis Pub/Sub and grace period."""
    await signaling_manager.handle_connection(websocket, session_id=session_id, token=token)

