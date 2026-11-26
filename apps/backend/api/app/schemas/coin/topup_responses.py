from datetime import datetime

from pydantic import BaseModel, ConfigDict


class CoinTopupPackageSnapshotResponse(BaseModel):
    """Immutable snapshot of the coin package at the moment of order creation."""

    id: str
    name: str
    coins: int
    bonus_coins: int


class CoinTopupOrderResponse(BaseModel):
    """C2 response contract for a QRIS coin top-up order."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    order_id: str
    package: CoinTopupPackageSnapshotResponse
    amount_idr: int
    currency: str
    total_coins: int
    payment_method: str
    status: str
    qr_image_url: str | None = None
    expires_at: datetime | None = None
    paid_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class MidtransNotificationAckResponse(BaseModel):
    """Acknowledgement returned to Midtrans webhook delivery."""

    received: bool = True
    order_id: str
    status: str
