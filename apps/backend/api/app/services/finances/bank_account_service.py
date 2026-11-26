from datetime import UTC, datetime, timedelta
import re
import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.crypto import (
    BankEncryptionError,
    encrypt_bank_account,
    is_encryption_configured,
    mask_account_number,
)
from app.core.payment_errors import raise_contract_error
from app.core.security import verify_password
from app.models.counselor import PsychologistProfile
from app.models.enums import (
    BankNameMatchStatus,
    BankValidationStatus,
    BankVerificationStatus,
)
from app.models.payment import BankAccountValidation, CounselorBankAccount
from app.models.user import User
from app.schemas.finances import (
    BankAccountResponse,
    BankValidationResponse,
    CurrentBankAccountResponse,
    SaveBankAccountRequest,
    SupportedBankListResponse,
    SupportedBankResponse,
    ValidateBankAccountRequest,
)
from app.services.payout import BasePayoutGatewayPort, PayoutGatewayError

_TITLE_STOPWORDS: frozenset[str] = frozenset(
    {
        "dr",
        "drg",
        "prof",
        "ir",
        "hj",
        "h",
        "m",
        "s",
        "psi",
        "mpsi",
        "spsi",
        "psikolog",
        "sked",
        "mkes",
        "spkj",
        "msc",
        "mph",
        "phd",
        "se",
        "sh",
        "mh",
        "ssos",
        "apt",
        "spd",
        "mpd",
    }
)

_REAUTH_MAX_TOKEN_AGE_SECONDS = 15 * 60
_VALIDATION_RATE_LIMIT_MAX = 5
_VALIDATION_RATE_LIMIT_WINDOW_MINUTES = 5


def normalize_person_name_tokens(raw_name: str) -> list[str]:
    """Normalize academic/clinical titles and punctuation into lowercase name tokens."""
    cleaned = re.sub(r"[^a-zA-Z\s]", " ", (raw_name or "").lower())
    tokens = [tok for tok in cleaned.split() if tok and tok not in _TITLE_STOPWORDS]
    return tokens


def evaluate_bank_name_match(holder_name: str, counselor_name: str) -> str:
    """Compare bank account holder name against registered counselor identity."""
    holder_tokens = normalize_person_name_tokens(holder_name)
    counselor_tokens = normalize_person_name_tokens(counselor_name)
    if not holder_tokens or not counselor_tokens:
        return BankNameMatchStatus.UNKNOWN.value

    if holder_tokens == counselor_tokens:
        return BankNameMatchStatus.MATCHED.value

    holder_set = set(holder_tokens)
    counselor_set = set(counselor_tokens)
    overlap = holder_set & counselor_set
    min_len = min(len(holder_set), len(counselor_set))

    if len(overlap) == min_len and min_len >= 2:
        return BankNameMatchStatus.MATCHED.value
    if len(overlap) == 1 and len(holder_set) == 1 and len(counselor_set) == 1:
        return BankNameMatchStatus.MATCHED.value
    if overlap:
        return BankNameMatchStatus.REVIEW_REQUIRED.value
    return BankNameMatchStatus.MISMATCH.value


def serialize_bank_account(account: CounselorBankAccount) -> BankAccountResponse:
    """Serialize CounselorBankAccount without ever exposing plaintext account digits."""
    return BankAccountResponse(
        id=str(account.id),
        bank_code=account.bank_code,
        bank_name=account.bank_name,
        account_number_masked=account.account_number_masked,
        account_holder_name=account.account_holder_name,
        verification_status=account.verification_status,
        verified_at=account.verified_at,
        account_revision=account.account_revision,
        is_active=account.is_active,
    )


