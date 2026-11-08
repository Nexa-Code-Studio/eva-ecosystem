import logging

from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user, get_user_service
from app.models.user import User
from app.schemas.user import (
    CreateEmergencyContactRequest,
    DeleteContactResponse,
    EmergencyContactResponse,
    UpdateEmergencyContactRequest,
)
from app.services.user import UserService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/emergency-contacts", response_model=list[EmergencyContactResponse])
async def get_emergency_contacts(
    user: User = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> list[EmergencyContactResponse]:
    """Retrieve all emergency contacts for the authenticated user."""
    return await service.get_emergency_contacts(user.id)


@router.post("/emergency-contacts", response_model=EmergencyContactResponse)
async def create_emergency_contact(
    payload: CreateEmergencyContactRequest,
    user: User = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> EmergencyContactResponse:
    """Create a new emergency contact for the authenticated user."""
    return await service.create_emergency_contact(user.id, payload)


@router.put("/emergency-contacts/{contact_id}", response_model=EmergencyContactResponse)
async def update_emergency_contact(
    contact_id: str,
    payload: UpdateEmergencyContactRequest,
    user: User = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> EmergencyContactResponse:
    """Update existing emergency contact details."""
    return await service.update_emergency_contact(user.id, contact_id, payload)


@router.delete("/emergency-contacts/{contact_id}", response_model=DeleteContactResponse)
async def delete_emergency_contact(
    contact_id: str,
    user: User = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> DeleteContactResponse:
    """Delete an emergency contact owned by the user."""
    return await service.delete_emergency_contact(user.id, contact_id)
