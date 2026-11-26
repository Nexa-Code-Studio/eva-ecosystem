from fastapi import APIRouter, Depends, Header, Request

from app.api.dependencies import get_coin_topup_service, get_payout_service
from app.schemas.coin import MidtransNotificationAckResponse
from app.schemas.finances import IrisWebhookAckResponse
from app.services.coin import CoinTopupService
from app.services.finances import PayoutService

router = APIRouter(prefix="/webhooks", tags=["Webhooks"])


@router.post("/midtrans/payment", response_model=MidtransNotificationAckResponse)
async def handle_midtrans_payment_webhook(
    request: Request,
    service: CoinTopupService = Depends(get_coin_topup_service),
) -> MidtransNotificationAckResponse:
    """Process Midtrans Core API QRIS HTTP notification webhook."""
    payload = await request.json()
    return await service.handle_midtrans_webhook(payload)


@router.post("/midtrans/iris", response_model=IrisWebhookAckResponse)
async def handle_midtrans_iris_webhook(
    request: Request,
    iris_signature: str | None = Header(default=None, alias="Iris-Signature"),
    service: PayoutService = Depends(get_payout_service),
) -> IrisWebhookAckResponse:
    """Process Midtrans Iris disbursement status notification webhook."""
    raw_body = await request.body()
    payload = await request.json()
    return await service.handle_iris_webhook(
        raw_body=raw_body,
        signature_header=iris_signature,
        payload=payload,
    )
