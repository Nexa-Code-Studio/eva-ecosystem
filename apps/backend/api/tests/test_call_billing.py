import asyncio
from contextlib import asynccontextmanager
from unittest.mock import AsyncMock, MagicMock, patch
import uuid

from fastapi import FastAPI
from fastapi.testclient import TestClient
import pytest

from app.api.routes.call import router as call_router
from app.core.call_config import call_config
from app.models.coin import CoinTransaction
from app.models.enums import CoinTransactionType, TransactionStatus
from app.models.user import User
from app.services.call.billing_service import AuthenticatedCallUser, CallBillingService, CallChargeResult


def _scalar_result(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


@pytest.mark.asyncio
async def test_resolve_authenticated_user_rejects_missing_or_invalid_token():
    assert await CallBillingService.resolve_authenticated_user(None) is None
    assert await CallBillingService.resolve_authenticated_user("") is None
    with patch("app.services.call.billing_service.decode_access_token", return_value=None):
        assert await CallBillingService.resolve_authenticated_user("bad.token") is None


@pytest.mark.asyncio
async def test_charge_call_minute_atomic_debit_and_insufficient():
    user_id = uuid.uuid4()
    user = User(id=user_id, email="caller@eva.id", is_active=True, coin_balance=1)

    mock_db = MagicMock()
    mock_db.execute = AsyncMock(return_value=_scalar_result(user))
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()

    @asynccontextmanager
    async def _fake_session():
        yield mock_db

    with patch("app.services.call.billing_service.AsyncSessionLocal", _fake_session):
        first = await CallBillingService.charge_call_minute(
            user_id=user_id,
            session_id="sess_bill_1",
            minute_index=1,
            coins_cost=1,
        )
        assert first.success is True
        assert first.coins_debited == 1
        assert first.coin_balance == 0
        assert user.coin_balance == 0

        added_tx = mock_db.add.call_args[0][0]
        assert isinstance(added_tx, CoinTransaction)
        assert added_tx.transaction_type == CoinTransactionType.AI_CALL_DEBIT.value
        assert added_tx.coins_delta == -1
        assert added_tx.balance_after == 0
        assert added_tx.status == TransactionStatus.COMPLETED.value
        assert added_tx.reference_session_id is None

        second = await CallBillingService.charge_call_minute(
            user_id=user_id,
            session_id="sess_bill_1",
            minute_index=2,
            coins_cost=1,
        )
        assert second.success is False
        assert second.reason == "insufficient_coins"
        assert second.coin_balance == 0


def test_call_websocket_rejects_unauthenticated_connection():
    ws_app = FastAPI()
    ws_app.include_router(call_router, prefix="/api/v1")
    client = TestClient(ws_app)

    with client.websocket_connect("/api/v1/call/ws/unauth_sess") as ws:
        evt = ws.receive_json()
        assert evt["type"] == "call.auth_error"
        assert evt["code"] == "AUTH_REQUIRED"


def test_call_websocket_rejects_zero_coin_balance_on_start_call():
    ws_app = FastAPI()
    ws_app.include_router(call_router, prefix="/api/v1")
    client = TestClient(ws_app)

    mock_user = AuthenticatedCallUser(user_id=uuid.uuid4(), display_name="Zero Coin", coin_balance=0)
    insufficient = CallChargeResult(
        success=False,
        coin_balance=0,
        coins_debited=0,
        minute_index=1,
        reason="insufficient_coins",
    )

    with (
        patch("app.services.call.session_manager.CallBillingService.resolve_authenticated_user", new=AsyncMock(return_value=mock_user)),
        patch("app.services.call.session_manager.CallBillingService.charge_call_minute", new=AsyncMock(return_value=insufficient)),
    ):
        with client.websocket_connect("/api/v1/call/ws/zero_coin_sess?token=ok&privacy_mode=local_private") as ws:
            connected = ws.receive_json()
            assert connected["type"] == "call_connected"

            ws.send_json({"type": "start_call"})
            evt = ws.receive_json()
            assert evt["type"] == "call.billing_insufficient"
            assert evt["coin_balance"] == 0
            assert evt["required_coins"] == call_config.ai_call_coins_per_minute


def test_call_websocket_auto_debit_warning_and_graceful_end(monkeypatch):
    ws_app = FastAPI()
    ws_app.include_router(call_router, prefix="/api/v1")
    client = TestClient(ws_app)

    monkeypatch.setattr(call_config, "ai_call_coins_per_minute", 1)
    monkeypatch.setattr(call_config, "ai_call_interval_seconds", 2)
    monkeypatch.setattr(call_config, "ai_call_warning_seconds", 1)
    monkeypatch.setattr(call_config, "ai_call_grace_seconds", 1)

    user_id = uuid.uuid4()
    state = {"balance": 2}
    mock_user = AuthenticatedCallUser(user_id=user_id, display_name="Auto Debit", coin_balance=2)

    async def _fake_charge(user_id, session_id, minute_index, coins_cost):
        if state["balance"] < coins_cost:
            return CallChargeResult(
                success=False,
                coin_balance=state["balance"],
                coins_debited=0,
                minute_index=minute_index,
                reason="insufficient_coins",
            )
        state["balance"] -= coins_cost
        return CallChargeResult(
            success=True,
            coin_balance=state["balance"],
            coins_debited=coins_cost,
            minute_index=minute_index,
            invoice_code=f"EVA-CALL-T-{minute_index}",
        )

    async def _fake_balance(user_id):
        return state["balance"]

    with (
        patch("app.services.call.session_manager.CallBillingService.resolve_authenticated_user", new=AsyncMock(return_value=mock_user)),
        patch("app.services.call.session_manager.CallBillingService.charge_call_minute", side_effect=_fake_charge),
        patch("app.services.call.session_manager.CallBillingService.get_user_coin_balance", side_effect=_fake_balance),
    ):
        with client.websocket_connect("/api/v1/call/ws/auto_debit_sess?token=ok&privacy_mode=local_private") as ws:
            assert ws.receive_json()["type"] == "call_connected"

            # Duplicate start_call must be idempotent (only charge minute 1 once)
            ws.send_json({"type": "start_call"})
            started_1 = ws.receive_json()
            assert started_1["type"] == "call_started"
            assert started_1["billing"]["current_minute"] == 1
            assert started_1["billing"]["remaining_balance"] == 1

            ws.send_json({"type": "start_call"})
            started_dup = ws.receive_json()
            assert started_dup["type"] == "call_started"
            assert state["balance"] == 1

            events = []
            for _ in range(10):
                try:
                    evt = ws.receive_json()
                    events.append(evt)
                    if evt.get("type") == "call.ended_by_billing":
                        break
                except Exception:
                    break

            types = [e.get("type") for e in events]
            assert "call.billing_warning" in types
            assert "call.billing_charged" in types
            assert "call.billing_exhausted" in types
            assert "call.ended_by_billing" in types

            charged = next(e for e in events if e["type"] == "call.billing_charged")
            assert charged["current_minute"] == 2
            assert charged["remaining_balance"] == 0

            warnings = [e for e in events if e["type"] == "call.billing_warning"]
            assert warnings[0]["will_expire_if_zero"] is False
            assert warnings[-1]["will_expire_if_zero"] is True
