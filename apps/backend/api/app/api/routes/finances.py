from fastapi import APIRouter, Depends, status

from app.api.dependencies import get_current_user, get_finance_service
from app.models.user import User
from app.schemas.finances import (
    FinancialSummaryResponse,
    PayoutRequest,
    PayoutResponse,
    TransactionResponse,
)
from app.services.finances import FinanceService

router = APIRouter(prefix="/finances", tags=["Finances"])


@router.get("/summary", response_model=FinancialSummaryResponse)
async def get_financial_summary(
    user: User = Depends(get_current_user),
    service: FinanceService = Depends(get_finance_service),
) -> FinancialSummaryResponse:
    """Retrieve financial summary, wallet balance, and earnings for authenticated counselor."""
    return await service.get_summary(user.id)


@router.get("/transactions", response_model=list[TransactionResponse])
async def get_transactions(
    user: User = Depends(get_current_user),
    service: FinanceService = Depends(get_finance_service),
) -> list[TransactionResponse]:
    """Retrieve transaction history and earnings ledger for authenticated counselor."""
    return await service.get_transactions(user.id)


@router.post("/payout", response_model=PayoutResponse, status_code=status.HTTP_201_CREATED)
async def request_payout(
    payload: PayoutRequest,
    user: User = Depends(get_current_user),
    service: FinanceService = Depends(get_finance_service),
) -> PayoutResponse:
    """Submit a payout / withdrawal request debited from the counselor's wallet balance."""
    return await service.request_payout(user.id, payload)