class BankAccountService:
    """Handles supported banks, provider account validation, encryption, and activation."""

    def __init__(
        self,
        db: AsyncSession,
        gateway: BasePayoutGatewayPort,
        *,
        max_validations_per_window: int = _VALIDATION_RATE_LIMIT_MAX,
        validation_window_minutes: int = _VALIDATION_RATE_LIMIT_WINDOW_MINUTES,
    ) -> None:
        self.db = db
        self.gateway = gateway
        self._max_validations = max_validations_per_window
        self._validation_window_minutes = validation_window_minutes

    async def list_supported_banks(self) -> SupportedBankListResponse:
        """Return list of supported disbursement beneficiary banks."""
        banks = await self.gateway.list_beneficiary_banks()
        return SupportedBankListResponse(
            items=[SupportedBankResponse(code=b.code, name=b.name) for b in banks]
        )

    async def validate_bank_account(
        self,
        user_id: uuid.UUID,
        payload: ValidateBankAccountRequest,
    ) -> BankValidationResponse:
        """Validate beneficiary bank account with provider and issue a single-use token."""
        profile, user = await self._load_counselor_and_user(user_id)
        window_start = datetime.now(UTC) - timedelta(minutes=self._validation_window_minutes)
        recent_count = int(
            (
                await self.db.execute(
                    select(func.count(BankAccountValidation.id)).where(
                        BankAccountValidation.counselor_id == profile.id,
                        BankAccountValidation.created_at >= window_start,
                    )
                )
            ).scalar()
            or 0
        )
        if recent_count >= self._max_validations:
            raise_contract_error(
                429,
                "RATE_LIMITED",
                "Terlalu banyak percobaan validasi rekening. Silakan tunggu beberapa menit sebelum mencoba lagi.",
            )

        cleaned_number = re.sub(r"\s+", "", payload.account_number.strip())
        if not cleaned_number.isdigit() or len(cleaned_number) < 6:
            raise_contract_error(
                400,
                "ACCOUNT_NOT_FOUND",
                "Nomor rekening harus berupa minimal 6 digit angka.",
            )

        if not is_encryption_configured():
            raise_contract_error(
                503,
                "PROVIDER_UNAVAILABLE",
                "Kunci enkripsi rekening bank belum dikonfigurasi pada server.",
            )

        try:
            encrypted_number = encrypt_bank_account(cleaned_number)
        except BankEncryptionError as exc:
            raise_contract_error(503, "PROVIDER_UNAVAILABLE", str(exc))

        try:
            inquiry = await self.gateway.validate_bank_account(
                bank_code=payload.bank_code.strip().lower(),
                account_number=cleaned_number,
            )
        except PayoutGatewayError as exc:
            status_code = 400 if exc.code == "BANK_NOT_SUPPORTED" else 503
            raise_contract_error(status_code, exc.code, exc.message)

        masked_number = mask_account_number(cleaned_number)
        now = datetime.now(UTC)
        expires_at = now + timedelta(minutes=15)

        if inquiry.status == "not_found":
            val_status = BankValidationStatus.NOT_FOUND.value
            name_match = BankNameMatchStatus.UNKNOWN.value
            holder_name = ""
        elif inquiry.status == "valid":
            holder_name = inquiry.account_holder_name.strip()
            counselor_identity = profile.full_name or user.display_name or ""
            name_match = evaluate_bank_name_match(holder_name, counselor_identity)
            if name_match == BankNameMatchStatus.MATCHED.value:
                val_status = BankValidationStatus.VERIFIED.value
            else:
                val_status = BankValidationStatus.REVIEW_REQUIRED.value
        else:
            val_status = BankValidationStatus.UNAVAILABLE.value
            name_match = BankNameMatchStatus.UNKNOWN.value
            holder_name = ""

        validation = BankAccountValidation(
            counselor_id=profile.id,
            bank_code=inquiry.bank_code,
            bank_name=inquiry.bank_name,
            account_number_encrypted=encrypted_number,
            account_number_masked=masked_number,
            account_holder_name=holder_name,
            status=val_status,
            name_match=name_match,
            provider_payload_redacted={"status": inquiry.status, "bank_code": inquiry.bank_code},
            expires_at=expires_at,
        )
        self.db.add(validation)
        await self.db.commit()
        await self.db.refresh(validation)

        return BankValidationResponse(
            validation_id=str(validation.id),
            bank_code=validation.bank_code,
            bank_name=validation.bank_name,
            account_number_masked=validation.account_number_masked,
            account_holder_name=validation.account_holder_name,
            status=validation.status,
            name_match=validation.name_match,
            expires_at=validation.expires_at,
        )

    async def get_current_bank_account(self, user_id: uuid.UUID) -> CurrentBankAccountResponse:
        """Return currently active counselor bank account or null."""
        profile = await self._load_counselor_profile(user_id)
        stmt = (
            select(CounselorBankAccount)
            .where(
                CounselorBankAccount.counselor_id == profile.id,
                CounselorBankAccount.is_active.is_(True),
            )
            .order_by(CounselorBankAccount.account_revision.desc())
        )
        result = await self.db.execute(stmt)
        account = result.scalars().first()
        return CurrentBankAccountResponse(
            bank_account=serialize_bank_account(account) if account else None
        )

    async def save_current_bank_account(
        self,
        user_id: uuid.UUID,
        payload: SaveBankAccountRequest,
        *,
        token_claims: dict | None = None,
    ) -> CurrentBankAccountResponse:
        """Consume a valid verification token, enforce reauth on changes, and set active account."""
        profile, user = await self._load_counselor_and_user(user_id)
        try:
            validation_uuid = uuid.UUID(payload.validation_id.strip())
        except ValueError:
            raise_contract_error(400, "BANK_UNVERIFIED", "ID validasi rekening tidak valid.")

        val_stmt = (
            select(BankAccountValidation)
            .where(
                BankAccountValidation.id == validation_uuid,
                BankAccountValidation.counselor_id == profile.id,
            )
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        val_result = await self.db.execute(val_stmt)
        validation = val_result.scalars().first()
        if not validation:
            raise_contract_error(404, "BANK_UNVERIFIED", "Token validasi rekening tidak ditemukan.")

        now = datetime.now(UTC)
        if validation.used_at is not None:
            raise_contract_error(409, "BANK_UNVERIFIED", "Token validasi rekening sudah digunakan.")
        if validation.expires_at <= now:
            raise_contract_error(
                410,
                "VALIDATION_EXPIRED",
                "Token validasi rekening telah kedaluwarsa. Silakan validasi ulang.",
            )
        if validation.status == BankValidationStatus.NOT_FOUND.value:
            raise_contract_error(404, "ACCOUNT_NOT_FOUND", "Nomor rekening tidak ditemukan pada bank tujuan.")
        if validation.name_match == BankNameMatchStatus.MISMATCH.value:
            raise_contract_error(
                422,
                "BANK_NAME_MISMATCH",
                "Nama pemilik rekening tidak cocok dengan identitas psikolog terdaftar.",
            )
        if (
            validation.status != BankValidationStatus.VERIFIED.value
            or validation.name_match != BankNameMatchStatus.MATCHED.value
        ):
            raise_contract_error(
                400,
                "BANK_UNVERIFIED",
                "Rekening belum lolos verifikasi otomatis dan memerlukan peninjauan.",
            )

        active_stmt = (
            select(CounselorBankAccount)
            .where(
                CounselorBankAccount.counselor_id == profile.id,
                CounselorBankAccount.is_active.is_(True),
            )
            .with_for_update()
        )
        active_result = await self.db.execute(active_stmt)
        active_accounts = list(active_result.scalars().all())

        has_verified_active = any(
            acc.verification_status == BankVerificationStatus.VERIFIED.value for acc in active_accounts
        )
        if payload.current_password is not None:
            if not user.password_hash or not verify_password(payload.current_password, user.password_hash):
                raise_contract_error(
                    403,
                    "REAUTH_REQUIRED",
                    "Konfirmasi kata sandi tidak sesuai. Silakan autentikasi ulang.",
                )
        elif has_verified_active:
            iat = (token_claims or {}).get("iat")
            if not isinstance(iat, (int, float)) or (now.timestamp() - float(iat)) > _REAUTH_MAX_TOKEN_AGE_SECONDS:
                raise_contract_error(
                    403,
                    "REAUTH_REQUIRED",
                    "Mengganti rekening bank terverifikasi memerlukan login ulang atau konfirmasi kata sandi.",
                )

        max_rev_stmt = select(func.coalesce(func.max(CounselorBankAccount.account_revision), 0)).where(
            CounselorBankAccount.counselor_id == profile.id
        )
        max_rev = (await self.db.execute(max_rev_stmt)).scalar() or 0
        next_revision = int(max_rev) + 1

        for existing in active_accounts:
            existing.is_active = False

        validation.used_at = now
        new_account = CounselorBankAccount(
            counselor_id=profile.id,
            validation_id=validation.id,
            bank_code=validation.bank_code,
            bank_name=validation.bank_name,
            account_number_encrypted=validation.account_number_encrypted,
            account_number_masked=validation.account_number_masked,
            account_holder_name=validation.account_holder_name,
            verification_status=BankVerificationStatus.VERIFIED.value,
            verified_at=now,
            account_revision=next_revision,
            is_active=True,
        )
        self.db.add(new_account)

        # Keep masked display fields in sync on legacy profile without storing plaintext digits
        profile.bank_name = validation.bank_name
        profile.bank_account_number = validation.account_number_masked
        profile.bank_account_holder = validation.account_holder_name

        await self.db.commit()
        await self.db.refresh(new_account)

        return CurrentBankAccountResponse(bank_account=serialize_bank_account(new_account))

    async def _load_counselor_profile(self, user_id: uuid.UUID) -> PsychologistProfile:
        stmt = select(PsychologistProfile).where(PsychologistProfile.user_id == user_id)
        profile = (await self.db.execute(stmt)).scalars().first()
        if not profile:
            raise_contract_error(404, "COUNSELOR_NOT_FOUND", "Profil konselor tidak ditemukan.")
        return profile

    async def _load_counselor_and_user(self, user_id: uuid.UUID) -> tuple[PsychologistProfile, User]:
        profile = await self._load_counselor_profile(user_id)
        user_stmt = select(User).where(User.id == user_id)
        user = (await self.db.execute(user_stmt)).scalars().first()
        if not user:
            raise_contract_error(404, "USER_NOT_FOUND", "Akun pengguna tidak ditemukan.")
        return profile, user
