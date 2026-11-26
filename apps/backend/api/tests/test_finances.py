import uuid
import pytest
from httpx import ASGITransport, AsyncClient
from decimal import Decimal

from app.db.session import engine, AsyncSessionLocal
from app.models.counselor import PsychologistProfile, CounselorTransaction
from app.models.enums import TransactionStatus, TransactionType
from app.models.user import User
from app.main import app


@pytest.fixture(autouse=True)
async def dispose_engine():
    await engine.dispose()
    yield
    await engine.dispose()


@pytest.fixture
async def counselor_auth():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # Register or login counselor
        email = f"counselor.{uuid.uuid4().hex[:6]}@eva.id"
        password = "Password123!"
        reg_res = await client.post(
            "/api/v1/counselors/register",
            json={
                "email": email,
                "password": password,
                "full_name": "Test Counselor, M.Psi., Psikolog",
                "str_number": f"STR-{uuid.uuid4().hex[:8]}",
                "specializations": ["Depresi", "Kecemasan"],
                "years_of_experience": 4,
            },
        )
        assert reg_res.status_code == 201

        login_res = await client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": password},
        )
        assert login_res.status_code == 200
        token = login_res.json()["access_token"]
        return {"headers": {"Authorization": f"Bearer {token}"}, "email": email}


@pytest.mark.asyncio
async def test_finances_summary_and_transactions(counselor_auth):
    headers = counselor_auth["headers"]
    email = counselor_auth["email"]

    # Fund wallet balance in database for testing
    async with AsyncSessionLocal() as session:
        from sqlalchemy import select
        user_res = await session.execute(select(User).where(User.email == email))
        user_obj = user_res.scalar_one()

        prof_res = await session.execute(select(PsychologistProfile).where(PsychologistProfile.user_id == user_obj.id))
        profile = prof_res.scalar_one()
        profile.wallet_balance = Decimal("2500000.00")
        profile.bank_name = "BCA"
        profile.bank_account_number = "8192039182"
        profile.bank_account_holder = "Test Counselor"

        # Add mock earning transaction
        trx = CounselorTransaction(
            counselor_id=profile.id,
            transaction_type=TransactionType.EARNING.value,
            status=TransactionStatus.COMPLETED.value,
            amount=Decimal("150000.00"),
            description="Telekonsultasi Video (30 Menit)",
            reference_number="TRX-2026-TEST01",
        )
        session.add(trx)
        await session.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. Summary
        sum_res = await client.get("/api/v1/finances/summary", headers=headers)
        assert sum_res.status_code == 200
        summary = sum_res.json()
        assert summary["available_balance"] == 2500000
        assert summary["total_earnings_this_month"] >= 150000

        # 2. Transactions
        tx_res = await client.get("/api/v1/finances/transactions", headers=headers)
        assert tx_res.status_code == 200
        txs = tx_res.json()
        assert len(txs) >= 1
        assert txs[0]["id"] == "TRX-2026-TEST01"
        assert txs[0]["net_earnings"] == 150000

        # 3. Legacy direct payout bypass is disabled
        payout_res = await client.post(
            "/api/v1/finances/payout",
            headers=headers,
            json={
                "amount": 500000,
                "bank_name": "BCA",
                "account_number": "8192039182",
                "account_holder": "Test Counselor",
            },
        )
        assert payout_res.status_code == 400
        assert payout_res.json()["detail"]["code"] == "USE_QUOTED_PAYOUT"

        # 4. Verify balance remained intact
        sum_after = await client.get("/api/v1/finances/summary", headers=headers)
        assert sum_after.json()["available_balance"] == 2500000
        assert sum_after.json()["locked_withdrawal_balance"] == 0
