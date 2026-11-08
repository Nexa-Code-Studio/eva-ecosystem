import logging

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_user, get_diary_service
from app.models.user import User
from app.schemas.diary import (
    CreateDiaryRequest,
    DeleteDiaryResponse,
    DiaryEntryResponse,
)
from app.services.diary import DiaryService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/diaries", tags=["Diaries"])


@router.get("", response_model=list[DiaryEntryResponse])
async def get_diaries(
    mood: str | None = Query(None),
    search: str | None = Query(None),
    user: User = Depends(get_current_user),
    service: DiaryService = Depends(get_diary_service),
) -> list[DiaryEntryResponse]:
    """Retrieve all diary entries for authenticated user with optional mood and search filters."""
    return await service.get_diaries(user.id, mood=mood, search=search)


@router.get("/today", response_model=DiaryEntryResponse)
async def get_today_diary(
    user: User = Depends(get_current_user),
    service: DiaryService = Depends(get_diary_service),
) -> DiaryEntryResponse:
    """Retrieve today's diary entry, auto-generating via LLM if not yet present."""
    return await service.get_today_diary(user.id)


@router.get("/{diary_id}", response_model=DiaryEntryResponse)
async def get_diary_by_id(
    diary_id: str,
    user: User = Depends(get_current_user),
    service: DiaryService = Depends(get_diary_service),
) -> DiaryEntryResponse:
    """Retrieve a single diary entry by ID with ownership verification."""
    return await service.get_diary_by_id(user.id, diary_id)


@router.post("/generate", response_model=DiaryEntryResponse)
async def generate_today_diary(
    user: User = Depends(get_current_user),
    service: DiaryService = Depends(get_diary_service),
) -> DiaryEntryResponse:
    """Force re-synthesis of today's diary from all conversation transcripts."""
    return await service.generate_today_diary(user.id)


@router.post("", response_model=DiaryEntryResponse)
async def create_diary(
    payload: CreateDiaryRequest,
    user: User = Depends(get_current_user),
    service: DiaryService = Depends(get_diary_service),
) -> DiaryEntryResponse:
    """Create or append today's custom diary entry reflection."""
    return await service.create_diary(user.id, payload)


@router.delete("/{diary_id}", response_model=DeleteDiaryResponse)
async def delete_diary(
    diary_id: str,
    service: DiaryService = Depends(get_diary_service),
) -> DeleteDiaryResponse:
    """Delete a diary entry by ID."""
    return await service.delete_diary(diary_id)
