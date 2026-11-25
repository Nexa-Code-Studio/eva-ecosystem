from typing import Generic, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class PaginatedResponse(BaseModel, Generic[T]):
    """Standard C1 paginated envelope for payment, payout, and admin finance lists."""

    items: list[T]
    page: int = Field(..., ge=1)
    page_size: int = Field(..., ge=1, le=100)
    total: int = Field(..., ge=0)
