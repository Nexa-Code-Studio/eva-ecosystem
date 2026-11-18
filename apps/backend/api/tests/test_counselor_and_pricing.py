import unittest
import uuid
from decimal import Decimal
from datetime import UTC, datetime

from app.models.counselor import (
    ConsultationSession,
    CounselorTransaction,
    PlatformPricingConfig,
    PsychologistProfile,
)
from app.models.enums import (
    ConsultationSessionStatus,
    PricingConfigStatus,
    PsychologistVerificationStatus,
    TransactionStatus,
    TransactionType,
)
from app.schemas.counselor import (
    RegisterPsychologistRequest,
    ResubmitVerificationRequest,
    ToggleAvailabilityRequest,
    UpdateBankDetailsRequest,
    UpdatePsychologistProfileRequest,
    VerifyPsychologistRequest,
)
from app.schemas.pricing import (
    CreatePricingConfigRequest,
    PricingCalculationResponse,
    UpdatePricingConfigRequest,
)


class TestCounselorAndPricingModels(unittest.TestCase):
    def test_psychologist_profile_defaults(self):
        profile = PsychologistProfile(
            user_id=uuid.uuid4(),
            full_name="Dr. Sarah Anindya, M.Psi., Psikolog",
            title_degree="M.Psi., Psikolog",
            str_number="STR-PK-198827364-2026",
            sip_number="SIP-198827364-2026",
            association="Himpunan Psikologi Indonesia (HIMPSI)",
            specializations=["Kecemasan Dewasa", "Depresi Ringan"],
            years_of_experience=5,
        )

        self.assertEqual(profile.full_name, "Dr. Sarah Anindya, M.Psi., Psikolog")
        self.assertEqual(profile.str_number, "STR-PK-198827364-2026")
        self.assertEqual(profile.verification_status, PsychologistVerificationStatus.PENDING.value)
        self.assertTrue(profile.is_online)
        self.assertEqual(profile.buffer_time_minutes, 10)
        self.assertEqual(profile.wallet_balance, Decimal("0.00"))
        self.assertIsNone(profile.verified_at)
        self.assertIsNone(profile.verification_notes)

    def test_platform_pricing_config_defaults(self):
        pricing = PlatformPricingConfig(
            session_duration_minutes=30,
            price_per_session=Decimal("150000.00"),
            counselor_share_percentage=Decimal("70.00"),
            platform_fee_percentage=Decimal("30.00"),
            extension_price_per_session=Decimal("150000.00"),
            status=PricingConfigStatus.ACTIVE.value,
        )

        self.assertEqual(pricing.session_duration_minutes, 30)
        self.assertEqual(pricing.price_per_session, Decimal("150000.00"))
        self.assertEqual(pricing.counselor_share_percentage, Decimal("70.00"))
        self.assertEqual(pricing.platform_fee_percentage, Decimal("30.00"))
        self.assertEqual(pricing.status, PricingConfigStatus.ACTIVE.value)

    def test_pricing_calculation_math(self):
        total = Decimal("200000.00")
        counselor_pct = Decimal("75.00")
        platform_pct = Decimal("25.00")

        counselor_earning = (total * counselor_pct) / Decimal("100.0")
        platform_fee = (total * platform_pct) / Decimal("100.0")

        self.assertEqual(counselor_earning, Decimal("150000.00"))
        self.assertEqual(platform_fee, Decimal("50000.00"))
        self.assertEqual(counselor_earning + platform_fee, total)

    def test_consultation_session_30_minute_block(self):
        start = datetime.now(UTC)
        end = start.replace(minute=(start.minute + 30) % 60)

        session = ConsultationSession(
            session_code="EVA-SES-202611-0001",
            patient_id=uuid.uuid4(),
            counselor_id=uuid.uuid4(),
            scheduled_start_time=start,
            scheduled_end_time=end,
            duration_minutes=30,
            status=ConsultationSessionStatus.SCHEDULED.value,
            is_extended=False,
            total_price=Decimal("150000.00"),
            counselor_earning=Decimal("105000.00"),
            platform_fee=Decimal("45000.00"),
        )

        self.assertEqual(session.duration_minutes, 30)
        self.assertFalse(session.is_extended)
        self.assertEqual(session.status, ConsultationSessionStatus.SCHEDULED.value)
        self.assertIsNone(session.extension_requested_at)
        self.assertIsNone(session.extension_granted_at)

    def test_counselor_transaction_ledger(self):
        tx = CounselorTransaction(
            counselor_id=uuid.uuid4(),
            transaction_type=TransactionType.EARNING.value,
            status=TransactionStatus.COMPLETED.value,
            amount=Decimal("105000.00"),
            description="Honorarium telekonsultasi 30 menit sesi EVA-SES-202611-0001",
            reference_number="TX-20261118-0001",
        )

        self.assertEqual(tx.transaction_type, TransactionType.EARNING.value)
        self.assertEqual(tx.status, TransactionStatus.COMPLETED.value)
        self.assertEqual(tx.amount, Decimal("105000.00"))


class TestCounselorAndPricingSchemas(unittest.TestCase):
    def test_register_request_validation(self):
        req = RegisterPsychologistRequest(
            full_name="Budi Santoso, M.Psi., Psikolog",
            title_degree="M.Psi., Psikolog",
            email="budi.santoso@psikolog.eva.id",
            password="StrongPassword123!",
            str_number="STR-PK-998877",
            association="HIMPSI",
            specializations=["Keluarga", "Hubungan"],
            years_of_experience=4,
        )
        self.assertEqual(req.full_name, "Budi Santoso, M.Psi., Psikolog")
        self.assertEqual(req.str_number, "STR-PK-998877")
        self.assertEqual(req.years_of_experience, 4)

    def test_pricing_calculation_response_contract(self):
        res = PricingCalculationResponse(
            session_duration_minutes=30,
            total_price=150000.0,
            counselor_earning=105000.0,
            platform_fee=45000.0,
            extension_price=150000.0,
        )
        self.assertEqual(res.session_duration_minutes, 30)
        self.assertEqual(res.total_price, 150000.0)
        self.assertEqual(res.counselor_earning + res.platform_fee, res.total_price)


if __name__ == "__main__":
    unittest.main()
