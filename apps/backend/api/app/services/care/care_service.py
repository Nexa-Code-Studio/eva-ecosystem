import logging
import uuid
from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import create_room_token
from app.models.counselor import ConsultationSession, PsychologistProfile
from app.models.enums import ConsultationSessionStatus
from app.schemas.care.requests import UpdateCallStatusRequest
from app.schemas.care.responses import (
    CallStatusResponse,
    CounselorSessionDetailResponse,
    SessionActionResponse,
    VideoTokenResponse,
)

logger = logging.getLogger(__name__)


class CareService:
    """Domain service managing teleconsultation video rooms, access control, and call lifecycle."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_video_token(self, session_id: uuid.UUID, user_id: uuid.UUID) -> VideoTokenResponse:
        """Validate participation and generate secure WebRTC / signaling room token."""
        stmt = (
            select(ConsultationSession)
            .where(ConsultationSession.id == session_id)
            .options(
                selectinload(ConsultationSession.patient),
                selectinload(ConsultationSession.counselor),
            )
        )
        res = await self.db.execute(stmt)
        session = res.scalar_one_or_none()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi konsultasi tidak ditemukan.",
            )

        # Access Control: User must be either the scheduled patient or counselor
        is_patient = session.patient_id == user_id
        is_counselor = session.counselor and session.counselor.user_id == user_id

        if not (is_patient or is_counselor):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak: Hanya pengguna atau psikolog terdaftar yang dapat memasuki ruang konsultasi.",
            )

        role = "counselor" if is_counselor else "patient"

        # Initialize video room identifier if not yet assigned
        if not session.video_room_id:
            session.video_room_id = f"eva-room-{session.session_code}"
            await self.db.commit()
            await self.db.refresh(session)

        token = create_room_token(
            session_id=str(session.id),
            room_id=session.video_room_id,
            user_id=str(user_id),
            role=role,
        )

        return VideoTokenResponse(
            session_id=str(session.id),
            room_id=session.video_room_id,
            token=token,
            participant_id=str(user_id),
            status=session.status,
            ice_servers=[
                "stun:stun.l.google.com:19302",
                "stun:stun1.l.google.com:19302",
            ],
        )

    async def update_call_status(
        self,
        session_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: UpdateCallStatusRequest,
    ) -> CallStatusResponse:
        """Update live call session status, actual duration, and end time."""
        stmt = (
            select(ConsultationSession)
            .where(ConsultationSession.id == session_id)
            .options(selectinload(ConsultationSession.counselor))
        )
        res = await self.db.execute(stmt)
        session = res.scalar_one_or_none()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi konsultasi tidak ditemukan.",
            )

        is_patient = session.patient_id == user_id
        is_counselor = session.counselor and session.counselor.user_id == user_id
        if not (is_patient or is_counselor):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak.",
            )

        target_status = payload.status.lower().strip()
        now = datetime.now(UTC)

        if target_status in ("active", "live"):
            session.status = ConsultationSessionStatus.LIVE.value
            if not session.actual_start_time:
                session.actual_start_time = now
        elif target_status in ("completed", "ended"):
            session.status = ConsultationSessionStatus.COMPLETED.value
            if not session.actual_end_time:
                session.actual_end_time = now
            if payload.duration_seconds and payload.duration_seconds > 0:
                session.duration_minutes = max(1, payload.duration_seconds // 60)
            if payload.notes:
                notes_dict = session.soap_notes or {}
                notes_dict["quick_notes"] = payload.notes
                session.soap_notes = notes_dict
        elif target_status in ("missed", "cancelled"):
            session.status = ConsultationSessionStatus.CANCELLED.value

        await self.db.commit()
        await self.db.refresh(session)

        return CallStatusResponse(
            success=True,
            session_id=str(session.id),
            status=session.status,
            message="Status panggilan konsultasi berhasil disinkronkan.",
        )

    async def get_counselor_session_detail(
        self, session_id: uuid.UUID, user_id: uuid.UUID
    ) -> CounselorSessionDetailResponse:
        """Fetch session metadata for counselor mobile video consultation screen."""
        stmt = (
            select(ConsultationSession)
            .where(ConsultationSession.id == session_id)
            .options(
                selectinload(ConsultationSession.patient),
                selectinload(ConsultationSession.counselor),
            )
        )
        res = await self.db.execute(stmt)
        session = res.scalar_one_or_none()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi konsultasi tidak ditemukan.",
            )

        patient_name = session.patient.email.split("@")[0].capitalize() if session.patient else "Pasien"
        channel_name = session.video_room_id or f"eva-room-{session.session_code}"
        token = create_room_token(str(session.id), channel_name, str(user_id), "counselor")

        return CounselorSessionDetailResponse(
            session_id=str(session.id),
            patient_id=str(session.patient_id),
            patient_name=patient_name,
            scheduled_time=session.scheduled_start_time.isoformat() if session.scheduled_start_time else datetime.now(UTC).isoformat(),
            status=session.status,
            signaling_token=token,
            channel_name=channel_name,
        )

    async def start_session(self, session_id: uuid.UUID, user_id: uuid.UUID) -> SessionActionResponse:
        """Mark consultation session as started / live."""
        update_req = UpdateCallStatusRequest(status="live")
        res = await self.update_call_status(session_id, user_id, update_req)
        return SessionActionResponse(success=res.success, session_id=res.session_id, status=res.status)

    async def end_session(
        self,
        session_id: uuid.UUID,
        user_id: uuid.UUID,
        duration_seconds: int = 0,
        quick_notes: list[str] | None = None,
    ) -> SessionActionResponse:
        """Mark consultation session as completed with duration and quick notes."""
        update_req = UpdateCallStatusRequest(
            status="completed",
            duration_seconds=duration_seconds,
            notes=quick_notes,
        )
        res = await self.update_call_status(session_id, user_id, update_req)
        return SessionActionResponse(success=res.success, session_id=res.session_id, status=res.status)
