import uuid

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status
from fastapi.responses import StreamingResponse

from app.api.dependencies import get_booth_feedback_service, get_current_admin
from app.models.user import User
from app.schemas.booth_feedback import (
    AdminBoothFeedbackListResponse,
    BoothFeedbackDeleteResponse,
    PublicBoothFeedbackCreateResponse,
)
from app.services.booth_feedback import BoothFeedbackService

public_router = APIRouter(prefix="/content/booth-feedbacks", tags=["Booth Feedback"])
admin_router = APIRouter(prefix="/admin/content/booth-feedbacks", tags=["Admin Booth Feedback"])


@public_router.post("", response_model=PublicBoothFeedbackCreateResponse, status_code=status.HTTP_201_CREATED)
async def submit_booth_feedback(
    rating: int = Form(..., ge=1, le=5),
    message: str = Form(..., min_length=5, max_length=2000),
    visitor_name: str | None = Form(default=None, max_length=120),
    visitor_contact: str | None = Form(default=None, max_length=150),
    event_label: str | None = Form(default="Event Booth EVA", max_length=120),
    photos: list[UploadFile] = File(...),
    service: BoothFeedbackService = Depends(get_booth_feedback_service),
) -> PublicBoothFeedbackCreateResponse:
    """Submit event booth feedback, 1-5 rating, and 1..5 selfie photos."""
    return await service.submit_feedback(
        rating=rating, message=message, visitor_name=visitor_name,
        visitor_contact=visitor_contact, event_label=event_label, photos=photos,
    )


@admin_router.get("", response_model=AdminBoothFeedbackListResponse)
async def list_admin_booth_feedbacks(
    rating: int | None = Query(default=None, ge=1, le=5),
    search: str | None = Query(default=None, max_length=120),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=10, ge=1, le=50),
    admin: User = Depends(get_current_admin),
    service: BoothFeedbackService = Depends(get_booth_feedback_service),
) -> AdminBoothFeedbackListResponse:
    """List submitted event booth feedbacks with rating summary and filters (Admin)."""
    return await service.list_admin_feedbacks(
        rating=rating, search=search, page=page, page_size=page_size,
    )


@admin_router.get("/{feedback_id}/photos/{photo_id}")
async def stream_admin_booth_feedback_photo(
    feedback_id: uuid.UUID,
    photo_id: uuid.UUID,
    admin: User = Depends(get_current_admin),
    service: BoothFeedbackService = Depends(get_booth_feedback_service),
) -> StreamingResponse:
    """Stream a private uploaded booth selfie image for authenticated Admin Portal viewing."""
    stream, mime_type, filename = await service.open_photo_stream(feedback_id, photo_id)
    headers = {"Content-Disposition": f'inline; filename="{filename}"', "Cache-Control": "private, max-age=300"}
    return StreamingResponse(stream, media_type=mime_type, headers=headers)


@admin_router.delete("/{feedback_id}", response_model=BoothFeedbackDeleteResponse)
async def delete_admin_booth_feedback(
    feedback_id: uuid.UUID,
    admin: User = Depends(get_current_admin),
    service: BoothFeedbackService = Depends(get_booth_feedback_service),
) -> BoothFeedbackDeleteResponse:
    """Delete an event booth feedback record and its stored selfie files (Admin)."""
    return await service.delete_feedback(feedback_id)
