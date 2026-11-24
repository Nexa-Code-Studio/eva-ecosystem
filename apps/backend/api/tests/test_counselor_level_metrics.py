import unittest
import uuid
from decimal import Decimal

from app.models.counselor import (
    CounselorReview,
    PsychologistLevel,
    PsychologistProfile,
)
from app.schemas.counselor import (
    CounselorLevelMetricsResponse,
    CounselorReviewItemResponse,
    CounselorReviewsListResponse,
    NextLevelTargetResponse,
    SubmitSessionReviewRequest,
    UpdatePricingRequest,
)


class TestCounselorLevelMetricsAndReviews(unittest.TestCase):
    def test_psychologist_level_defaults_and_fields(self):
        level = PsychologistLevel(
            level_tier=1,
            name="Junior Practitioner",
            badge_icon="shield",
            min_completed_sessions=0,
            min_average_rating=Decimal("0.00"),
            min_consultation_hours=Decimal("0.0"),
            min_review_count=0,
            default_session_price=Decimal("50000.00"),
            platform_fee_percentage=Decimal("20.00"),
            allow_custom_price=False,
            is_active=True,
        )
        self.assertEqual(level.level_tier, 1)
        self.assertEqual(level.name, "Junior Practitioner")
        self.assertFalse(level.allow_custom_price)
        self.assertEqual(level.default_session_price, Decimal("50000.00"))
        self.assertEqual(level.platform_fee_percentage, Decimal("20.00"))

    def test_master_expert_level_with_custom_price(self):
        level = PsychologistLevel(
            level_tier=4,
            name="Master Expert",
            badge_icon="workspace_premium",
            min_completed_sessions=60,
            min_average_rating=Decimal("4.85"),
            min_consultation_hours=Decimal("30.0"),
            min_review_count=30,
            default_session_price=Decimal("150000.00"),
            platform_fee_percentage=Decimal("20.00"),
            allow_custom_price=True,
            min_custom_price=Decimal("100000.00"),
            max_custom_price=Decimal("500000.00"),
            is_active=True,
        )
        self.assertEqual(level.level_tier, 4)
        self.assertTrue(level.allow_custom_price)
        self.assertEqual(level.min_custom_price, Decimal("100000.00"))
        self.assertEqual(level.max_custom_price, Decimal("500000.00"))

    def test_counselor_review_model(self):
        session_id = uuid.uuid4()
        counselor_id = uuid.uuid4()
        patient_id = uuid.uuid4()

        review = CounselorReview(
            session_id=session_id,
            counselor_id=counselor_id,
            patient_id=patient_id,
            rating=Decimal("5.0"),
            label="Sangat Sabar & Empati",
            review_text="Sesi konsultasi sangat membuka wawasan dan memberikan ketenangan.",
            is_anonymous=True,
        )
        self.assertEqual(review.session_id, session_id)
        self.assertEqual(review.counselor_id, counselor_id)
        self.assertEqual(review.patient_id, patient_id)
        self.assertEqual(review.rating, Decimal("5.0"))
        self.assertTrue(review.is_anonymous)

    def test_profile_level_metrics_attributes(self):
        profile = PsychologistProfile(
            user_id=uuid.uuid4(),
            full_name="Dr. Sarah Anindya",
            str_number="STR-12345",
            total_completed_sessions=25,
            total_consultation_hours=Decimal("12.5"),
            average_rating=Decimal("4.92"),
            rating_count=18,
            custom_price_per_session=Decimal("125000.00"),
        )
        self.assertEqual(profile.total_completed_sessions, 25)
        self.assertEqual(profile.total_consultation_hours, Decimal("12.5"))
        self.assertEqual(profile.average_rating, Decimal("4.92"))
        self.assertEqual(profile.rating_count, 18)
        self.assertEqual(profile.custom_price_per_session, Decimal("125000.00"))

    def test_schemas_validation(self):
        pricing_req = UpdatePricingRequest(custom_price_per_session=150000.0)
        self.assertEqual(pricing_req.custom_price_per_session, 150000.0)

        review_req = SubmitSessionReviewRequest(
            rating=4.8,
            label="Mendengarkan dengan Baik",
            review_text="Sangat membantu.",
            is_anonymous=False,
        )
        self.assertEqual(review_req.rating, 4.8)
        self.assertFalse(review_req.is_anonymous)


if __name__ == "__main__":
    unittest.main()
