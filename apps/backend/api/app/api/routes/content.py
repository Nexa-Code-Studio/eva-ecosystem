import uuid

from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_content_service, get_current_admin
from app.models.user import User
from app.schemas.content import (
    CreateFaqRequest,
    CrisisConfigResponse,
    FaqDeleteResponse,
    FaqEntryResponse,
    UpdateCrisisConfigRequest,
    UpdateFaqRequest,
)
from app.services.content import ContentService

public_router = APIRouter(prefix="/content", tags=["Content"])
admin_router = APIRouter(prefix="/admin/content", tags=["Admin Content"])


@public_router.get("/crisis-config", response_model=CrisisConfigResponse)
async def get_public_crisis_config(
    service: ContentService = Depends(get_content_service),
) -> CrisisConfigResponse:
    """Get active SafetyNet crisis hotline and DASS-21 intervention thresholds."""
    return await service.get_crisis_config()


@public_router.get("/faqs", response_model=list[FaqEntryResponse])
async def list_public_faqs(
    service: ContentService = Depends(get_content_service),
) -> list[FaqEntryResponse]:
    """List published website FAQ entries ordered for Landing Page display."""
    return await service.list_faqs(published_only=True)


@admin_router.put("/crisis-config", response_model=CrisisConfigResponse)
async def update_admin_crisis_config(
    payload: UpdateCrisisConfigRequest,
    admin: User = Depends(get_current_admin),
    service: ContentService = Depends(get_content_service),
) -> CrisisConfigResponse:
    """Update active SafetyNet crisis protocol and DASS-21 intervention thresholds (Admin)."""
    return await service.update_crisis_config(payload)


@admin_router.get("/faqs", response_model=list[FaqEntryResponse])
async def list_admin_faqs(
    admin: User = Depends(get_current_admin),
    service: ContentService = Depends(get_content_service),
) -> list[FaqEntryResponse]:
    """List all FAQ entries including unpublished drafts (Admin)."""
    return await service.list_faqs(published_only=False)


@admin_router.post("/faqs", response_model=FaqEntryResponse, status_code=status.HTTP_201_CREATED)
async def create_admin_faq(
    payload: CreateFaqRequest,
    admin: User = Depends(get_current_admin),
    service: ContentService = Depends(get_content_service),
) -> FaqEntryResponse:
    """Create a new website FAQ entry (Admin)."""
    return await service.create_faq(payload)


@admin_router.put("/faqs/{faq_id}", response_model=FaqEntryResponse)
async def update_admin_faq(
    faq_id: uuid.UUID,
    payload: UpdateFaqRequest,
    admin: User = Depends(get_current_admin),
    service: ContentService = Depends(get_content_service),
) -> FaqEntryResponse:
    """Update an existing website FAQ entry (Admin)."""
    return await service.update_faq(faq_id, payload)


@admin_router.patch("/faqs/{faq_id}/toggle", response_model=FaqEntryResponse)
async def toggle_admin_faq_published(
    faq_id: uuid.UUID,
    admin: User = Depends(get_current_admin),
    service: ContentService = Depends(get_content_service),
) -> FaqEntryResponse:
    """Toggle publish visibility of a website FAQ entry (Admin)."""
    return await service.toggle_faq_published(faq_id)


@admin_router.delete("/faqs/{faq_id}", response_model=FaqDeleteResponse)
async def delete_admin_faq(
    faq_id: uuid.UUID,
    admin: User = Depends(get_current_admin),
    service: ContentService = Depends(get_content_service),
) -> FaqDeleteResponse:
    """Delete a website FAQ entry permanently (Admin)."""
    return await service.delete_faq(faq_id)
