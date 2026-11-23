from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock
import unittest
import uuid

from fastapi import HTTPException
from httpx import ASGITransport, AsyncClient
import pytest

from app.db.session import engine
from app.main import app
from app.models.coin import CoinEconomyConfig, CoinPackage
from app.models.user import User
from app.schemas.auth import RegisterRequest
from app.schemas.coin import UpdateCoinEconomyConfigRequest, UpsertCoinPackageRequest
from app.services.auth.auth_service import AuthService
from app.services.coin import CoinService


def _scalar_result(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    result.scalars.return_value.all.return_value = (
        value if isinstance(value, list) else ([value] if value else [])
    )
    return result


class TestCoinPackagesAndEconomyUnit(unittest.IsolatedAsyncioTestCase):
    async def test_create_and_update_package_enforces_unique_code(self):
        now = datetime.now(UTC)
        pkg_id = uuid.uuid4()
        existing_pkg = CoinPackage(
            id=pkg_id,
            code="COIN-50",
            name="Paket Lama",
            coins=50,
            bonus_coins=5,
            price_idr=45000,
            description="Desc",
            is_popular=False,
            is_active=True,
            created_at=now,
            updated_at=now,
        )

        db = MagicMock()
        db.add = MagicMock()
        db.commit = AsyncMock()
        db.delete = AsyncMock()

        async def _refresh(obj):
            if getattr(obj, "id", None) is None:
                obj.id = uuid.uuid4()
            if getattr(obj, "created_at", None) is None:
                obj.created_at = now
            if getattr(obj, "updated_at", None) is None:
                obj.updated_at = now

        db.refresh = AsyncMock(side_effect=_refresh)
        service = CoinService(db)

        # Duplicate code on create -> 409
        db.execute = AsyncMock(return_value=_scalar_result(existing_pkg))
        with self.assertRaises(HTTPException) as dup_ctx:
            await service.create_package(
                UpsertCoinPackageRequest(
                    code="coin-50",
                    name="Paket Baru",
                    coins=50,
                    bonus_coins=0,
                    price_idr=50000,
                )
            )
        self.assertEqual(dup_ctx.exception.status_code, 409)

        # Create clean package -> normalizes code to uppercase
        db.execute = AsyncMock(return_value=_scalar_result(None))
        created = await service.create_package(
            UpsertCoinPackageRequest(
                code="coin-75",
                name="Paket Hemat",
                coins=75,
                bonus_coins=10,
                price_idr=65000,
                description="Paket hemat 75+10",
                is_popular=True,
                is_active=True,
            )
        )
        self.assertEqual(created.code, "COIN-75")
        self.assertEqual(created.coins, 75)
        self.assertTrue(created.is_popular)

        # Toggle active
        db.execute = AsyncMock(return_value=_scalar_result(existing_pkg))
        toggled = await service.toggle_package_active(pkg_id)
        self.assertFalse(toggled.is_active)

    async def test_economy_config_default_and_register_reads_free_trial(self):
        now = datetime.now(UTC)
        db = MagicMock()
        db.add = MagicMock()
        db.commit = AsyncMock()

        async def _refresh(obj):
            if getattr(obj, "id", None) is None:
                obj.id = uuid.uuid4()
            if getattr(obj, "created_at", None) is None:
                obj.created_at = now
            if getattr(obj, "updated_at", None) is None:
                obj.updated_at = now

        db.refresh = AsyncMock(side_effect=_refresh)

        coin_service = CoinService(db)
        db.execute = AsyncMock(return_value=_scalar_result(None))
        default_cfg = await coin_service.get_economy_config()
        self.assertEqual(default_cfg.base_price_per_coin_idr, 1000)
        self.assertEqual(default_cfg.free_trial_coins_new_user, 10)

        cfg = CoinEconomyConfig(
            id=uuid.uuid4(),
            base_price_per_coin_idr=1200,
            free_trial_coins_new_user=25,
            created_at=now,
            updated_at=now,
        )
        db.execute = AsyncMock(return_value=_scalar_result(cfg))
        updated = await coin_service.update_economy_config(
            UpdateCoinEconomyConfigRequest(
                base_price_per_coin_idr=1200,
                free_trial_coins_new_user=25,
            )
        )
        self.assertEqual(updated.base_price_per_coin_idr, 1200)
        self.assertEqual(updated.free_trial_coins_new_user, 25)

        # AuthService.register assigns coin_balance from CoinEconomyConfig
        auth_db = MagicMock()
        added_users: list[User] = []

        def _capture_add(obj):
            if isinstance(obj, User):
                if getattr(obj, "id", None) is None:
                    obj.id = uuid.uuid4()
                added_users.append(obj)

        auth_db.add = MagicMock(side_effect=_capture_add)
        auth_db.commit = AsyncMock()
        auth_db.refresh = AsyncMock()
        auth_db.execute = AsyncMock(side_effect=[_scalar_result(None), _scalar_result(cfg)])

        auth_service = AuthService(auth_db)
        token_res = await auth_service.register(
            RegisterRequest(
                name="Pengguna Baru Trial",
                email="trial.user@eva.id",
                password="Password123!",
            )
        )
        self.assertEqual(len(added_users), 1)
        self.assertEqual(added_users[0].coin_balance, 25)
        self.assertEqual(token_res.user.coin_balance, 25)


@pytest.fixture
async def clean_engine():
    await engine.dispose()
    yield
    await engine.dispose()


@pytest.mark.asyncio
async def test_coin_package_and_economy_endpoints_e2e(clean_engine):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # Public endpoints require no auth
        pub_pkgs = await client.get("/api/v1/coins/packages")
        assert pub_pkgs.status_code == 200
        assert any(p["code"] == "COIN-15" for p in pub_pkgs.json())

        pub_econ = await client.get("/api/v1/coins/economy")
        assert pub_econ.status_code == 200
        assert pub_econ.json()["base_price_per_coin_idr"] >= 100

        # Non-admin rejected with 403
        user_login = await client.post(
            "/api/v1/auth/login",
            json={"email": "samsul@gmail.com", "password": "password123"},
        )
        user_headers = {"Authorization": f"Bearer {user_login.json()['access_token']}"}
        assert (await client.get("/api/v1/admin/coins/packages", headers=user_headers)).status_code == 403
        assert (
            await client.put(
                "/api/v1/admin/coins/economy",
                headers=user_headers,
                json={"base_price_per_coin_idr": 1000, "free_trial_coins_new_user": 10},
            )
        ).status_code == 403

        # Admin lifecycle: list -> create -> toggle inactive -> verify hidden on public -> delete
        admin_login = await client.post(
            "/api/v1/auth/login",
            json={"email": "admin@eva.id", "password": "AdminEva2026!"},
        )
        admin_headers = {"Authorization": f"Bearer {admin_login.json()['access_token']}"}

        temp_code = f"COIN-TEST-{uuid.uuid4().hex[:4].upper()}"
        create_res = await client.post(
            "/api/v1/admin/coins/packages",
            headers=admin_headers,
            json={
                "code": temp_code.lower(),
                "name": "Paket Uji Sementara",
                "coins": 40,
                "bonus_coins": 5,
                "price_idr": 38000,
                "description": "Uji CRUD backend",
                "is_popular": False,
                "is_active": True,
            },
        )
        assert create_res.status_code == 201
        created = create_res.json()
        assert created["code"] == temp_code

        # Toggle inactive and verify public list excludes it
        toggle_res = await client.patch(
            f"/api/v1/admin/coins/packages/{created['id']}/toggle",
            headers=admin_headers,
        )
        assert toggle_res.status_code == 200
        assert toggle_res.json()["is_active"] is False

        pub_after_toggle = await client.get("/api/v1/coins/packages")
        assert all(p["id"] != created["id"] for p in pub_after_toggle.json())

        # Clean up temp package
        del_res = await client.delete(
            f"/api/v1/admin/coins/packages/{created['id']}",
            headers=admin_headers,
        )
        assert del_res.status_code == 200
