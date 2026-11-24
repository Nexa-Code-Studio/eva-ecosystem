import logging

from fastapi import APIRouter, WebSocket

from app.services.call import call_session_manager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/call", tags=["Call"])


@router.websocket("/ws/{session_id}")
async def websocket_call_endpoint(
    websocket: WebSocket,
    session_id: str,
    token: str | None = None,
    voice_mode: str | None = None,
) -> None:
    """Bi-directional WebSocket endpoint for AI Phone Call sessions."""
    await call_session_manager.handle_connection(
        websocket=websocket,
        session_id=session_id,
        token=token,
        voice_mode=voice_mode,
    )
