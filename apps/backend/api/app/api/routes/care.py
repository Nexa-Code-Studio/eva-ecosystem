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
    UpdateCallStatusRequest,
    VideoTokenResponse,
)
from app.services.care import CareService, WebRtcSignalingManager

router = APIRouter(prefix="/care", tags=["Care"])


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
