import asyncio
from datetime import UTC, datetime, timedelta
from decimal import Decimal
import hashlib
import json
import uuid

from fastapi import FastAPI
import httpx
import jwt
import pytest
from sqlalchemy import delete, select

from app.api.dependencies import (
    get_bank_account_service,
    get_coin_topup_service,
    get_db_session,
    get_payout_service,
)
from app.api.routes.counselor import router as counselor_router
from app.api.routes.finances import router as finances_router
from app.api.routes.webhooks import router as webhooks_router
from app.core.crypto import (
    BankEncryptionError,
    decrypt_bank_account,
    encrypt_bank_account,
    mask_account_number,
)
from app.core.security import JWT_ALGORITHM, JWT_SECRET_KEY, create_access_token, hash_password
from app.db.session import AsyncSessionLocal, engine
from app.models.counselor import CounselorTransaction, PsychologistProfile
from app.models.enums import (
    BankNameMatchStatus,
    BankValidationStatus,
    BankVerificationStatus,
    PayoutStatus,
    PsychologistVerificationStatus,
    TransactionStatus,
    WebhookProcessStatus,
)
from app.models.payment import (
    BankAccountValidation,
    CounselorBankAccount,
    CounselorWithdrawal,
    PaymentWebhookInbox,
    PayoutQuote,
)
from app.models.user import User
from app.services.finances import BankAccountService, PayoutService
from app.services.payout import IrisPayoutAdapter, MockPayoutGatewayAdapter
from shared.config import settings


@pytest.fixture(autouse=True)
async def dispose_engine():
    await engine.dispose()
    yield
    await engine.dispose()


def _test_app(
    gateway: MockPayoutGatewayAdapter,
    *,
    payout_enabled: bool = True,
    auto_approve: bool = False,
) -> FastAPI:
    app = FastAPI()
    app.include_router(finances_router, prefix="/api/v1")
    app.include_router(counselor_router, prefix="/api/v1")
    app.include_router(webhooks_router, prefix="/api/v1")

    async def override_bank_service():
        async with AsyncSessionLocal() as db:
            yield BankAccountService(db, gateway=gateway)

    async def override_payout_service():
        async with AsyncSessionLocal() as db:
            yield PayoutService(
                db,
                gateway=gateway,
                payout_enabled=payout_enabled,
                auto_approve=auto_approve,
            )

    app.dependency_overrides[get_bank_account_service] = override_bank_service
    app.dependency_overrides[get_payout_service] = override_payout_service
    return app


