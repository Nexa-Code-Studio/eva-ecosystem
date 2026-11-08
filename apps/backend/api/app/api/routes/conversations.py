import logging
import uuid

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse

from app.api.dependencies import (
    get_conversation_service,
    get_current_user,
    get_summary_stream_service,
)
from app.models.user import User
from app.schemas.conversation import (
    ConversationDetailResponse,
    ConversationListResponse,
    SendMessageRequest,
    SentMessageResponse,
    TodayConversationResponse,
    TodayMessagesResponse,
)
from app.services.conversation import ConversationService, SummaryStreamService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/conversations", tags=["Conversations"])


@router.get("", response_model=ConversationListResponse)
async def get_conversations(
    page: int = Query(1, ge=1, description="Page number for pagination"),
    limit: int = Query(10, ge=1, le=100, description="Items per page"),
    user: User = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
) -> ConversationListResponse:
    """Retrieve paginated conversations with messages and emotion mappings."""
    return await service.get_conversations(user.id, page=page, limit=limit)


@router.get("/today", response_model=TodayConversationResponse)
async def get_today_conversations(
    page: int = Query(1, ge=1, description="Page number for pagination"),
    limit: int = Query(10, ge=1, le=100, description="Items per page"),
    user: User = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
) -> TodayConversationResponse:
    """Retrieve today's voice call sessions with local time formatting and backend pagination."""
    return await service.get_today_conversations(user.id, page=page, limit=limit)


@router.get("/today/messages", response_model=TodayMessagesResponse)
async def get_today_conversation_messages(
    page: int = Query(1, ge=1, description="Page number for pagination"),
    limit: int = Query(10, ge=1, le=100, description="Items per page"),
    user: User = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
) -> TodayMessagesResponse:
    """Retrieve all messages from today's conversations ordered chronologically (Oldest First) with pagination."""
    return await service.get_today_messages(user.id, page=page, limit=limit)


@router.get("/{conversation_id}", response_model=ConversationDetailResponse)
async def get_conversation_by_id(
    conversation_id: str,
    service: ConversationService = Depends(get_conversation_service),
) -> ConversationDetailResponse:
    """Retrieve details and messages of a specific conversation session."""
    return await service.get_conversation_by_id(conversation_id)


@router.post("/{conversation_id}/messages", response_model=SentMessageResponse)
async def send_message(
    conversation_id: str,
    payload: SendMessageRequest,
    service: ConversationService = Depends(get_conversation_service),
) -> SentMessageResponse:
    """Send and persist a new message within a conversation."""
    return await service.send_message(conversation_id, payload)


@router.get("/{conversation_id}/summary/stream")
async def stream_conversation_summary(
    conversation_id: uuid.UUID,
    user: User = Depends(get_current_user),
    service: SummaryStreamService = Depends(get_summary_stream_service),
) -> StreamingResponse:
    """Stream 2-3 sentence empathetic counseling summary token-by-token using SSE and persist upon completion."""
    return await service.stream_summary(conversation_id, user.id)
