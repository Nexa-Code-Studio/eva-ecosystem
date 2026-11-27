from collections.abc import AsyncIterator
from pathlib import Path
import uuid

from fastapi import HTTPException, UploadFile, status
from shared.config import settings
from sqlalchemy import case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.booth_feedback import BoothFeedback, BoothFeedbackPhoto
from app.schemas.booth_feedback import (
    AdminBoothFeedbackListResponse,
    BoothFeedbackDeleteResponse,
    BoothFeedbackItemResponse,
    BoothFeedbackPhotoResponse,
    BoothFeedbackSummaryResponse,
    PublicBoothFeedbackCreateResponse,
)


VALID_VISITOR_ROLES = {"user", "counselor"}


def _detect_image_format(data: bytes) -> tuple[str, str]:
    """Validate uploaded image magic bytes and return normalized (mime_type, extension)."""
    if data.startswith(b"\xff\xd8\xff"):
        return ("image/jpeg", ".jpg")
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return ("image/png", ".png")
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ("image/webp", ".webp")
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail="Format foto harus JPEG, PNG, atau WebP yang valid.",
    )


def _sanitize_original_filename(filename: str | None, fallback_ext: str) -> str:
    base = Path(filename or f"booth-selfie{fallback_ext}").name.strip()
    return (base or f"booth-selfie{fallback_ext}")[:180]


async def _iter_file_chunks(path: Path, chunk_size: int = 65536) -> AsyncIterator[bytes]:
    with path.open("rb") as fh:
        while chunk := fh.read(chunk_size):
            yield chunk


