from datetime import datetime

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_admin_finance_service, get_current_admin
from app.models.user import User
from app.schemas.admin_finance import (
    AdminFinanceSummaryResponse,
    AdminFinanceTransactionDetailResponse,
    AdminFinanceTransactionItemResponse,
)
from app.schemas.common import PaginatedResponse
from app.services.admin_finance import AdminFinanceService

router = APIRouter(prefix="/admin/finance", tags=["Admin Finance"])


@router.get("/summary", response_model=AdminFinanceSummaryResponse)
async def get_admin_finance_summary(
    from_at: datetime | None = Query(default=None, alias="from"),
    to_at: datetime | None = Query(default=None, alias="to"),
    admin: User = Depends(get_current_admin),
    service: AdminFinanceService = Depends(get_admin_finance_service),
) -> AdminFinanceSummaryResponse:
    """Return real-money platform financial summary separated from coin grants."""
    return await service.get_summary(from_at=from_at, to_at=to_at)


@router.get("/transactions", response_model=PaginatedResponse[AdminFinanceTransactionItemResponse])
async def list_admin_finance_transactions(
    from_at: datetime | None = Query(default=None, alias="from"),
    to_at: datetime | None = Query(default=None, alias="to"),
    direction: str | None = Query(default=None), status: str | None = Query(default=None),
    source: str | None = Query(default=None), q: str | None = Query(default=None),
    page: int = Query(default=1, ge=1), page_size: int = Query(default=20, ge=1, le=100),
    admin: User = Depends(get_current_admin),
    service: AdminFinanceService = Depends(get_admin_finance_service),
) -> PaginatedResponse[AdminFinanceTransactionItemResponse]:
    """List paginated audited financial transactions for admin supervision."""
    return await service.list_transactions(
        from_at=from_at, to_at=to_at, direction=direction, status_filter=status,
        source=source, q=q, page=page, page_size=page_size,
    )


@router.get("/transactions/{record_id}", response_model=AdminFinanceTransactionDetailResponse)
async def get_admin_finance_transaction_detail(
    record_id: str,
    admin: User = Depends(get_current_admin),
    service: AdminFinanceService = Depends(get_admin_finance_service),
) -> AdminFinanceTransactionDetailResponse:
    """Get detailed sanitized transaction record and timeline events for admin review."""
    return await service.get_transaction_detail(record_id)
