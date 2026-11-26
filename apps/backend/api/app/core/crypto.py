import base64
import hashlib
import hmac
import os

from shared.config import settings

_TOKEN_PREFIX = "v1:"
_NONCE_SIZE = 16
_TAG_SIZE = 32


class BankEncryptionError(RuntimeError):
    """Raised when bank account encryption/decryption fails or key is unconfigured."""


def _resolve_master_key(raw_key: str | None = None) -> bytes:
    """Resolve and validate the 32-byte master key from settings or explicit override."""
    candidate = (raw_key if raw_key is not None else settings.BANK_ACCOUNT_ENCRYPTION_KEY).strip()
    if not candidate:
        raise BankEncryptionError("BANK_ACCOUNT_ENCRYPTION_KEY belum dikonfigurasi.")
    if len(candidate) < 16:
        raise BankEncryptionError("BANK_ACCOUNT_ENCRYPTION_KEY terlalu pendek (minimal 16 karakter).")
    return hashlib.sha256(candidate.encode("utf-8")).digest()


def _derive_subkeys(master_key: bytes) -> tuple[bytes, bytes]:
    """Derive independent encryption and MAC subkeys via HMAC-SHA256 domain separation."""
    enc_key = hmac.new(master_key, b"eva-bank-enc-v1", hashlib.sha256).digest()
    mac_key = hmac.new(master_key, b"eva-bank-mac-v1", hashlib.sha256).digest()
    return enc_key, mac_key


def _keystream(enc_key: bytes, nonce: bytes, length: int) -> bytes:
    """Generate deterministic SHA-256 counter-mode keystream for a given key and nonce."""
    chunks: list[bytes] = []
    generated = 0
    counter = 0
    while generated < length:
        block = hashlib.sha256(enc_key + nonce + counter.to_bytes(4, "big")).digest()
        chunks.append(block)
        generated += len(block)
        counter += 1
    return b"".join(chunks)[:length]


def mask_account_number(account_number: str) -> str:
    """Return masked bank account number (e.g. '****3333') without exposing full digits."""
    cleaned = "".join(ch for ch in str(account_number).strip() if not ch.isspace())
    if len(cleaned) <= 4:
        return "****"
    return f"****{cleaned[-4:]}"


def is_encryption_configured(raw_key: str | None = None) -> bool:
    """Return True when a valid non-empty encryption key is available."""
    try:
        _resolve_master_key(raw_key)
        return True
    except BankEncryptionError:
        return False


def encrypt_bank_account(plaintext: str, key: str | None = None) -> str:
    """Encrypt bank account number with authenticated Encrypt-then-MAC (v1 CTR+HMAC-SHA256)."""
    normalized = str(plaintext).strip()
    if not normalized:
        raise BankEncryptionError("Nomor rekening tidak boleh kosong.")
    master_key = _resolve_master_key(key)
    enc_key, mac_key = _derive_subkeys(master_key)
    nonce = os.urandom(_NONCE_SIZE)
    raw_bytes = normalized.encode("utf-8")
    stream = _keystream(enc_key, nonce, len(raw_bytes))
    ciphertext = bytes(a ^ b for a, b in zip(raw_bytes, stream, strict=True))
    tag = hmac.new(mac_key, b"v1|" + nonce + ciphertext, hashlib.sha256).digest()
    token = base64.urlsafe_b64encode(nonce + ciphertext + tag).decode("ascii")
    return f"{_TOKEN_PREFIX}{token}"


def decrypt_bank_account(token: str, key: str | None = None) -> str:
    """Verify HMAC tag in constant time and decrypt v1 encrypted bank account number."""
    if not token or not token.startswith(_TOKEN_PREFIX):
        raise BankEncryptionError("Format token rekening terenkripsi tidak valid.")
    master_key = _resolve_master_key(key)
    enc_key, mac_key = _derive_subkeys(master_key)
    try:
        payload = base64.urlsafe_b64decode(token[len(_TOKEN_PREFIX) :].encode("ascii"))
    except Exception as exc:
        raise BankEncryptionError("Payload rekening terenkripsi korup.") from exc

    if len(payload) < _NONCE_SIZE + _TAG_SIZE + 1:
        raise BankEncryptionError("Panjang payload rekening terenkripsi tidak valid.")

    nonce = payload[:_NONCE_SIZE]
    tag = payload[-_TAG_SIZE:]
    ciphertext = payload[_NONCE_SIZE:-_TAG_SIZE]
    expected_tag = hmac.new(mac_key, b"v1|" + nonce + ciphertext, hashlib.sha256).digest()
    if not hmac.compare_digest(tag, expected_tag):
        raise BankEncryptionError("Autentikasi dekripsi rekening bank gagal.")

    stream = _keystream(enc_key, nonce, len(ciphertext))
    raw_bytes = bytes(a ^ b for a, b in zip(ciphertext, stream, strict=True))
    try:
        return raw_bytes.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise BankEncryptionError("Hasil dekripsi rekening tidak valid.") from exc
