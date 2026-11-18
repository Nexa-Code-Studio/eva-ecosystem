import logging
import uuid
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.counselor import PlatformPricingConfig
from app.models.enums import PricingConfigStatus
from app.schemas.pricing import (
    CreatePricingConfigRequest,
    PricingCalculationResponse,
    PricingConfigResponse,
    UpdatePricingConfigRequest,
)

logger = logging.getLogger(__name__)


class PricingService:
    """Domain service managing centralized platform pricing, 30-minute block rates, and revenue share."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_active_pricing(self) -> PlatformPricingConfig:
        """Fetch current active pricing policy configuration."""
        query = (
            select(PlatformPricingConfig)
            .where(PlatformPricingConfig.status == PricingConfigStatus.ACTIVE.value)
            .order_by(PlatformPricingConfig.effective_from.desc())
        )
        res = await self.db.execute(query)
        config = res.scalars().first()

        if not config:
            # Fallback default configuration (zero until configured by admin)
            config = PlatformPricingConfig(
                session_duration_minutes=30,
                price_per_session=Decimal("0.00"),
                counselor_share_percentage=Decimal("0.00"),
                platform_fee_percentage=Decimal("0.00"),
                extension_price_per_session=Decimal("0.00"),
                status=PricingConfigStatus.ACTIVE.value,
                notes="Default initial platform pricing configuration",
            )
            self.db.add(config)
            await self.db.commit()
            await self.db.refresh(config)

        return config

    async def calculate_pricing(self, config_id: uuid.UUID | None = None) -> PricingCalculationResponse:
        """Calculate financial split for a standard 30-minute consultation session."""
        if config_id:
            query = select(PlatformPricingConfig).where(PlatformPricingConfig.id == config_id)
            res = await self.db.execute(query)
            config = res.scalar_one_or_none()
            if not config:
                config = await self.get_active_pricing()
        else:
            config = await self.get_active_pricing()

        total = config.price_per_session
        counselor_share = (total * config.counselor_share_percentage) / Decimal("100.0")
        platform_fee = (total * config.platform_fee_percentage) / Decimal("100.0")

        return PricingCalculationResponse(
            session_duration_minutes=config.session_duration_minutes,
            total_price=float(total),
            counselor_earning=float(counselor_share),
            platform_fee=float(platform_fee),
            extension_price=float(config.extension_price_per_session),
        )

    async def create_pricing_config(self, payload: CreatePricingConfigRequest) -> PricingConfigResponse:
        """Create new centralized pricing configuration (Web Admin)."""
        # If new config is active, archive old active configs
        query = select(PlatformPricingConfig).where(
            PlatformPricingConfig.status == PricingConfigStatus.ACTIVE.value
        )
        res = await self.db.execute(query)
        active_configs = res.scalars().all()
        for ac in active_configs:
            ac.status = PricingConfigStatus.ARCHIVED.value

        config = PlatformPricingConfig(
            session_duration_minutes=payload.session_duration_minutes,
            price_per_session=Decimal(str(payload.price_per_session)),
            counselor_share_percentage=Decimal(str(payload.counselor_share_percentage)),
            platform_fee_percentage=Decimal(str(payload.platform_fee_percentage)),
            extension_price_per_session=Decimal(str(payload.extension_price_per_session)),
            status=PricingConfigStatus.ACTIVE.value,
            notes=payload.notes,
        )
        self.db.add(config)
        await self.db.commit()
        await self.db.refresh(config)

        return self._to_response(config)

    async def update_pricing_config(
        self,
        config_id: uuid.UUID,
        payload: UpdatePricingConfigRequest,
    ) -> PricingConfigResponse:
        """Update existing pricing configuration."""
        query = select(PlatformPricingConfig).where(PlatformPricingConfig.id == config_id)
        res = await self.db.execute(query)
        config = res.scalar_one_or_none()
        if not config:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Konfigurasi harga tidak ditemukan.",
            )

        if payload.price_per_session is not None:
            config.price_per_session = Decimal(str(payload.price_per_session))
        if payload.counselor_share_percentage is not None:
            config.counselor_share_percentage = Decimal(str(payload.counselor_share_percentage))
        if payload.platform_fee_percentage is not None:
            config.platform_fee_percentage = Decimal(str(payload.platform_fee_percentage))
        if payload.extension_price_per_session is not None:
            config.extension_price_per_session = Decimal(str(payload.extension_price_per_session))
        if payload.status is not None:
            config.status = payload.status
        if payload.notes is not None:
            config.notes = payload.notes

        await self.db.commit()
        await self.db.refresh(config)
        return self._to_response(config)

    async def list_pricing_configs(self) -> list[PricingConfigResponse]:
        """List all pricing configurations for audit and history."""
        query = select(PlatformPricingConfig).order_by(PlatformPricingConfig.created_at.desc())
        res = await self.db.execute(query)
        configs = res.scalars().all()
        return [self._to_response(c) for c in configs]

    def _to_response(self, config: PlatformPricingConfig) -> PricingConfigResponse:
        return PricingConfigResponse(
            id=str(config.id),
            session_duration_minutes=config.session_duration_minutes,
            price_per_session=float(config.price_per_session),
            counselor_share_percentage=float(config.counselor_share_percentage),
            platform_fee_percentage=float(config.platform_fee_percentage),
            extension_price_per_session=float(config.extension_price_per_session),
            status=config.status,
            notes=config.notes,
            effective_from=config.effective_from,
            effective_until=config.effective_until,
            created_at=config.created_at,
        )
