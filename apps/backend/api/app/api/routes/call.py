import logging

from fastapi import APIRouter, Depends, WebSocket

from app.api.dependencies import get_call_synthesis_service, get_current_user
from app.models.user import User
from app.schemas.call import CallSynthesizeRequest, CallSynthesizeResponse
from app.services.call import CallSynthesisService, call_session_manager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/call", tags=["Call"])


@router.post("/synthesize", response_model=CallSynthesizeResponse)
async def synthesize_call_session(
    payload: CallSynthesizeRequest,
    _user: User = Depends(get_current_user),
    service: CallSynthesisService = Depends(get_call_synthesis_service),
) -> CallSynthesizeResponse:
    """Stateless post-session AI synthesis for local-first clients (zero DB persistence)."""
    return await service.synthesize_from_request(payload)


@router.websocket("/ws/{session_id}")
async def websocket_call_endpoint(
    websocket: WebSocket,
    session_id: str,
    token: str | None = None,
    voice_mode: str | None = None,
    privacy_mode: str | None = None,
) -> None:
    """Bi-directional WebSocket endpoint for AI Phone Call sessions."""
    await call_session_manager.handle_connection(
        websocket=websocket,
        session_id=session_id,
        token=token,
        voice_mode=voice_mode,
        privacy_mode=privacy_mode,
    )
