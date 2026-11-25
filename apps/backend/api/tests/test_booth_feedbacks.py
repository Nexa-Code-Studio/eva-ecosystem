from datetime import UTC, datetime
from io import BytesIO
from pathlib import Path
import tempfile
import unittest
from unittest.mock import AsyncMock, MagicMock
import uuid

from fastapi import HTTPException, UploadFile

from app.models.booth_feedback import BoothFeedback, BoothFeedbackPhoto
from app.services.booth_feedback import BoothFeedbackService

PNG_BYTES = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde"
JPEG_BYTES = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xd9"


def _make_upload(filename: str, payload: bytes) -> UploadFile:
    return UploadFile(filename=filename, file=BytesIO(payload))


class TestBoothFeedbackService(unittest.IsolatedAsyncioTestCase):
    async def test_submit_feedback_with_multiple_photos_succeeds(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = MagicMock()
            db.add = MagicMock()
            db.rollback = AsyncMock()

            async def _commit():
                added = db.add.call_args[0][0]
                added.id = uuid.uuid4()
                added.created_at = datetime.now(UTC)

            db.commit = AsyncMock(side_effect=_commit)
            db.refresh = AsyncMock()

            service = BoothFeedbackService(db, upload_root=Path(tmp))
            res = await service.submit_feedback(
                rating=5,
                message="Booth sangat interaktif dan ramah dicoba langsung.",
                visitor_name="Nadia",
                visitor_contact="@nadia.id",
                event_label="Event Booth EVA",
                photos=[_make_upload("selfie1.png", PNG_BYTES), _make_upload("selfie2.jpg", JPEG_BYTES)],
            )

            self.assertEqual(res.rating, 5)
            self.assertEqual(res.photo_count, 2)
            saved_files = list(Path(tmp).glob("*"))
            self.assertEqual(len(saved_files), 2)

    async def test_submit_feedback_rejects_missing_or_too_many_photos(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = MagicMock()
            service = BoothFeedbackService(db, upload_root=Path(tmp))

            with self.assertRaises(HTTPException) as ctx_empty:
                await service.submit_feedback(
                    rating=4, message="Bagus sekali!", visitor_name=None,
                    visitor_contact=None, event_label=None, photos=[],
                )
            self.assertEqual(ctx_empty.exception.status_code, 422)

            too_many = [_make_upload(f"p{i}.jpg", JPEG_BYTES) for i in range(6)]
            with self.assertRaises(HTTPException) as ctx_many:
                await service.submit_feedback(
                    rating=4, message="Terlalu banyak foto!", visitor_name=None,
                    visitor_contact=None, event_label=None, photos=too_many,
                )
            self.assertEqual(ctx_many.exception.status_code, 422)

    async def test_submit_feedback_rejects_invalid_magic_bytes_and_rating_bounds(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = MagicMock()
            service = BoothFeedbackService(db, upload_root=Path(tmp))

            with self.assertRaises(HTTPException) as ctx_rating:
                await service.submit_feedback(
                    rating=6, message="Rating di luar batas.", visitor_name=None,
                    visitor_contact=None, event_label=None, photos=[_make_upload("a.jpg", JPEG_BYTES)],
                )
            self.assertEqual(ctx_rating.exception.status_code, 422)

            with self.assertRaises(HTTPException) as ctx_mime:
                await service.submit_feedback(
                    rating=3, message="File palsu menyamar jadi jpg.", visitor_name=None,
                    visitor_contact=None, event_label=None, photos=[_make_upload("fake.jpg", b"not-an-image")],
                )
            self.assertEqual(ctx_mime.exception.status_code, 422)
            self.assertEqual(list(Path(tmp).glob("*")), [])

    async def test_admin_summary_open_photo_and_delete_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            feedback_id = uuid.uuid4()
            photo_id = uuid.uuid4()
            photo_file = Path(tmp) / "sample.jpg"
            photo_file.write_bytes(JPEG_BYTES)

            photo = BoothFeedbackPhoto(
                id=photo_id,
                feedback_id=feedback_id,
                storage_rel_path="sample.jpg",
                original_filename="booth.jpg",
                mime_type="image/jpeg",
                file_size_bytes=len(JPEG_BYTES),
                sort_order=0,
                created_at=datetime.now(UTC),
            )
            entry = BoothFeedback(
                id=feedback_id,
                rating=5,
                message="Boothnya seru!",
                visitor_name="Bima",
                visitor_contact=None,
                event_label="Event Booth EVA",
                photos=[photo],
                created_at=datetime.now(UTC),
            )

            agg_res = MagicMock()
            agg_res.all.return_value = [(5, 2), (3, 1)]
            count_res = MagicMock()
            count_res.scalar_one.return_value = 1
            items_res = MagicMock()
            items_res.scalars.return_value.all.return_value = [entry]
            photo_res = MagicMock()
            photo_res.scalar_one_or_none.return_value = photo
            del_res = MagicMock()
            del_res.scalar_one_or_none.return_value = entry

            db = MagicMock()
            db.execute = AsyncMock(side_effect=[agg_res, count_res, items_res, photo_res, del_res])
            db.delete = AsyncMock()
            db.commit = AsyncMock()

            service = BoothFeedbackService(db, upload_root=Path(tmp))
            listing = await service.list_admin_feedbacks()
            self.assertEqual(listing.summary.total_count, 3)
            self.assertEqual(listing.summary.average_rating, 4.33)
            self.assertEqual(listing.summary.rating_counts[5], 2)
            self.assertEqual(len(listing.items[0].photos), 1)

            stream, mime, fname = await service.open_photo_stream(feedback_id, photo_id)
            chunks = [chunk async for chunk in stream]
            self.assertEqual(b"".join(chunks), JPEG_BYTES)
            self.assertEqual(mime, "image/jpeg")
            self.assertEqual(fname, "booth.jpg")

            deleted = await service.delete_feedback(feedback_id)
            self.assertEqual(deleted.deleted_id, str(feedback_id))
            self.assertFalse(photo_file.exists())
