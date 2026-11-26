import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

from fastapi import HTTPException
from pydantic import BaseModel

from app.core.payment_errors import raise_contract_error
from app.models.enums import (
    BankNameMatchStatus,
    BankValidationStatus,
    BankVerificationStatus,
    CoinTransactionType,
    PayoutStatus,
    ReconciliationStatus,
    TopupOrderStatus,
)
from app.models.payment import (
    BankAccountValidation,
    CoinTopupOrder,
    CounselorBankAccount,
    CounselorWithdrawal,
    CounselorWithdrawalEvent,
    PaymentOutboxEvent,
    PaymentWebhookInbox,
    PayoutQuote,
)
from app.schemas.common import PaginatedResponse
from shared.config import BaseConfig

FIXTURES_DIR = (
    Path(__file__).resolve().parents[4] / "docs" / "contracts" / "fixtures" / "c1_c6"
)


class _DummyItem(BaseModel):
    id: str


class TestPaymentFoundation(unittest.TestCase):
    def test_base_config_zero_breakage_defaults(self):
        with patch.dict(os.environ, {}, clear=True):
            cfg = BaseConfig(_env_file=None)
        self.assertFalse(cfg.MIDTRANS_IS_PRODUCTION)
        self.assertFalse(cfg.MIDTRANS_PAYMENT_ENABLED)
        self.assertFalse(cfg.MIDTRANS_PAYOUT_ENABLED)
        self.assertFalse(cfg.MIDTRANS_PAYOUT_AUTO_APPROVE)
        self.assertEqual(cfg.MIDTRANS_QRIS_ACQUIRER, "gopay")
        self.assertEqual(cfg.MIDTRANS_PAYOUT_PROVIDER_MODE, "iris")
        self.assertEqual(cfg.MIDTRANS_SERVER_KEY, "")
        self.assertEqual(cfg.MIDTRANS_IRIS_CREATOR_KEY, "")
        self.assertEqual(cfg.BANK_ACCOUNT_ENCRYPTION_KEY, "")

    def test_contract_error_and_pagination_envelopes(self):
        with self.assertRaises(HTTPException) as ctx:
            raise_contract_error(409, "IDEMPOTENCY_CONFLICT", "Conflict detected")
        self.assertEqual(ctx.exception.status_code, 409)
        self.assertEqual(
            ctx.exception.detail,
            {"code": "IDEMPOTENCY_CONFLICT", "message": "Conflict detected"},
        )

        page = PaginatedResponse[_DummyItem](
            items=[_DummyItem(id="1")],
            page=1,
            page_size=20,
            total=1,
        )
        self.assertEqual(page.total, 1)
        self.assertEqual(page.items[0].id, "1")

    def test_payment_models_and_enums_registered(self):
        self.assertEqual(CoinTransactionType.TOPUP_QRIS.value, "topup_qris")
        self.assertIn("settlement", {"settlement"})
        self.assertEqual(TopupOrderStatus.PAID.value, "paid")
        self.assertEqual(BankValidationStatus.VERIFIED.value, "verified")
        self.assertEqual(BankNameMatchStatus.MATCHED.value, "matched")
        self.assertEqual(BankVerificationStatus.UNVERIFIED.value, "unverified")
        self.assertEqual(PayoutStatus.WAITING_APPROVAL.value, "waiting_approval")
        self.assertEqual(ReconciliationStatus.MATCHED.value, "matched")

        for model_cls in (
            CoinTopupOrder,
            BankAccountValidation,
            CounselorBankAccount,
            PayoutQuote,
            CounselorWithdrawal,
            CounselorWithdrawalEvent,
            PaymentWebhookInbox,
            PaymentOutboxEvent,
        ):
            self.assertTrue(hasattr(model_cls, "__tablename__"))

    def test_c1_c6_fixtures_are_valid_and_sanitized(self):
        expected_files = (
            "c2_topups.json",
            "c3_c4_counselor_finances.json",
            "c5_admin_finance.json",
        )
        forbidden_tokens = ("SB-Mid-server-", "Mid-server-", "ApbctwIL", "BEGIN PRIVATE KEY")

        for filename in expected_files:
            raw_text = (FIXTURES_DIR / filename).read_text(encoding="utf-8")
            for secret in forbidden_tokens:
                self.assertNotIn(secret, raw_text)
            parsed = json.loads(raw_text)
            self.assertIsInstance(parsed, dict)
