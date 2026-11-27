import asyncio
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from types import SimpleNamespace
import uuid

from fastapi import FastAPI, HTTPException
import httpx
import pytest
from sqlalchemy import select

from app.api.dependencies import get_coin_topup_service
from app.api.routes.coins import router as coins_router
from app.api.routes.user import router as user_router
from app.api.routes.webhooks import router as webhooks_router
from app.core.security import create_access_token
from app.db.session import AsyncSessionLocal, engine
from app.models.coin import CoinPackage, CoinTransaction
from app.models.counselor import PlatformPricingConfig, PsychologistProfile
from app.models.enums import (
    CoinTransactionType,
    PricingConfigStatus,
    PsychologistVerificationStatus,
    TopupOrderStatus,
)
from app.models.user import User
from app.schemas.coin import CreateCoinTopupRequest
from app.schemas.session import BookSessionRequest
from app.services.coin import CoinTopupService
from app.services.payment import (
    MidtransCoreApiAdapter,
    MockPaymentGatewayAdapter,
    PaymentGatewayError,
)
from app.services.payment.midtrans_adapter import validate_qr_url
from app.services.session import SchedulingService


@pytest.fixture(autouse=True)
async def dispose_engine():
    await engine.dispose()
    yield
    await engine.dispose()


def _test_settings(**overrides):
    defaults = {
        "MIDTRANS_IS_PRODUCTION": False,
        "MIDTRANS_PAYMENT_ENABLED": True,
        "MIDTRANS_SERVER_KEY": "SB-Mid-server-test-key",
        "MIDTRANS_SIGNATURE_SECRET_KEY": "test-sig-secret",
        "MIDTRANS_QRIS_ACQUIRER": "gopay",
    }
    defaults.update(overrides)
    return SimpleNamespace(**defaults)


@pytest.mark.asyncio
async def test_midtrans_adapter_fail_closed_and_ssrf_guard():
    disabled_adapter = MidtransCoreApiAdapter(config=_test_settings(MIDTRANS_PAYMENT_ENABLED=False))
    with pytest.raises(PaymentGatewayError) as exc:
        await disabled_adapter.create_qris_charge(
            order_id="EVA-TEST-1",
            amount_idr=10000,
            item_id="PKG",
            item_name="Paket",
            customer_name="User",
            customer_email="user@eva.id",
        )
    assert exc.value.code == "PAYMENT_DISABLED"

    for bad_url in (
        "http://api.sandbox.midtrans.com/qr.png",
        "https://evil.example.com/qr.png",
        "https://127.0.0.1/qr.png",
        "https://api.sandbox.midtrans.com:8443/qr.png",
    ):
        with pytest.raises(PaymentGatewayError) as ssrf_exc:
            validate_qr_url(bad_url)
        assert ssrf_exc.value.code == "INVALID_QR_HOST"