def _make_stale_token(user_id: uuid.UUID, email: str, name: str, *, minutes_ago: int) -> str:
    now = datetime.now(UTC)
    iat = now - timedelta(minutes=minutes_ago)
    payload = {
        "sub": str(user_id),
        "email": email,
        "name": name,
        "type": "access",
        "iat": int(iat.timestamp()),
        "exp": int((now + timedelta(hours=1)).timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)


def test_crypto_roundtrip_tamper_and_fail_closed():
    key = "unit-test-32-char-encryption-key-2026"
    token = encrypt_bank_account("1234567890123", key=key)
    assert token.startswith("v1:")
    assert decrypt_bank_account(token, key=key) == "1234567890123"
    assert mask_account_number("1234567890123") == "****0123"
    assert mask_account_number("123") == "****"

    tampered = token[:-4] + ("AAAA" if not token.endswith("AAAA") else "BBBB")
    with pytest.raises(BankEncryptionError):
        decrypt_bank_account(tampered, key=key)

    with pytest.raises(BankEncryptionError):
        encrypt_bank_account("1234567890", key="")

    with pytest.raises(BankEncryptionError):
        encrypt_bank_account("1234567890", key="too-short")


@pytest.mark.asyncio
async def test_iris_adapter_creator_approver_separation_and_signature():
    seen_auth: list[tuple[str, str]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen_auth.append((request.url.path, request.headers.get("Authorization", "")))
        if request.url.path.endswith("/account_validation"):
            return httpx.Response(
                200,
                json={"account_name": "BUDI SANTOSO", "bank_name": "Bank Mandiri"},
            )
        if request.url.path.endswith("/payouts/approve"):
            return httpx.Response(200, json={"status": "approved"})
        if request.url.path.endswith("/payouts"):
            return httpx.Response(
                201,
                json={"payouts": [{"reference_no": "iris-ref-1", "status": "queued"}]},
            )
        return httpx.Response(
            200,
            json={"reference_no": "iris-ref-1", "status": "completed", "amount": "95000.00"},
        )

    adapter = IrisPayoutAdapter(
        creator_key="iris-creator-key",
        approver_key="iris-approver-key",
        notification_secret="iris-webhook-secret",
        base_url="https://app.sandbox.midtrans.com/iris/api/v1",
    )

    class _PatchedClient(httpx.AsyncClient):
        def __init__(self, *args, **kwargs):
            kwargs["transport"] = httpx.MockTransport(handler)
            super().__init__(*args, **kwargs)

    orig_client = httpx.AsyncClient
    httpx.AsyncClient = _PatchedClient  # type: ignore[misc]
    try:
        val = await adapter.validate_bank_account(bank_code="mandiri", account_number="1234567890")
        assert val.status == "valid"
        created = await adapter.create_payout(
            reference_id="EVA-PO-1",
            beneficiary_name="BUDI SANTOSO",
            beneficiary_account="1234567890",
            beneficiary_bank="mandiri",
            amount_idr=95000,
            notes="Test",
        )
        assert created.reference_no == "iris-ref-1"
        approved = await adapter.approve_payouts(reference_nos=["iris-ref-1"])
        assert approved[0].status == "approved"
        st = await adapter.get_payout_status("iris-ref-1")
        assert st.status == "completed"
        assert st.amount_idr == 95000
    finally:
        httpx.AsyncClient = orig_client  # type: ignore[misc]

    # Verify creator endpoints did not use approver key and approve endpoint used approver key
    assert seen_auth[0][1] != seen_auth[2][1]
    assert seen_auth[0][1] == seen_auth[1][1]
    assert "/payouts/approve" in seen_auth[2][0]

    raw_body = b'{"reference_no":"iris-ref-1","status":"completed"}'
    good_sig = hashlib.sha512(raw_body + b"iris-webhook-secret").hexdigest()
    assert adapter.verify_webhook_signature(raw_body=raw_body, signature_header=good_sig) is True
    assert adapter.verify_webhook_signature(raw_body=raw_body, signature_header="0" * 128) is False


@pytest.mark.asyncio
async def test_c3_bank_verification_reauth_revision_and_bypass_closed(monkeypatch):
    monkeypatch.setattr(settings, "BANK_ACCOUNT_ENCRYPTION_KEY", "test-bank-encryption-secret-key-2026")
    suffix = uuid.uuid4().hex[:8]
    user_id = uuid.uuid4()
    email = f"counselor-bank-{suffix}@eva.id"
    password = "StrongPassword123!"

    async with AsyncSessionLocal() as db:
        user = User(
            id=user_id,
            email=email,
            password_hash=hash_password(password),
            display_name="Dr. Budi Santoso, M.Psi., Psikolog",
            is_active=True,
        )
        profile = PsychologistProfile(
            id=uuid.uuid4(),
            user_id=user_id,
            full_name="Dr. Budi Santoso, M.Psi., Psikolog",
            str_number=f"STR-B-{suffix}",
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            wallet_balance=Decimal("500000"),
        )
        db.add_all([user, profile])
        await db.commit()

    gateway = MockPayoutGatewayAdapter()
    gateway.registered_accounts[("bca", "8877665544")] = "BUDI SANTOSO"
    gateway.registered_accounts[("mandiri", "1122334455")] = "SITI AMINAH"
    gateway.registered_accounts[("bni", "5566778899")] = "BUDI SANTOSO"

    app = _test_app(gateway)
    fresh_token = create_access_token(str(user_id), email, user.display_name or "")
    stale_token = _make_stale_token(user_id, email, user.display_name or "", minutes_ago=30)

    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://testserver",
        ) as client:
            # 1. Supported banks
            banks_resp = await client.get(
                "/api/v1/finances/banks",
                headers={"Authorization": f"Bearer {fresh_token}"},
            )
            assert banks_resp.status_code == 200
            assert any(item["code"] == "bca" for item in banks_resp.json()["items"])

            # 2. Legacy direct overwrite bypass is rejected
            legacy_put = await client.put(
                "/api/v1/counselors/me/bank-details",
                headers={"Authorization": f"Bearer {fresh_token}"},
                json={
                    "bank_name": "BCA",
                    "bank_account_number": "99999999",
                    "bank_account_holder": "Fake",
                },
            )
            assert legacy_put.status_code == 403
            assert legacy_put.json()["detail"]["code"] == "BANK_VERIFICATION_REQUIRED"

            # 3. Account not found -> status='not_found'
            nf_val = await client.post(
                "/api/v1/finances/bank-accounts/validate",
                headers={"Authorization": f"Bearer {fresh_token}"},
                json={"bank_code": "bca", "account_number": "0000000000"},
            )
            assert nf_val.status_code == 200
            assert nf_val.json()["status"] == BankValidationStatus.NOT_FOUND.value

            # 4. Name mismatch cannot be saved
            mm_val = await client.post(
                "/api/v1/finances/bank-accounts/validate",
                headers={"Authorization": f"Bearer {fresh_token}"},
                json={"bank_code": "mandiri", "account_number": "1122334455"},
            )
            assert mm_val.status_code == 200
            assert mm_val.json()["name_match"] == BankNameMatchStatus.MISMATCH.value
            mm_save = await client.put(
                "/api/v1/finances/bank-accounts/current",
                headers={"Authorization": f"Bearer {fresh_token}"},
                json={"validation_id": mm_val.json()["validation_id"]},
            )
            assert mm_save.status_code == 422
            assert mm_save.json()["detail"]["code"] == "BANK_NAME_MISMATCH"

            # 5. Valid verification succeeds, encrypts at rest, masks legacy profile, single-use
            ok_val = await client.post(
                "/api/v1/finances/bank-accounts/validate",
                headers={"Authorization": f"Bearer {fresh_token}"},
                json={"bank_code": "bca", "account_number": "8877665544"},
            )
            assert ok_val.status_code == 200
            val_data = ok_val.json()
            assert val_data["status"] == BankValidationStatus.VERIFIED.value
            assert val_data["name_match"] == BankNameMatchStatus.MATCHED.value
            assert val_data["account_number_masked"] == "****5544"

            save_ok = await client.put(
                "/api/v1/finances/bank-accounts/current",
                headers={"Authorization": f"Bearer {fresh_token}"},
                json={"validation_id": val_data["validation_id"]},
            )
            assert save_ok.status_code == 200
            acct_v1 = save_ok.json()["bank_account"]
            assert acct_v1["account_revision"] == 1
            assert acct_v1["verification_status"] == BankVerificationStatus.VERIFIED.value
            assert acct_v1["account_number_masked"] == "****5544"

            # Replay same validation_id -> rejected
            replay_save = await client.put(
                "/api/v1/finances/bank-accounts/current",
                headers={"Authorization": f"Bearer {fresh_token}"},
                json={"validation_id": val_data["validation_id"]},
            )
            assert replay_save.status_code == 409
            assert replay_save.json()["detail"]["code"] == "BANK_UNVERIFIED"

            # Verify ciphertext stored at rest & profile never contains raw number
            async with AsyncSessionLocal() as db:
                stored_acct = (
                    await db.execute(
                        select(CounselorBankAccount).where(CounselorBankAccount.id == uuid.UUID(acct_v1["id"]))
                    )
                ).scalars().first()
                assert stored_acct is not None
                assert stored_acct.account_number_encrypted is not None
                assert "8877665544" not in stored_acct.account_number_encrypted
                assert decrypt_bank_account(stored_acct.account_number_encrypted) == "8877665544"

                stored_prof = (
                    await db.execute(select(PsychologistProfile).where(PsychologistProfile.user_id == user_id))
                ).scalars().first()
                assert stored_prof is not None
                assert stored_prof.bank_account_number == "****5544"

            # 6. Changing existing verified bank with stale JWT requires reauth; password overrides and increments revision
            bni_val = await client.post(
                "/api/v1/finances/bank-accounts/validate",
                headers={"Authorization": f"Bearer {stale_token}"},
                json={"bank_code": "bni", "account_number": "5566778899"},
            )
            assert bni_val.status_code == 200

            stale_save = await client.put(
                "/api/v1/finances/bank-accounts/current",
                headers={"Authorization": f"Bearer {stale_token}"},
                json={"validation_id": bni_val.json()["validation_id"]},
            )
            assert stale_save.status_code == 403
            assert stale_save.json()["detail"]["code"] == "REAUTH_REQUIRED"

            pw_save = await client.put(
                "/api/v1/finances/bank-accounts/current",
                headers={"Authorization": f"Bearer {stale_token}"},
                json={"validation_id": bni_val.json()["validation_id"], "current_password": password},
            )
            assert pw_save.status_code == 200
            assert pw_save.json()["bank_account"]["account_revision"] == 2
            assert pw_save.json()["bank_account"]["bank_code"] == "bni"

            # 7. Expired validation rejected
            exp_val = await client.post(
                "/api/v1/finances/bank-accounts/validate",
                headers={"Authorization": f"Bearer {fresh_token}"},
                json={"bank_code": "bca", "account_number": "8877665544"},
            )
            exp_id = uuid.UUID(exp_val.json()["validation_id"])
            async with AsyncSessionLocal() as db:
                row = (
                    await db.execute(select(BankAccountValidation).where(BankAccountValidation.id == exp_id))
                ).scalars().first()
                assert row is not None
                row.expires_at = datetime.now(UTC) - timedelta(minutes=1)
                await db.commit()

            exp_save = await client.put(
                "/api/v1/finances/bank-accounts/current",
                headers={"Authorization": f"Bearer {fresh_token}"},
                json={"validation_id": str(exp_id)},
            )
            assert exp_save.status_code == 410
            assert exp_save.json()["detail"]["code"] == "VALIDATION_EXPIRED"

            # 8. Rate-limiting after 5 validations in 5 minutes -> 429 RATE_LIMITED
            rate_limited = await client.post(
                "/api/v1/finances/bank-accounts/validate",
                headers={"Authorization": f"Bearer {fresh_token}"},
                json={"bank_code": "bca", "account_number": "8877665544"},
            )
            assert rate_limited.status_code == 429
            assert rate_limited.json()["detail"]["code"] == "RATE_LIMITED"

            # 8. Rate-limiting guard on 6th validation within 5-minute window
            rate_limited = await client.post(
                "/api/v1/finances/bank-accounts/validate",
                headers={"Authorization": f"Bearer {fresh_token}"},
                json={"bank_code": "bca", "account_number": "8877665544"},
            )
            assert rate_limited.status_code == 429
            assert rate_limited.json()["detail"]["code"] == "RATE_LIMITED"
    finally:
        async with AsyncSessionLocal() as db:
            await db.execute(delete(CounselorBankAccount).where(CounselorBankAccount.counselor_id.in_(
                select(PsychologistProfile.id).where(PsychologistProfile.user_id == user_id)
            )))
            await db.execute(delete(BankAccountValidation).where(BankAccountValidation.counselor_id.in_(
                select(PsychologistProfile.id).where(PsychologistProfile.user_id == user_id)
            )))
            await db.execute(delete(PsychologistProfile).where(PsychologistProfile.user_id == user_id))
            await db.execute(delete(User).where(User.id == user_id))
            await db.commit()


@pytest.mark.asyncio
async def test_c4_c6_payout_quote_concurrency_webhook_and_legacy_bypass(monkeypatch):
    monkeypatch.setattr(settings, "BANK_ACCOUNT_ENCRYPTION_KEY", "test-bank-encryption-secret-key-2026")
    suffix = uuid.uuid4().hex[:8]
    user_id = uuid.uuid4()
    counselor_id = uuid.uuid4()
    bank_id = uuid.uuid4()
    email = f"counselor-payout-{suffix}@eva.id"

    async with AsyncSessionLocal() as db:
        user = User(
            id=user_id,
            email=email,
            password_hash="x",
            display_name="Dr. Ratna Wijaya",
            is_active=True,
        )
        profile = PsychologistProfile(
            id=counselor_id,
            user_id=user_id,
            full_name="Dr. Ratna Wijaya",
            str_number=f"STR-R-{suffix}",
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            wallet_balance=Decimal("250000"),
            locked_withdrawal_balance=Decimal("0"),
            bank_name="Bank Central Asia (BCA)",
            bank_account_number="****4321",
            bank_account_holder="RATNA WIJAYA",
        )
        bank = CounselorBankAccount(
            id=bank_id,
            counselor_id=counselor_id,
            bank_code="bca",
            bank_name="Bank Central Asia (BCA)",
            account_number_encrypted=encrypt_bank_account("1234564321"),
            account_number_masked="****4321",
            account_holder_name="RATNA WIJAYA",
            verification_status=BankVerificationStatus.VERIFIED.value,
            verified_at=datetime.now(UTC),
            account_revision=1,
            is_active=True,
        )
        db.add_all([user, profile, bank])
        await db.commit()

    gateway = MockPayoutGatewayAdapter(webhook_secret="iris-unit-secret")
    token = create_access_token(str(user_id), email, "Dr. Ratna Wijaya")
    disabled_app = _test_app(gateway, payout_enabled=False)
    app = _test_app(gateway, payout_enabled=True, auto_approve=True)

    try:
        # 1. Fail-closed when payout_enabled=False
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=disabled_app),
            base_url="http://testserver",
        ) as disabled_client:
            pol = await disabled_client.get(
                "/api/v1/finances/payout-policy",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert pol.status_code == 200
            assert pol.json()["payout_enabled"] is False

            q_disabled = await disabled_client.post(
                "/api/v1/finances/payouts/quote",
                headers={"Authorization": f"Bearer {token}"},
                json={"bank_account_id": str(bank_id), "amount_idr": 150000},
            )
            assert q_disabled.status_code == 503
            assert q_disabled.json()["detail"]["code"] == "PAYOUT_DISABLED"

        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://testserver",
        ) as client:
            # 2. Legacy direct payout bypass rejected
            legacy_po = await client.post(
                "/api/v1/finances/payout",
                headers={"Authorization": f"Bearer {token}"},
                json={"amount": 100000, "bank_name": "BCA", "account_number": "1234564321"},
            )
            assert legacy_po.status_code == 400
            assert legacy_po.json()["detail"]["code"] == "USE_QUOTED_PAYOUT"

            # 3. Quote limits & insufficient balance checks
            too_low = await client.post(
                "/api/v1/finances/payouts/quote",
                headers={"Authorization": f"Bearer {token}"},
                json={"bank_account_id": str(bank_id), "amount_idr": 10000},
            )
            assert too_low.status_code == 400
            assert too_low.json()["detail"]["code"] == "PAYOUT_LIMIT"

            too_high = await client.post(
                "/api/v1/finances/payouts/quote",
                headers={"Authorization": f"Bearer {token}"},
                json={"bank_account_id": str(bank_id), "amount_idr": 999000},
            )
            assert too_high.status_code == 400
            assert too_high.json()["detail"]["code"] == "INSUFFICIENT_BALANCE"

            # 4. Valid quote does NOT lock balance
            q1 = await client.post(
                "/api/v1/finances/payouts/quote",
                headers={"Authorization": f"Bearer {token}"},
                json={"bank_account_id": str(bank_id), "amount_idr": 150000},
            )
            q2 = await client.post(
                "/api/v1/finances/payouts/quote",
                headers={"Authorization": f"Bearer {token}"},
                json={"bank_account_id": str(bank_id), "amount_idr": 150000},
            )
            assert q1.status_code == 200
            assert q2.status_code == 200
            quote1_id = q1.json()["quote_id"]
            quote2_id = q2.json()["quote_id"]
            assert q1.json()["fee_idr"] == 5000
            assert q1.json()["net_amount_idr"] == 145000
            assert q1.json()["wallet_debit_idr"] == 150000

            # 5. Missing Idempotency-Key fails
            no_idem = await client.post(
                "/api/v1/finances/payouts",
                headers={"Authorization": f"Bearer {token}"},
                json={"quote_id": quote1_id},
            )
            assert no_idem.status_code == 400
            assert no_idem.json()["detail"]["code"] == "IDEMPOTENCY_CONFLICT"

            # 6. Parallel concurrent payouts totaling 300k > 250k balance -> only 1 succeeds!
            res_a, res_b = await asyncio.gather(
                client.post(
                    "/api/v1/finances/payouts",
                    headers={"Authorization": f"Bearer {token}", "Idempotency-Key": f"idem-a-{suffix}"},
                    json={"quote_id": quote1_id},
                ),
                client.post(
                    "/api/v1/finances/payouts",
                    headers={"Authorization": f"Bearer {token}", "Idempotency-Key": f"idem-b-{suffix}"},
                    json={"quote_id": quote2_id},
                ),
            )
            statuses = sorted([res_a.status_code, res_b.status_code])
            assert statuses == [201, 400]
            winning_resp = res_a if res_a.status_code == 201 else res_b
            winning_idem = f"idem-a-{suffix}" if res_a.status_code == 201 else f"idem-b-{suffix}"
            winning_quote = quote1_id if res_a.status_code == 201 else quote2_id
            losing_quote = quote2_id if res_a.status_code == 201 else quote1_id

            payout_id = winning_resp.json()["id"]
            assert winning_resp.json()["status"] == PayoutStatus.PROCESSING.value
            assert winning_resp.json()["bank_account"]["account_number_masked"] == "****4321"

            # 7. Idempotency replay returns same payout; conflict rejected
            replay = await client.post(
                "/api/v1/finances/payouts",
                headers={"Authorization": f"Bearer {token}", "Idempotency-Key": winning_idem},
                json={"quote_id": winning_quote},
            )
            assert replay.status_code == 201
            assert replay.json()["id"] == payout_id

            conflict = await client.post(
                "/api/v1/finances/payouts",
                headers={"Authorization": f"Bearer {token}", "Idempotency-Key": winning_idem},
                json={"quote_id": losing_quote},
            )
            assert conflict.status_code == 409
            assert conflict.json()["detail"]["code"] == "IDEMPOTENCY_CONFLICT"

            # 8. Summary shows 100k available and 150k locked
            sum_resp = await client.get(
                "/api/v1/finances/summary",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert sum_resp.status_code == 200
            assert sum_resp.json()["available_balance"] == 100000
            assert sum_resp.json()["locked_withdrawal_balance"] == 150000

            # Transactions endpoint masks bank account info
            trx_resp = await client.get(
                "/api/v1/finances/transactions",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert trx_resp.status_code == 200
            assert "****4321" in (trx_resp.json()[0]["bank_account_info"] or "")
            assert "1234564321" not in json.dumps(trx_resp.json())

            # List & detail
            list_resp = await client.get(
                "/api/v1/finances/payouts",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert list_resp.status_code == 200
            assert list_resp.json()["total"] == 1
            detail_resp = await client.get(
                f"/api/v1/finances/payouts/{payout_id}",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert detail_resp.status_code == 200
            assert detail_resp.json()["id"] == payout_id

            # 9. Iris webhook: invalid signature quarantined -> 403; valid completed webhook unlocks balance
            async with AsyncSessionLocal() as db:
                w_row = (
                    await db.execute(select(CounselorWithdrawal).where(CounselorWithdrawal.id == uuid.UUID(payout_id)))
                ).scalars().first()
                assert w_row is not None and w_row.provider_reference is not None
                ref_no = w_row.provider_reference

            bad_hook = await client.post(
                "/api/v1/webhooks/midtrans/iris",
                headers={"Iris-Signature": "deadbeef" * 16},
                json={"reference_no": ref_no, "status": "completed"},
            )
            assert bad_hook.status_code == 403

            # Update mock provider authoritative status to completed before sending valid webhook
            gateway.records[ref_no].status = "completed"
            hook_body = json.dumps({"reference_no": ref_no, "status": "completed", "amount": "145000"}).encode("utf-8")
            good_sig = hashlib.sha512(hook_body + b"iris-unit-secret").hexdigest()
            ok_hook = await client.post(
                "/api/v1/webhooks/midtrans/iris",
                content=hook_body,
                headers={"Content-Type": "application/json", "Iris-Signature": good_sig},
            )
            assert ok_hook.status_code == 200
            assert ok_hook.json()["status"] == PayoutStatus.COMPLETED.value

            # Replay webhook idempotent
            dup_hook = await client.post(
                "/api/v1/webhooks/midtrans/iris",
                content=hook_body,
                headers={"Content-Type": "application/json", "Iris-Signature": good_sig},
            )
            assert dup_hook.status_code == 200
            assert dup_hook.json()["status"] == "duplicate"

            # Verify locked balance unlocked and transaction completed
            sum_after = await client.get(
                "/api/v1/finances/summary",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert sum_after.json()["available_balance"] == 100000
            assert sum_after.json()["locked_withdrawal_balance"] == 0
            assert sum_after.json()["total_withdrawn"] == 150000

            # 10. Second payout failed/reversed by Iris webhook unlocks & refunds wallet_balance cleanly
            q3 = await client.post(
                "/api/v1/finances/payouts/quote",
                headers={"Authorization": f"Bearer {token}"},
                json={"bank_account_id": str(bank_id), "amount_idr": 80000},
            )
            assert q3.status_code == 200
            po3 = await client.post(
                "/api/v1/finances/payouts",
                headers={"Authorization": f"Bearer {token}", "Idempotency-Key": f"idem-fail-{suffix}"},
                json={"quote_id": q3.json()["quote_id"]},
            )
            assert po3.status_code == 201
            po3_id = po3.json()["id"]

            async with AsyncSessionLocal() as db:
                w3 = (
                    await db.execute(select(CounselorWithdrawal).where(CounselorWithdrawal.id == uuid.UUID(po3_id)))
                ).scalars().first()
                assert w3 is not None and w3.provider_reference is not None
                ref3 = w3.provider_reference

            gateway.records[ref3].status = "failed"
            gateway.records[ref3].failure_reason = "Invalid destination bank"
            fail_body = json.dumps({"reference_no": ref3, "status": "failed"}).encode("utf-8")
            fail_sig = hashlib.sha512(fail_body + b"iris-unit-secret").hexdigest()
            fail_hook = await client.post(
                "/api/v1/webhooks/midtrans/iris",
                content=fail_body,
                headers={"Content-Type": "application/json", "Iris-Signature": fail_sig},
            )
            assert fail_hook.status_code == 200
            assert fail_hook.json()["status"] == PayoutStatus.FAILED.value

            sum_refunded = await client.get(
                "/api/v1/finances/summary",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert sum_refunded.json()["available_balance"] == 100000
            assert sum_refunded.json()["locked_withdrawal_balance"] == 0

            # 11. ACCOUNT_CHANGED check when bank_account_revision changes between quote and submit
            q4 = await client.post(
                "/api/v1/finances/payouts/quote",
                headers={"Authorization": f"Bearer {token}"},
                json={"bank_account_id": str(bank_id), "amount_idr": 60000},
            )
            assert q4.status_code == 200
            async with AsyncSessionLocal() as db:
                b_row = (
                    await db.execute(select(CounselorBankAccount).where(CounselorBankAccount.id == bank_id))
                ).scalars().first()
                assert b_row is not None
                b_row.account_revision += 1
                await db.commit()

            changed_submit = await client.post(
                "/api/v1/finances/payouts",
                headers={"Authorization": f"Bearer {token}", "Idempotency-Key": f"idem-changed-{suffix}"},
                json={"quote_id": q4.json()["quote_id"]},
            )
            assert changed_submit.status_code == 409
            assert changed_submit.json()["detail"]["code"] == "ACCOUNT_CHANGED"

            # 12. Provider liquidity pre-check rejects when Iris balance < net_amount without locking wallet
            gateway.aggregator_balance_idr = 10000
            low_liq = await client.post(
                "/api/v1/finances/payouts",
                headers={"Authorization": f"Bearer {token}", "Idempotency-Key": f"idem-liq-{suffix}"},
                json={"quote_id": q4.json()["quote_id"]},
            )
            assert low_liq.status_code == 503
            assert low_liq.json()["detail"]["code"] == "PROVIDER_UNAVAILABLE"

            sum_final = await client.get(
                "/api/v1/finances/summary",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert sum_final.json()["available_balance"] == 100000
            assert sum_final.json()["locked_withdrawal_balance"] == 0
    finally:
        async with AsyncSessionLocal() as db:
            await db.execute(delete(PaymentWebhookInbox).where(PaymentWebhookInbox.provider == "iris"))
            await db.execute(delete(CounselorWithdrawal).where(CounselorWithdrawal.counselor_id == counselor_id))
            await db.execute(delete(PayoutQuote).where(PayoutQuote.counselor_id == counselor_id))
            await db.execute(delete(CounselorTransaction).where(CounselorTransaction.counselor_id == counselor_id))
            await db.execute(delete(CounselorBankAccount).where(CounselorBankAccount.counselor_id == counselor_id))
            await db.execute(delete(PsychologistProfile).where(PsychologistProfile.id == counselor_id))
            await db.execute(delete(User).where(User.id == user_id))
            await db.commit()
