import logging
import uuid
from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.orm.attributes import flag_modified

from app.core.security import create_room_token
from app.models.counselor import ConsultationSession, PsychologistProfile
from app.models.enums import ConsultationSessionStatus
from app.schemas.care.requests import ClinicalShareRequest, UpdateCallStatusRequest
from app.schemas.care.responses import (
    CallStatusResponse,
    ClinicalShareResponse,
    CounselorSessionDetailResponse,
    RevokeClinicalShareResponse,
    SessionActionResponse,
    SharedClinicalBundleResponse,
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

    async def create_clinical_share(
        self,
        booking_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: ClinicalShareRequest,
    ) -> ClinicalShareResponse:
        """Create consent-based clinical data share bundle tied to a consultation booking."""
        stmt = select(ConsultationSession).where(ConsultationSession.id == booking_id)
        res = await self.db.execute(stmt)
        session = res.scalar_one_or_none()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi booking konsultasi tidak ditemukan.",
            )

        if session.patient_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak: Hanya pasien pemilik booking yang dapat membagikan data klinis.",
            )

        if session.counselor_id != payload.psychologist_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Penerima data klinis tidak cocok dengan psikolog yang ditugaskan.",
            )

        receipt_id = f"rec-{uuid.uuid4()}"
        now_utc = datetime.now(UTC)
        bundle_items = payload.items.model_dump()
        authorized_categories = [k for k, v in bundle_items.items() if v]

        bundle = {
            "share_receipt_id": receipt_id,
            "booking_id": str(booking_id),
            "psychologist_id": str(payload.psychologist_id),
            "status": "authorized",
            "version": payload.version,
            "consent_version": payload.consent_version,
            "items": bundle_items,
            "authorized_categories": authorized_categories,
            "created_at": now_utc.isoformat(),
            "expires_at": session.scheduled_end_time.isoformat() if session.scheduled_end_time else None,
        }

        current_soap = dict(session.soap_notes or {})
        current_soap["_clinical_share_bundle"] = bundle
        session.soap_notes = current_soap
        flag_modified(session, "soap_notes")

        await self.db.commit()
        await self.db.refresh(session)
        logger.info(f"📋 [CLINICAL SHARE CREATED] Booking {booking_id} -> Receipt {receipt_id} (Categories: {authorized_categories})")

        return ClinicalShareResponse(
            share_receipt_id=receipt_id,
            booking_id=str(booking_id),
            psychologist_id=str(payload.psychologist_id),
            status="authorized",
            authorized_categories=authorized_categories,
            expires_at=bundle["expires_at"],
            created_at=bundle["created_at"],
        )

    async def revoke_clinical_share(
        self,
        booking_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> RevokeClinicalShareResponse:
        """Revoke patient consent and clinical data sharing for a booking."""
        stmt = select(ConsultationSession).where(ConsultationSession.id == booking_id)
        res = await self.db.execute(stmt)
        session = res.scalar_one_or_none()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi booking konsultasi tidak ditemukan.",
            )

        if session.patient_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak: Hanya pasien pemilik booking yang dapat mencabut persetujuan berbagi.",
            )

        current_soap = dict(session.soap_notes or {})
        bundle = current_soap.get("_clinical_share_bundle")

        if not bundle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Paket berbagi data klinis tidak ditemukan pada sesi ini.",
            )

        now_iso = datetime.now(UTC).isoformat()
        bundle["status"] = "revoked"
        bundle["revoked_at"] = now_iso
        current_soap["_clinical_share_bundle"] = bundle
        session.soap_notes = current_soap
        flag_modified(session, "soap_notes")

        await self.db.commit()
        await self.db.refresh(session)
        logger.info(f"🚫 [CLINICAL SHARE REVOKED] Booking {booking_id}: Receipt {bundle.get('share_receipt_id')}")

        return RevokeClinicalShareResponse(
            share_receipt_id=bundle.get("share_receipt_id", f"rec-{booking_id}"),
            status="revoked",
            revoked_at=now_iso,
            message="Clinical data sharing has been revoked. The psychologist will no longer have access to this payload.",
        )

    async def get_shared_clinical_bundle(
        self,
        session_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> SharedClinicalBundleResponse:
        """Allow authorized psychologist to access consented clinical bundle."""
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

        is_counselor = session.counselor and session.counselor.user_id == user_id
        is_patient = session.patient_id == user_id

        if not (is_counselor or is_patient):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak: Anda bukan psikolog yang ditugaskan untuk sesi ini.",
            )

        bundle = (session.soap_notes or {}).get("_clinical_share_bundle")
        if not bundle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pasien tidak membagikan paket data klinis untuk sesi konsultasi ini.",
            )

        if bundle.get("status") != "authorized":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak: Persetujuan berbagi data klinis telah dicabut oleh pasien.",
            )

        return SharedClinicalBundleResponse(
            share_receipt_id=bundle.get("share_receipt_id", ""),
            booking_id=str(session.id),
            psychologist_id=bundle.get("psychologist_id", str(session.counselor_id)),
            status=bundle.get("status", "authorized"),
            authorized_categories=bundle.get("authorized_categories", []),
            items=bundle.get("items", {}),
            created_at=bundle.get("created_at", ""),
        )

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

    async def create_clinical_share(
        self,
        booking_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: ClinicalShareRequest,
    ) -> ClinicalShareResponse:
        """Create consent-based clinical data share bundle tied to a consultation booking."""
        stmt = select(ConsultationSession).where(ConsultationSession.id == booking_id)
        res = await self.db.execute(stmt)
        session = res.scalar_one_or_none()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi booking konsultasi tidak ditemukan.",
            )

        if session.patient_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak: Hanya pasien pemilik booking yang dapat membagikan data klinis.",
            )

        if session.counselor_id != payload.psychologist_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Penerima data klinis tidak cocok dengan psikolog yang ditugaskan.",
            )

        receipt_id = f"rec-{uuid.uuid4()}"
        now_utc = datetime.now(UTC)
        bundle_items = payload.items.model_dump()
        authorized_categories = [k for k, v in bundle_items.items() if v]

        bundle = {
            "share_receipt_id": receipt_id,
            "booking_id": str(booking_id),
            "psychologist_id": str(payload.psychologist_id),
            "status": "authorized",
            "version": payload.version,
            "consent_version": payload.consent_version,
            "items": bundle_items,
            "authorized_categories": authorized_categories,
            "created_at": now_utc.isoformat(),
            "expires_at": session.scheduled_end_time.isoformat() if session.scheduled_end_time else None,
        }

        current_soap = dict(session.soap_notes or {})
        current_soap["_clinical_share_bundle"] = bundle
        session.soap_notes = current_soap
        flag_modified(session, "soap_notes")

        await self.db.commit()
        await self.db.refresh(session)
        logger.info(f"📋 [CLINICAL SHARE CREATED] Booking {booking_id} -> Receipt {receipt_id} (Categories: {authorized_categories})")

        return ClinicalShareResponse(
            share_receipt_id=receipt_id,
            booking_id=str(booking_id),
            psychologist_id=str(payload.psychologist_id),
            status="authorized",
            authorized_categories=authorized_categories,
            expires_at=bundle["expires_at"],
            created_at=bundle["created_at"],
        )

    async def revoke_clinical_share(
        self,
        booking_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> RevokeClinicalShareResponse:
        """Revoke patient consent and clinical data sharing for a booking."""
        stmt = select(ConsultationSession).where(ConsultationSession.id == booking_id)
        res = await self.db.execute(stmt)
        session = res.scalar_one_or_none()

        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Sesi booking konsultasi tidak ditemukan.",
            )

        if session.patient_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak: Hanya pasien pemilik booking yang dapat mencabut persetujuan berbagi.",
            )

        current_soap = dict(session.soap_notes or {})
        bundle = current_soap.get("_clinical_share_bundle")

        if not bundle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Paket berbagi data klinis tidak ditemukan pada sesi ini.",
            )

        now_iso = datetime.now(UTC).isoformat()
        bundle["status"] = "revoked"
        bundle["revoked_at"] = now_iso
        current_soap["_clinical_share_bundle"] = bundle
        session.soap_notes = current_soap
        flag_modified(session, "soap_notes")

        await self.db.commit()
        await self.db.refresh(session)
        logger.info(f"🚫 [CLINICAL SHARE REVOKED] Booking {booking_id}: Receipt {bundle.get('share_receipt_id')}")

        return RevokeClinicalShareResponse(
            share_receipt_id=bundle.get("share_receipt_id", f"rec-{booking_id}"),
            status="revoked",
            revoked_at=now_iso,
            message="Clinical data sharing has been revoked. The psychologist will no longer have access to this payload.",
        )

    async def get_shared_clinical_bundle(
        self,
        session_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> SharedClinicalBundleResponse:
        """Allow authorized psychologist to access consented clinical bundle."""
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

        is_counselor = session.counselor and session.counselor.user_id == user_id
        is_patient = session.patient_id == user_id

        if not (is_counselor or is_patient):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak: Anda bukan psikolog yang ditugaskan untuk sesi ini.",
            )

        bundle = (session.soap_notes or {}).get("_clinical_share_bundle")
        if not bundle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pasien tidak membagikan paket data klinis untuk sesi konsultasi ini.",
            )

        if bundle.get("status") != "authorized":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Akses ditolak: Persetujuan berbagi data klinis telah dicabut oleh pasien.",
            )

        return SharedClinicalBundleResponse(
            share_receipt_id=bundle.get("share_receipt_id", ""),
            booking_id=str(session.id),
            psychologist_id=bundle.get("psychologist_id", str(session.counselor_id)),
            status=bundle.get("status", "authorized"),
            authorized_categories=bundle.get("authorized_categories", []),
            items=bundle.get("items", {}),
            created_at=bundle.get("created_at", ""),
        )