class BoothFeedbackService:
    """Domain service for Mobile-First event booth feedback submissions and admin moderation."""

    def __init__(self, db: AsyncSession, upload_root: Path | None = None):
        self.db = db
        self.upload_dir = (upload_root or (Path(settings.UPLOAD_DIR) / "booth-feedbacks")).resolve()

    @staticmethod
    def _validate_scale_score(value: int, field_label: str) -> None:
        if value < 1 or value > 5:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"{field_label} wajib dipilih antara 1 sampai 5.",
            )

    @staticmethod
    def _validate_visitor_role(visitor_role: str | None) -> str:
        normalized = (visitor_role or "user").strip().lower()
        if normalized not in VALID_VISITOR_ROLES:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Peran responden wajib dipilih antara 'user' atau 'counselor'.",
            )
        return normalized

    async def submit_feedback(
        self,
        *,
        rating: int,
        usage_likelihood: int,
        recommendation_score: int,
        visitor_role: str = "user",
        message: str,
        visitor_name: str | None,
        visitor_contact: str | None,
        event_label: str | None,
        photos: list[UploadFile],
    ) -> PublicBoothFeedbackCreateResponse:
        """Validate visitor feedback role, scores (1-5), and 1..5 uploaded booth photos."""
        normalized_role = self._validate_visitor_role(visitor_role)
        self._validate_scale_score(rating, "Rating pengalaman")
        self._validate_scale_score(usage_likelihood, "Skala minat menggunakan aplikasi")
        self._validate_scale_score(recommendation_score, "Skala rekomendasi ke teman")

        clean_message = message.strip()
        if len(clean_message) < 5 or len(clean_message) > 2000:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Pesan feedback wajib diisi antara 5 hingga 2000 karakter.",
            )

        if not photos or len(photos) > settings.BOOTH_FEEDBACK_MAX_PHOTOS:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Lampirkan antara 1 hingga {settings.BOOTH_FEEDBACK_MAX_PHOTOS} foto selfie booth.",
            )

        prepared_photos: list[tuple[str, str, str, bytes]] = []
        for upload in photos:
            raw = await upload.read()
            if not raw:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="File foto tidak boleh kosong.",
                )
            if len(raw) > settings.BOOTH_FEEDBACK_MAX_PHOTO_BYTES:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Ukuran setiap foto maksimal 5 MB.",
                )
            mime_type, ext = _detect_image_format(raw)
            safe_name = _sanitize_original_filename(upload.filename, ext)
            rel_path = f"{uuid.uuid4().hex}{ext}"
            prepared_photos.append((rel_path, safe_name, mime_type, raw))

        self.upload_dir.mkdir(parents=True, exist_ok=True)
        written_files: list[Path] = []
        try:
            for rel_path, _, _, raw in prepared_photos:
                dest = (self.upload_dir / rel_path).resolve()
                if not dest.is_relative_to(self.upload_dir):
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Path file tidak valid.")
                dest.write_bytes(raw)
                written_files.append(dest)

            entry = BoothFeedback(
                rating=rating,
                usage_likelihood=usage_likelihood,
                recommendation_score=recommendation_score,
                visitor_role=normalized_role,
                message=clean_message,
                visitor_name=visitor_name.strip()[:120] if visitor_name and visitor_name.strip() else None,
                visitor_contact=visitor_contact.strip()[:150] if visitor_contact and visitor_contact.strip() else None,
                event_label=(event_label or "Event Booth EVA").strip()[:120] or "Event Booth EVA",
            )
            for idx, (rel_path, safe_name, mime_type, raw) in enumerate(prepared_photos):
                entry.photos.append(
                    BoothFeedbackPhoto(
                        storage_rel_path=rel_path,
                        original_filename=safe_name,
                        mime_type=mime_type,
                        file_size_bytes=len(raw),
                        sort_order=idx,
                    )
                )

            self.db.add(entry)
            await self.db.commit()
            await self.db.refresh(entry)
        except Exception:
            await self.db.rollback()
            for file_path in written_files:
                file_path.unlink(missing_ok=True)
            raise

        return PublicBoothFeedbackCreateResponse(
            id=str(entry.id),
            rating=entry.rating,
            usage_likelihood=entry.usage_likelihood,
            recommendation_score=entry.recommendation_score,
            visitor_role=entry.visitor_role,
            photo_count=len(prepared_photos),
            created_at=entry.created_at,
            message="Terima kasih! Feedback dan foto booth Anda telah tersimpan.",
        )

    async def list_admin_feedbacks(
        self,
        *,
        rating: int | None = None,
        visitor_role: str | None = None,
        search: str | None = None,
        page: int = 1,
        page_size: int = 10,
    ) -> AdminBoothFeedbackListResponse:
        """Return aggregated booth stats (filtered by role if given) and paginated entries."""
        active_role: str | None = None
        if visitor_role is not None and visitor_role.strip():
            active_role = self._validate_visitor_role(visitor_role)

        summary = await self._compute_summary(visitor_role=active_role)

        filters = []
        if active_role is not None:
            filters.append(BoothFeedback.visitor_role == active_role)
        if rating is not None and 1 <= rating <= 5:
            filters.append(BoothFeedback.rating == rating)
        if search and search.strip():
            term = f"%{search.strip()}%"
            filters.append(
                or_(
                    BoothFeedback.message.ilike(term),
                    BoothFeedback.visitor_name.ilike(term),
                    BoothFeedback.visitor_contact.ilike(term),
                )
            )

        count_stmt = select(func.count(BoothFeedback.id))
        items_stmt = (
            select(BoothFeedback)
            .options(selectinload(BoothFeedback.photos))
            .order_by(BoothFeedback.created_at.desc())
        )
        if filters:
            count_stmt = count_stmt.where(*filters)
            items_stmt = items_stmt.where(*filters)

        total_res = await self.db.execute(count_stmt)
        total = int(total_res.scalar_one() or 0)

        safe_page = max(1, page)
        safe_size = min(50, max(1, page_size))
        offset = (safe_page - 1) * safe_size

        rows_res = await self.db.execute(items_stmt.offset(offset).limit(safe_size))
        entries = list(rows_res.scalars().all())

        return AdminBoothFeedbackListResponse(
            summary=summary,
            items=[self._to_item_response(e) for e in entries],
            total=total,
            page=safe_page,
            page_size=safe_size,
        )

    async def open_photo_stream(
        self,
        feedback_id: uuid.UUID,
        photo_id: uuid.UUID,
    ) -> tuple[AsyncIterator[bytes], str, str]:
        """Resolve and stream an uploaded booth photo after verifying admin authorization."""
        res = await self.db.execute(
            select(BoothFeedbackPhoto).where(
                BoothFeedbackPhoto.id == photo_id,
                BoothFeedbackPhoto.feedback_id == feedback_id,
            )
        )
        photo = res.scalar_one_or_none()
        if not photo:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Foto feedback tidak ditemukan.",
            )

        target = (self.upload_dir / photo.storage_rel_path).resolve()
        if not target.is_relative_to(self.upload_dir) or not target.is_file():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Berkas foto tidak tersedia di penyimpanan.",
            )

        return _iter_file_chunks(target), photo.mime_type, photo.original_filename

    async def delete_feedback(self, feedback_id: uuid.UUID) -> BoothFeedbackDeleteResponse:
        """Delete a booth feedback record along with all stored photo files on disk."""
        res = await self.db.execute(
            select(BoothFeedback)
            .options(selectinload(BoothFeedback.photos))
            .where(BoothFeedback.id == feedback_id)
        )
        entry = res.scalar_one_or_none()
        if not entry:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Feedback booth tidak ditemukan.",
            )

        paths_to_remove = [
            (self.upload_dir / photo.storage_rel_path).resolve()
            for photo in entry.photos
        ]
        await self.db.delete(entry)
        await self.db.commit()

        for file_path in paths_to_remove:
            if file_path.is_relative_to(self.upload_dir):
                file_path.unlink(missing_ok=True)

        return BoothFeedbackDeleteResponse(deleted_id=str(feedback_id))

    async def _compute_summary(
        self,
        *,
        visitor_role: str | None = None,
    ) -> BoothFeedbackSummaryResponse:
        summary_stmt = select(
            func.count(BoothFeedback.id),
            func.coalesce(func.sum(BoothFeedback.rating), 0),
            func.coalesce(func.sum(case((BoothFeedback.rating == 1, 1), else_=0)), 0),
            func.coalesce(func.sum(case((BoothFeedback.rating == 2, 1), else_=0)), 0),
            func.coalesce(func.sum(case((BoothFeedback.rating == 3, 1), else_=0)), 0),
            func.coalesce(func.sum(case((BoothFeedback.rating == 4, 1), else_=0)), 0),
            func.coalesce(func.sum(case((BoothFeedback.rating == 5, 1), else_=0)), 0),
            func.coalesce(func.sum(BoothFeedback.usage_likelihood), 0),
            func.coalesce(
                func.sum(case((BoothFeedback.usage_likelihood >= 4, 1), else_=0)),
                0,
            ),
            func.coalesce(func.sum(BoothFeedback.recommendation_score), 0),
            func.coalesce(
                func.sum(case((BoothFeedback.recommendation_score >= 4, 1), else_=0)),
                0,
            ),
        )
        if visitor_role is not None:
            summary_stmt = summary_stmt.where(BoothFeedback.visitor_role == visitor_role)

        res = await self.db.execute(summary_stmt)
        row = res.one()

        role_res = await self.db.execute(
            select(
                func.coalesce(func.sum(case((BoothFeedback.visitor_role == "user", 1), else_=0)), 0),
                func.coalesce(
                    func.sum(case((BoothFeedback.visitor_role == "counselor", 1), else_=0)),
                    0,
                ),
            )
        )
        role_row = role_res.one()

        total = int(row[0] or 0)
        rating_sum = int(row[1] or 0)
        counts = {score: int(row[1 + score] or 0) for score in range(1, 6)}
        usage_sum = int(row[7] or 0)
        high_usage_count = int(row[8] or 0)
        rec_sum = int(row[9] or 0)
        promoter_count = int(row[10] or 0)

        return BoothFeedbackSummaryResponse(
            total_count=total,
            average_rating=round(rating_sum / total, 2) if total > 0 else 0.0,
            rating_counts=counts,
            role_counts={
                "user": int(role_row[0] or 0),
                "counselor": int(role_row[1] or 0),
            },
            average_usage_likelihood=round(usage_sum / total, 2) if total > 0 else 0.0,
            high_usage_intent_count=high_usage_count,
            high_usage_intent_percentage=(
                round((high_usage_count / total) * 100, 1) if total > 0 else 0.0
            ),
            average_recommendation_score=round(rec_sum / total, 2) if total > 0 else 0.0,
            promoter_count=promoter_count,
            promoter_percentage=(
                round((promoter_count / total) * 100, 1) if total > 0 else 0.0
            ),
        )

    @staticmethod
    def _to_item_response(entry: BoothFeedback) -> BoothFeedbackItemResponse:
        return BoothFeedbackItemResponse(
            id=str(entry.id),
            rating=entry.rating,
            usage_likelihood=entry.usage_likelihood,
            recommendation_score=entry.recommendation_score,
            visitor_role=entry.visitor_role,
            message=entry.message,
            visitor_name=entry.visitor_name,
            visitor_contact=entry.visitor_contact,
            event_label=entry.event_label,
            photos=[
                BoothFeedbackPhotoResponse(
                    id=str(p.id),
                    mime_type=p.mime_type,
                    file_size_bytes=p.file_size_bytes,
                    sort_order=p.sort_order,
                    created_at=p.created_at,
                )
                for p in sorted(entry.photos, key=lambda item: item.sort_order)
            ],
            created_at=entry.created_at,
        )
