import uuid

from pydantic import BaseModel, Field


class CreateCoinTopupRequest(BaseModel):
    """Payload for initiating a server-authoritative QRIS EVA Coin top-up order."""

    package_id: uuid.UUID = Field(..., description="Active EVA Coin package UUID")