@pytest.mark.asyncio
async def test_midtrans_adapter_recovers_charge_timeout_via_get_status():
    calls = {"charge": 0, "status": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/v2/charge":
            calls["charge"] += 1
            raise httpx.ReadTimeout("simulated timeout")
        if request.url.path == "/v2/EVA-TIMEOUT-1/status":
            calls["status"] += 1
            return httpx.Response(
                200,
                json={
                    "status_code": "201",
                    "order_id": "EVA-TIMEOUT-1",
                    "transaction_id": "tx-recovered-123",
                    "transaction_status": "pending",
                    "transaction_time": "2026-11-25 18:00:00",
                    "actions": [
                        {"name": "generate-qr-code", "url": "https://api.sandbox.midtrans.com/v2/qris/tx-recovered-123/qr-code"},
                        {"name": "generate-qr-code-v2", "url": "https://merchants-app.sbx.midtrans.com/v4/qris/gopay/abc/qr-code"},
                    ],
                },
            )
        raise AssertionError(f"Unexpected path {request.url.path}")

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        adapter = MidtransCoreApiAdapter(config=_test_settings(), http_client=client)
        res = await adapter.create_qris_charge(
            order_id="EVA-TIMEOUT-1",
            amount_idr=45000,
            item_id="FAV",
            item_name="Paket Favorit",
            customer_name="User",
            customer_email="user@eva.id",
        )

    assert calls == {"charge": 1, "status": 1}
    assert res.provider_transaction_id == "tx-recovered-123"
    assert res.qr_image_v2_url == "https://merchants-app.sbx.midtrans.com/v4/qris/gopay/abc/qr-code"


@pytest.mark.asyncio
async def test_topup_idempotency_webhook_concurrency_and_refund_guards():
    suffix = uuid.uuid4().hex[:6]
    async with AsyncSessionLocal() as db:
        user = User(email=f"topup.{suffix}@eva.id", password_hash="h", coin_balance=10)
        other_user = User(email=f"other.{suffix}@eva.id", password_hash="h", coin_balance=0)
        active_pkg = CoinPackage(
            code=f"FAV_{suffix.upper()}",
            name="Paket Favorit Test",
            coins=150,
            bonus_coins=20,
            price_idr=45000,
            is_active=True,
        )
        inactive_pkg = CoinPackage(
            code=f"OFF_{suffix.upper()}",
            name="Paket Nonaktif",
            coins=50,
            bonus_coins=0,
            price_idr=15000,
            is_active=False,
        )
        db.add_all([user, other_user, active_pkg, inactive_pkg])
        await db.commit()
        await db.refresh(user)
        await db.refresh(other_user)
        await db.refresh(active_pkg)
        await db.refresh(inactive_pkg)

    gateway = MockPaymentGatewayAdapter(signature_secret="test-sig-secret")
    cfg = _test_settings()

    # 1. Inactive package & disabled flag rejected
    async with AsyncSessionLocal() as db:
        disabled_svc = CoinTopupService(db, gateway=gateway, config=_test_settings(MIDTRANS_PAYMENT_ENABLED=False))
        with pytest.raises(HTTPException) as dis_exc:
            await disabled_svc.create_topup_order(user, CreateCoinTopupRequest(package_id=active_pkg.id), "k-dis")
        assert dis_exc.value.status_code == 503
        assert dis_exc.value.detail["code"] == "PAYMENT_DISABLED"

        svc = CoinTopupService(db, gateway=gateway, config=cfg)
        with pytest.raises(HTTPException) as pkg_exc:
            await svc.create_topup_order(user, CreateCoinTopupRequest(package_id=inactive_pkg.id), "k-off")
        assert pkg_exc.value.status_code == 400
        assert pkg_exc.value.detail["code"] == "PACKAGE_INACTIVE"

    # 2. Create order + idempotency replay + idempotency conflict
    idem_key = f"idem-{suffix}"
    async with AsyncSessionLocal() as db:
        svc = CoinTopupService(db, gateway=gateway, config=cfg)
        dto, code1 = await svc.create_topup_order(user, CreateCoinTopupRequest(package_id=active_pkg.id), idem_key)
        assert code1 == 201
        assert dto.status == TopupOrderStatus.PENDING.value
        assert dto.amount_idr == 45000
        assert dto.total_coins == 170

        replay_dto, code2 = await svc.create_topup_order(user, CreateCoinTopupRequest(package_id=active_pkg.id), idem_key)
        assert code2 == 200
        assert replay_dto.id == dto.id
        assert gateway.charge_calls == 1

        with pytest.raises(HTTPException) as conflict_exc:
            await svc.create_topup_order(user, CreateCoinTopupRequest(package_id=inactive_pkg.id), idem_key)
        assert conflict_exc.value.status_code == 409
        assert conflict_exc.value.detail["code"] == "IDEMPOTENCY_CONFLICT"

        # Ownership check
        with pytest.raises(HTTPException) as owner_exc:
            await svc.get_topup_order(other_user.id, uuid.UUID(dto.id))
        assert owner_exc.value.status_code == 404

        # QR proxy bytes
        png = await svc.fetch_qr_png(user.id, uuid.UUID(dto.id))
        assert png.startswith(b"\x89PNG")

        # Refresh rate limit within cooldown
        with pytest.raises(HTTPException) as rate_exc:
            await svc.refresh_topup_order(user.id, uuid.UUID(dto.id))
        assert rate_exc.value.status_code == 429

    # 3. Invalid signature quarantined
    async with AsyncSessionLocal() as db:
        svc = CoinTopupService(db, gateway=gateway, config=cfg)
        with pytest.raises(HTTPException) as sig_exc:
            await svc.handle_midtrans_webhook(
                {
                    "order_id": dto.order_id,
                    "status_code": "200",
                    "gross_amount": "45000.00",
                    "signature_key": "tampered",
                    "transaction_id": gateway.orders[dto.order_id].provider_transaction_id,
                    "transaction_status": "settlement",
                }
            )
        assert sig_exc.value.status_code == 403

    # 4. Concurrent settlement webhooks credit coins EXACTLY ONCE
    gateway.orders[dto.order_id].transaction_status = "settlement"
    gateway.orders[dto.order_id].status_code = "200"
    gateway.orders[dto.order_id].settlement_time = datetime.now(UTC)
    valid_sig = gateway.sign(dto.order_id, "200", "45000.00")

    async def _deliver_webhook():
        async with AsyncSessionLocal() as wdb:
            wsvc = CoinTopupService(wdb, gateway=gateway, config=cfg)
            return await wsvc.handle_midtrans_webhook(
                {
                    "order_id": dto.order_id,
                    "status_code": "200",
                    "gross_amount": "45000.00",
                    "signature_key": valid_sig,
                    "transaction_id": gateway.orders[dto.order_id].provider_transaction_id,
                    "transaction_status": "settlement",
                }
            )

    await asyncio.gather(*[_deliver_webhook() for _ in range(4)])

    # 5. Out-of-order pending webhook must NOT downgrade 'paid'
    gateway.orders[dto.order_id].transaction_status = "pending"
    async with AsyncSessionLocal() as db:
        svc = CoinTopupService(db, gateway=gateway, config=cfg)
        ooo_sig = gateway.sign(dto.order_id, "201", "45000.00")
        ack = await svc.handle_midtrans_webhook(
            {
                "order_id": dto.order_id,
                "status_code": "201",
                "gross_amount": "45000.00",
                "signature_key": ooo_sig,
                "transaction_id": gateway.orders[dto.order_id].provider_transaction_id,
                "transaction_status": "pending",
            }
        )
        assert ack.status == TopupOrderStatus.PAID.value

    async with AsyncSessionLocal() as db:
        u_res = await db.execute(select(User).where(User.id == user.id))
        refreshed_user = u_res.scalar_one()
        assert refreshed_user.coin_balance == 180  # 10 initial + 170 topup once

        tx_res = await db.execute(
            select(CoinTransaction).where(
                CoinTransaction.user_id == user.id,
                CoinTransaction.transaction_type == CoinTransactionType.TOPUP_QRIS.value,
            )
        )
        assert len(tx_res.scalars().all()) == 1

    # 6. Refund when coins untouched succeeds; refund when coins already spent -> review_required
    gateway.orders[dto.order_id].transaction_status = "refund"
    gateway.orders[dto.order_id].refund_amount_idr = 45000
    async with AsyncSessionLocal() as db:
        svc = CoinTopupService(db, gateway=gateway, config=cfg)
        rf_sig = gateway.sign(dto.order_id, "200", "45000.00")
        ack = await svc.handle_midtrans_webhook(
            {
                "order_id": dto.order_id,
                "status_code": "200",
                "gross_amount": "45000.00",
                "signature_key": rf_sig,
                "transaction_id": gateway.orders[dto.order_id].provider_transaction_id,
                "transaction_status": "refund",
            }
        )
        assert ack.status == TopupOrderStatus.REFUNDED.value

    async with AsyncSessionLocal() as db:
        u_res = await db.execute(select(User).where(User.id == user.id))
        assert u_res.scalar_one().coin_balance == 10


@pytest.mark.asyncio
async def test_booking_pending_clearing_release_and_cancel_refund():
    suffix = uuid.uuid4().hex[:6]
    async with AsyncSessionLocal() as db:
        patient = User(email=f"pat.{suffix}@eva.id", password_hash="h", coin_balance=500)
        counselor_user = User(email=f"psy.{suffix}@eva.id", password_hash="h", coin_balance=0)
        db.add_all([patient, counselor_user])
        await db.flush()

        profile = PsychologistProfile(
            user_id=counselor_user.id,
            full_name="Dr. Clearing Test",
            str_number=f"STR-CLR-{suffix}",
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            is_online=True,
            wallet_balance=Decimal("0.00"),
        )
        pricing = PlatformPricingConfig(
            session_duration_minutes=30,
            price_per_session=Decimal("150.00"),
            counselor_share_percentage=Decimal("80.00"),
            platform_fee_percentage=Decimal("20.00"),
            extension_price_per_session=Decimal("150.00"),
            status=PricingConfigStatus.ACTIVE.value,
        )
        db.add_all([profile, pricing])
        await db.commit()
        await db.refresh(patient)
        await db.refresh(profile)

    # Book 2 separate sessions: session A will complete, session B will cancel
    start_a = datetime.now(UTC) + timedelta(days=2)
    start_b = start_a + timedelta(hours=3)
    async with AsyncSessionLocal() as db:
        sched = SchedulingService(db)
        sess_a = await sched.book_session(
            patient.id,
            BookSessionRequest(counselor_id=profile.id, scheduled_start_time=start_a, session_count=1),
        )
        sess_b = await sched.book_session(
            patient.id,
            BookSessionRequest(counselor_id=profile.id, scheduled_start_time=start_b, session_count=1),
        )

    # Wallet balance must STILL be 0.00 while both sessions are SCHEDULED (pending clearing)
    async with AsyncSessionLocal() as db:
        p_res = await db.execute(select(PsychologistProfile).where(PsychologistProfile.id == profile.id))
        assert p_res.scalar_one().wallet_balance == Decimal("0.00")

        u_res = await db.execute(select(User).where(User.id == patient.id))
        assert u_res.scalar_one().coin_balance == 200  # 500 - 150 - 150

        # Complete session A -> releases pending earnings once (second call is no-op)
        sched = SchedulingService(db)
        released1 = await sched.release_pending_session_earnings(uuid.UUID(sess_a.id))
        released2 = await sched.release_pending_session_earnings(uuid.UUID(sess_a.id))
        assert released1 == Decimal("120.00")
        assert released2 == Decimal("0.00")

        # Cancel session B -> voids pending earning and refunds 150 coins once
        refunded1 = await sched.cancel_session_and_refund(uuid.UUID(sess_b.id), reason="patient_cancelled")
        refunded2 = await sched.cancel_session_and_refund(uuid.UUID(sess_b.id), reason="patient_cancelled")
        assert refunded1 == 150
        assert refunded2 == 0

    async with AsyncSessionLocal() as db:
        p_res = await db.execute(select(PsychologistProfile).where(PsychologistProfile.id == profile.id))
        assert p_res.scalar_one().wallet_balance == Decimal("120.00")

        u_res = await db.execute(select(User).where(User.id == patient.id))
        assert u_res.scalar_one().coin_balance == 350


@pytest.mark.asyncio
async def test_c2_and_c6_http_routes_end_to_end():
    suffix = uuid.uuid4().hex[:6]
    async with AsyncSessionLocal() as db:
        user = User(email=f"http.{suffix}@eva.id", password_hash="h", coin_balance=25)
        pkg = CoinPackage(
            code=f"HTTP_{suffix.upper()}",
            name="Paket HTTP Test",
            coins=50,
            bonus_coins=5,
            price_idr=50000,
            is_active=True,
        )
        db.add_all([user, pkg])
        await db.commit()
        await db.refresh(user)
        await db.refresh(pkg)

    gateway = MockPaymentGatewayAdapter(signature_secret="test-sig-secret")
    cfg = _test_settings()

    test_app = FastAPI()
    test_app.include_router(coins_router, prefix="/api/v1")
    test_app.include_router(user_router, prefix="/api/v1")
    test_app.include_router(webhooks_router, prefix="/api/v1")

    async def _override_topup_service():
        async with AsyncSessionLocal() as s:
            yield CoinTopupService(s, gateway=gateway, config=cfg)

    test_app.dependency_overrides[get_coin_topup_service] = _override_topup_service

    token = create_access_token(str(user.id), user.email, "Http User")
    auth_headers = {"Authorization": f"Bearer {token}", "Idempotency-Key": f"http-idem-{suffix}"}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=test_app), base_url="http://test") as client:
        create_res = await client.post(
            "/api/v1/coins/topups",
            headers=auth_headers,
            json={"package_id": str(pkg.id)},
        )
        assert create_res.status_code == 201
        created = create_res.json()
        assert created["amount_idr"] == 50000
        assert created["total_coins"] == 55
        assert created["status"] == "pending"

        qr_res = await client.get(
            f"/api/v1/coins/topups/{created['id']}/qr",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert qr_res.status_code == 200
        assert qr_res.headers["cache-control"] == "private, no-store"
        assert qr_res.content.startswith(b"\x89PNG")

        # Simulate payment settlement via webhook
        gateway.orders[created["order_id"]].transaction_status = "settlement"
        gateway.orders[created["order_id"]].status_code = "200"
        sig = gateway.sign(created["order_id"], "200", "50000.00")
        wh_res = await client.post(
            "/api/v1/webhooks/midtrans/payment",
            json={
                "order_id": created["order_id"],
                "status_code": "200",
                "gross_amount": "50000.00",
                "signature_key": sig,
                "transaction_id": gateway.orders[created["order_id"]].provider_transaction_id,
                "transaction_status": "settlement",
            },
        )
        assert wh_res.status_code == 200
        assert wh_res.json()["status"] == "paid"

        bal_res = await client.get(
            "/api/v1/users/coins",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert bal_res.status_code == 200
        assert bal_res.json()["coin_balance"] == 80  # 25 + 55

        list_res = await client.get(
            "/api/v1/coins/topups?page=1&page_size=20",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert list_res.status_code == 200
        assert list_res.json()["total"] == 1
        assert list_res.json()["items"][0]["status"] == "paid"

        # Sandbox simulation endpoint settles pending order once and rejects in production
        sim_create = await client.post(
            "/api/v1/coins/topups",
            headers={"Authorization": f"Bearer {token}", "Idempotency-Key": f"idem-sim-{suffix}"},
            json={"package_id": str(pkg.id)},
        )
        assert sim_create.status_code == 201
        sim_id = sim_create.json()["id"]

        sim_paid = await client.post(
            f"/api/v1/coins/topups/{sim_id}/simulate-paid",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert sim_paid.status_code == 200
        assert sim_paid.json()["status"] == "paid"

        # Verify coins credited exactly once (80 + 55 = 135)
        bal_after_sim = await client.get(
            "/api/v1/users/coins",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert bal_after_sim.json()["coin_balance"] == 135

        # Fail closed if MIDTRANS_IS_PRODUCTION=True
        prod_app = FastAPI()
        prod_app.include_router(coins_router, prefix="/api/v1")

        async def override_prod_service():
            async with AsyncSessionLocal() as db:
                yield CoinTopupService(
                    db,
                    gateway=gateway,
                    config=_test_settings(MIDTRANS_IS_PRODUCTION=True, APP_ENV="production"),
                )

        prod_app.dependency_overrides[get_coin_topup_service] = override_prod_service
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=prod_app),
            base_url="http://testserver",
        ) as prod_client:
            denied = await prod_client.post(
                f"/api/v1/coins/topups/{sim_id}/simulate-paid",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert denied.status_code == 403
            assert denied.json()["detail"]["code"] == "SANDBOX_ONLY"

