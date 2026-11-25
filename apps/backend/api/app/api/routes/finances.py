from fastapi import APIRouter, Depends, Header, Query, status

from app.api.dependencies import (
    get_bank_account_service,
    get_current_token_claims,
    get_current_user,
    get_finance_service,
    get_payout_service,
)
from app.models.user import User
from app.schemas.common import PaginatedResponse
from app.schemas.finances import (
    BankValidationResponse,
    CreatePayoutQuoteRequest,
    CreatePayoutRequest,
    CurrentBankAccountResponse,
    FinancialSummaryResponse,
    PayoutPolicyResponse,
    PayoutQuoteResponse,
    PayoutRecordResponse,
    PayoutRequest,
    PayoutResponse,
    SaveBankAccountRequest,
    SupportedBankListResponse,
    TransactionResponse,
    ValidateBankAccountRequest,
)
from app.services.finances import BankAccountService, FinanceService, PayoutService

router = APIRouter(prefix="/finances", tags=["Finances"])


@router.get("/summary", response_model=FinancialSummaryResponse)
async def get_financial_summary(
    user: User = Depends(get_current_user),
    service: FinanceService = Depends(get_finance_service),
) -> FinancialSummaryResponse:
    """Get available balance, clearing balance, locked payout balance, and monthly earnings."""
    return await service.get_summary(user.id)


@router.get("/transactions", response_model=list[TransactionResponse])
async def get_transactions(
    user: User = Depends(get_current_user),
    service: FinanceService = Depends(get_finance_service),
) -> list[TransactionResponse]:
    """Get counselor transaction history with masked destination bank details."""
    return await service.get_transactions(user.id)


@router.post("/payout", response_model=PayoutResponse, status_code=status.HTTP_201_CREATED)
async def request_payout(
    payload: PayoutRequest,
    user: User = Depends(get_current_user),
    service: FinanceService = Depends(get_finance_service),
) -> PayoutResponse:
    """Legacy direct payout endpoint rejected in favor of quoted /finances/payouts."""
    return await service.request_payout(user.id, payload)


@router.get("/banks", response_model=SupportedBankListResponse)
async def list_supported_banks(
    user: User = Depends(get_current_user),
    service: BankAccountService = Depends(get_bank_account_service),
) -> SupportedBankListResponse:
    """List supported beneficiary banks from Iris."""
    return await service.list_supported_banks()


@router.post("/bank-accounts/validate", response_model=BankValidationResponse)
async def validate_bank_account(
    payload: ValidateBankAccountRequest,
    user: User = Depends(get_current_user),
    service: BankAccountService = Depends(get_bank_account_service),
) -> BankValidationResponse:
    """Validate counselor beneficiary bank account and return single-use verification token."""
    return await service.validate_bank_account(user.id, payload)


@router.get("/bank-accounts/current", response_model=CurrentBankAccountResponse)
async def get_current_bank_account(
    user: User = Depends(get_current_user),
    service: BankAccountService = Depends(get_bank_account_service),
) -> CurrentBankAccountResponse:
    """Get current active counselor bank account."""
    return await service.get_current_bank_account(user.id)


@router.put("/bank-accounts/current", response_model=CurrentBankAccountResponse)
async def save_current_bank_account(
    payload: SaveBankAccountRequest,
    user: User = Depends(get_current_user),
    claims: dict = Depends(get_current_token_claims),
    service: BankAccountService = Depends(get_bank_account_service),
) -> CurrentBankAccountResponse:
    """Save a verified bank account token as the active payout account."""
    return await service.save_current_bank_account(user.id, payload, token_claims=claims)


@router.get("/payout-policy", response_model=PayoutPolicyResponse)
async def get_payout_policy(
    user: User = Depends(get_current_user),
    service: PayoutService = Depends(get_payout_service),
) -> PayoutPolicyResponse:
    """Return authoritative payout policy bounds and fee structure."""
    return service.get_payout_policy()


@router.post("/payouts/quote", response_model=PayoutQuoteResponse)
async def create_payout_quote(
    payload: CreatePayoutQuoteRequest,
    user: User = Depends(get_current_user),
    service: PayoutService = Depends(get_payout_service),
) -> PayoutQuoteResponse:
    """Compute a time-limited withdrawal fee and net payout quote."""
    return await service.create_payout_quote(user.id, payload)


@router.post("/payouts", response_model=PayoutRecordResponse, status_code=status.HTTP_201_CREATED)
async def submit_payout(
    payload: CreatePayoutRequest,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    user: User = Depends(get_current_user),
    service: PayoutService = Depends(get_payout_service),
) -> PayoutRecordResponse:
    """Submit an idempotent counselor payout from a valid server quote."""
    return await service.create_payout(user.id, payload, idempotency_key=idempotency_key)


@router.get("/payouts", response_model=PaginatedResponse[PayoutRecordResponse])
async def list_payouts(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    status_filter: str | None = Query(default=None, alias="status"),
    user: User = Depends(get_current_user),
    service: PayoutService = Depends(get_payout_service),
) -> PaginatedResponse[PayoutRecordResponse]:
    """List counselor payout history newest first."""
    return await service.list_payouts(user.id, page=page, page_size=page_size, status_filter=status_filter)


@router.get("/payouts/{payout_id}", response_model=PayoutRecordResponse)
async def get_payout_detail(
    payout_id: str,
    user: User = Depends(get_current_user),
    service: PayoutService = Depends(get_payout_service),
) -> PayoutRecordResponse:
    """Fetch detail for a counselor-owned payout."""
    return await service.get_payout_detail(user.id, payout_id)
