import logging
import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import EmergencyContact, User
from app.schemas.user import (
    CreateEmergencyContactRequest,
    DeleteContactResponse,
    EmergencyContactResponse,
    UpdateEmergencyContactRequest,
)

logger = logging.getLogger(__name__)


class UserService:
    """Service handling user profile and emergency contacts management."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_emergency_contacts(self, user_id: uuid.UUID) -> list[EmergencyContactResponse]:
        """Fetch all emergency contacts registered for the specified user."""
        query = select(EmergencyContact).where(EmergencyContact.user_id == user_id)
        res = await self.db.execute(query)
        contacts = res.scalars().all()

        return [
            EmergencyContactResponse(
                id=str(c.id),
                name=c.name,
                relationship=c.relationship,
                phone=c.phone_number,
                isPrimary=c.is_primary,
            )
            for c in contacts
        ]

    async def create_emergency_contact(
        self, user_id: uuid.UUID, payload: CreateEmergencyContactRequest
    ) -> EmergencyContactResponse:
        """Create a new emergency contact, unsetting previous primary contact if requested."""
        if payload.is_primary:
            existing_q = select(EmergencyContact).where(
                EmergencyContact.user_id == user_id,
                EmergencyContact.is_primary == True,  # noqa: E712
            )
            existing_res = await self.db.execute(existing_q)
            for c in existing_res.scalars().all():
                c.is_primary = False

        contact = EmergencyContact(
            user_id=user_id,
            name=payload.name,
            relationship=payload.relationship,
            phone_number=payload.phone_number,
            is_primary=payload.is_primary,
        )
        self.db.add(contact)
        await self.db.commit()
        await self.db.refresh(contact)

        return EmergencyContactResponse(
            id=str(contact.id),
            name=contact.name,
            relationship=contact.relationship,
            phone=contact.phone_number,
            isPrimary=contact.is_primary,
        )

    async def update_emergency_contact(
        self, user_id: uuid.UUID, contact_id: str, payload: UpdateEmergencyContactRequest
    ) -> EmergencyContactResponse:
        """Update existing emergency contact details with ownership verification."""
        try:
            c_uuid = uuid.UUID(contact_id)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid contact ID")

        query = select(EmergencyContact).where(
            EmergencyContact.id == c_uuid,
            EmergencyContact.user_id == user_id,
        )
        res = await self.db.execute(query)
        contact = res.scalar_one_or_none()

        if not contact:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Contact not found")

        if payload.name is not None:
            contact.name = payload.name
        if payload.relationship is not None:
            contact.relationship = payload.relationship
        if payload.phone_number is not None:
            contact.phone_number = payload.phone_number
        if payload.is_primary is not None:
            if payload.is_primary:
                existing_q = select(EmergencyContact).where(
                    EmergencyContact.user_id == user_id,
                    EmergencyContact.is_primary == True,  # noqa: E712
                )
                existing_res = await self.db.execute(existing_q)
                for c in existing_res.scalars().all():
                    c.is_primary = False
            contact.is_primary = payload.is_primary

        await self.db.commit()
        await self.db.refresh(contact)

        return EmergencyContactResponse(
            id=str(contact.id),
            name=contact.name,
            relationship=contact.relationship,
            phone=contact.phone_number,
            isPrimary=contact.is_primary,
        )

    async def delete_emergency_contact(
        self, user_id: uuid.UUID, contact_id: str
    ) -> DeleteContactResponse:
        """Remove an emergency contact if owned by the user."""
        try:
            c_uuid = uuid.UUID(contact_id)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid contact ID")

        query = select(EmergencyContact).where(
            EmergencyContact.id == c_uuid,
            EmergencyContact.user_id == user_id,
        )
        res = await self.db.execute(query)
        contact = res.scalar_one_or_none()

        if not contact:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Contact not found")

        await self.db.delete(contact)
        await self.db.commit()

        return DeleteContactResponse()
