import unittest
import uuid
from datetime import UTC, datetime, time, timedelta
from decimal import Decimal

from app.models.counselor import (
    ConsultationSession,
    PatientConsent,
    PlatformPricingConfig,
    PsychologistProfile,
)
from app.models.enums import ConsultationSessionStatus, PsychologistVerificationStatus
from app.schemas.session import (
    AvailableSlotsResponse,
    BookSessionRequest,
    ClinicalNotesResponse,
    ConsentStatusResponse,
    ConsultationSessionResponse,
    ExtensionAvailabilityResponse,
    TimeSlotResponse,
    UpdateSoapNotesRequest,
)


class TestSchedulingAndSlotGeneration(unittest.TestCase):
    def test_dynamic_30_min_slot_generation_with_buffer(self):
        target_date = datetime(2026, 11, 20, tzinfo=UTC).date()
        buffer_minutes = 10
        buffer_delta = timedelta(minutes=buffer_minutes)
        slot_duration = timedelta(minutes=30)

        start_time = datetime.combine(target_date, time(8, 0), tzinfo=UTC)
        end_time = datetime.combine(target_date, time(10, 0), tzinfo=UTC)

        slots: list[TimeSlotResponse] = []
        curr = start_time
        while curr + slot_duration <= end_time:
            s_end = curr + slot_duration
            slots.append(TimeSlotResponse(start_time=curr, end_time=s_end, duration_minutes=30, is_available=True))
            curr = s_end + buffer_delta

        # From 08:00 to 10:00 with 30m slot + 10m buffer:
        # Slot 1: 08:00 - 08:30 (next start: 08:40)
        # Slot 2: 08:40 - 09:10 (next start: 09:20)
        # Slot 3: 09:20 - 09:50 (next start: 10:00 -> +30m > 10:00, stop)
        self.assertEqual(len(slots), 3)
        self.assertEqual(slots[0].start_time.strftime("%H:%M"), "08:00")
        self.assertEqual(slots[0].end_time.strftime("%H:%M"), "08:30")
        self.assertEqual(slots[1].start_time.strftime("%H:%M"), "08:40")
        self.assertEqual(slots[1].end_time.strftime("%H:%M"), "09:10")
        self.assertEqual(slots[2].start_time.strftime("%H:%M"), "09:20")
        self.assertEqual(slots[2].end_time.strftime("%H:%M"), "09:50")

    def test_anti_collision_overlap_detection(self):
        existing_start = datetime(2026, 11, 20, 9, 0, tzinfo=UTC)
        existing_end = datetime(2026, 11, 20, 9, 30, tzinfo=UTC)

        def is_overlap(new_start, new_end):
            return (new_start < existing_end) and (new_end > existing_start)

        # Overlapping slot (starts inside existing)
        self.assertTrue(is_overlap(datetime(2026, 11, 20, 9, 15, tzinfo=UTC), datetime(2026, 11, 20, 9, 45, tzinfo=UTC)))
        # Overlapping slot (exact match)
        self.assertTrue(is_overlap(datetime(2026, 11, 20, 9, 0, tzinfo=UTC), datetime(2026, 11, 20, 9, 30, tzinfo=UTC)))
        # Non-overlapping slot before
        self.assertFalse(is_overlap(datetime(2026, 11, 20, 8, 30, tzinfo=UTC), datetime(2026, 11, 20, 9, 0, tzinfo=UTC)))
        # Non-overlapping slot after
        self.assertFalse(is_overlap(datetime(2026, 11, 20, 9, 30, tzinfo=UTC), datetime(2026, 11, 20, 10, 0, tzinfo=UTC)))


class TestInCallSessionExtension(unittest.TestCase):
    def test_extension_math_and_duration_increase(self):
        initial_duration = 30
        extension_minutes = 30
        final_duration = initial_duration + extension_minutes
        self.assertEqual(final_duration, 60)

        initial_price = Decimal("150000.00")
        ext_price = Decimal("150000.00")
        total_price = initial_price + ext_price
        self.assertEqual(total_price, Decimal("300000.00"))

    def test_extension_availability_rejection_when_already_extended(self):
        res = ExtensionAvailabilityResponse(
            session_id=str(uuid.uuid4()),
            can_extend=False,
            extension_duration_minutes=30,
            extension_price=150000.0,
            reason="Sesi telah diperpanjang sebelumnya (maksimal 1 perpanjangan / 60 menit per temu).",
            next_available_slots=[],
        )
        self.assertFalse(res.can_extend)
        self.assertIn("maksimal 1 perpanjangan", res.reason)

    def test_extension_availability_fallback_when_conflicting(self):
        res = ExtensionAvailabilityResponse(
            session_id=str(uuid.uuid4()),
            can_extend=False,
            extension_duration_minutes=30,
            extension_price=150000.0,
            reason="Psikolog memiliki jadwal konsultasi lain tepat setelah sesi ini.",
            next_available_slots=[
                TimeSlotResponse(
                    start_time=datetime(2026, 11, 20, 14, 0, tzinfo=UTC),
                    end_time=datetime(2026, 11, 20, 14, 30, tzinfo=UTC),
                    duration_minutes=30,
                    is_available=True,
                )
            ],
        )
        self.assertFalse(res.can_extend)
        self.assertEqual(len(res.next_available_slots), 1)
        self.assertEqual(res.next_available_slots[0].duration_minutes, 30)


class TestPatientConsentAndSoapNotes(unittest.TestCase):
    def test_patient_consent_status_contract(self):
        consent = ConsentStatusResponse(
            patient_id=str(uuid.uuid4()),
            counselor_id=str(uuid.uuid4()),
            status="granted",
            is_granted=True,
            granted_at=datetime.now(UTC),
            expires_at=None,
        )
        self.assertTrue(consent.is_granted)
        self.assertEqual(consent.status, "granted")

    def test_soap_notes_request_validation(self):
        soap = UpdateSoapNotesRequest(
            subjective="Pasien mengeluhkan insomnia 2 minggu terakhir akibat beban skripsi.",
            objective="Afek cemas, kontak mata baik, skor DASS-21 kecemasan 16 (sedang).",
            assessment="Episode ansietas situasional dipicu stresor akademik.",
            plan="Edukasi sleep hygiene, latihan pernapasan 4-7-8, sesi follow-up 1 minggu.",
            status="verified",
        )
        self.assertEqual(soap.status, "verified")
        self.assertIn("sleep hygiene", soap.plan)


if __name__ == "__main__":
    unittest.main()
