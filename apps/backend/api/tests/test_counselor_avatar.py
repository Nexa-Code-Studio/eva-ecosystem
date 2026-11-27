from io import BytesIO
from pathlib import Path
import uuid

from fastapi import HTTPException, UploadFile
import pytest

from app.services.counselor.counselor_service import CounselorService


def _fake_upload(data: bytes, filename: str = "avatar.png") -> UploadFile:
    return UploadFile(filename=filename, file=BytesIO(data))


@pytest.mark.asyncio
async def test_detect_avatar_format_and_path_traversal(tmp_path: Path):
    # Magic bytes validation
    assert CounselorService._detect_avatar_format(b"\xff\xd8\xff\xe0test") == ("image/jpeg", ".jpg")
    assert CounselorService._detect_avatar_format(b"\x89PNG\r\n\x1a\nrest") == ("image/png", ".png")
    assert CounselorService._detect_avatar_format(b"RIFF\x00\x00\x00\x00WEBPdata") == ("image/webp", ".webp")

    with pytest.raises(HTTPException) as exc:
        CounselorService._detect_avatar_format(b"not-an-image")
    assert exc.value.status_code == 422

    # Path traversal guard
    with pytest.raises(HTTPException) as exc_trav:
        CounselorService.resolve_avatar_file("../secret.png", upload_root=tmp_path)
    assert exc_trav.value.status_code == 404

    # Valid filename resolution
    valid_name = f"{uuid.uuid4()}-abcd1234.png"
    target = tmp_path / valid_name
    target.write_bytes(b"\x89PNG\r\n\x1a\npayload")
    resolved, media_type = CounselorService.resolve_avatar_file(valid_name, upload_root=tmp_path)
    assert resolved == target.resolve()
    assert media_type == "image/png"
