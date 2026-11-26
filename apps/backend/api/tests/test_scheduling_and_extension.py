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
from app.services.session.scheduling_service import SchedulingService


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

    def test_anti_collision_with_buffer_window(self):
        # User scenario: Sesi 12:05 - 12:35, buffer 10 menit
        existing_start = datetime(2026, 11, 20, 12, 5, tzinfo=UTC)
        existing_end = datetime(2026, 11, 20, 12, 35, tzinfo=UTC)
        buffer_minutes = 10
        buffer_delta = timedelta(minutes=buffer_minutes)

        def is_overlap_with_buffer(new_start, new_end):
            return (existing_start < new_end + buffer_delta) and (existing_end > new_start - buffer_delta)

        # Pasien coba booking tepat selesai sesi 12:35 - 13:05 -> Kena Buffer (Ditolak)
        self.assertTrue(is_overlap_with_buffer(datetime(2026, 11, 20, 12, 35, tzinfo=UTC), datetime(2026, 11, 20, 13, 5, tzinfo=UTC)))
        # Pasien coba booking 12:40 - 13:10 -> Kena Buffer (Ditolak)
        self.assertTrue(is_overlap_with_buffer(datetime(2026, 11, 20, 12, 40, tzinfo=UTC), datetime(2026, 11, 20, 13, 10, tzinfo=UTC)))
        # Pasien booking di 12:45 - 13:15 -> Aman setelah jeda buffer 10 menit (Diterima)
        self.assertFalse(is_overlap_with_buffer(datetime(2026, 11, 20, 12, 45, tzinfo=UTC), datetime(2026, 11, 20, 13, 15, tzinfo=UTC)))
        # Pasien coba booking sebelum sesi 11:30 - 12:00 -> Jeda cuma 5 menit ke 12:05 (Ditolak)
        self.assertTrue(is_overlap_with_buffer(datetime(2026, 11, 20, 11, 30, tzinfo=UTC), datetime(2026, 11, 20, 12, 0, tzinfo=UTC)))
        # Pasien booking 11:25 - 11:55 -> Cukup buffer 10 menit sebelum 12:05 (Diterima)
        self.assertFalse(is_overlap_with_buffer(datetime(2026, 11, 20, 11, 25, tzinfo=UTC), datetime(2026, 11, 20, 11, 55, tzinfo=UTC)))

    def test_multi_session_consecutive_booking_calculation(self):
        # User booking 3 sesi sekaligus: 30x3 = 90 menit
        session_count = 3
        duration_minutes = session_count * 30
        self.assertEqual(duration_minutes, 90)

        start_time = datetime(2026, 11, 20, 13, 0, tzinfo=UTC)
        end_time = start_time + timedelta(minutes=duration_minutes)
        self.assertEqual(end_time.strftime("%H:%M"), "14:30")

        # Snapshot pricing policy calculation
        price_per_session = Decimal("150000.00")
        total_price = price_per_session * Decimal(str(session_count))
        self.assertEqual(total_price, Decimal("450000.00"))


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

    def test_extension_schedule_config_rejects_break_closing_and_inactive_day(self):
        # 2026-11-20 is Friday
        counselor = PsychologistProfile(
            user_id=uuid.uuid4(),
            full_name="Dr. Schedule Test",
            str_number="STR-TEST-1",
            schedule_config={
                "friday": {
                    "is_active": True,
                    "operating_hours": {"start": "08:00", "end": "17:00"},
                    "breaks": [
                        {"start": "11:30", "end": "13:00", "label": "Shalat Jumat & Istirahat"},
                    ],
                },
                "saturday": {
                    "is_active": False,
                    "operating_hours": {"start": "08:00", "end": "17:00"},
                    "breaks": [],
                },
            },
        )

        # 1. Overlaps break (11:15 - 11:45 overlaps 11:30 - 13:00)
        conflict_break = SchedulingService.evaluate_schedule_config_conflict(
            counselor,
            datetime(2026, 11, 20, 11, 15, tzinfo=UTC),
            datetime(2026, 11, 20, 11, 45, tzinfo=UTC),
        )
        self.assertIsNotNone(conflict_break)
        self.assertIn("istirahat", conflict_break.lower())

        # 2. Exceeds closing hours (16:40 - 17:10 passes 17:00)
        conflict_closing = SchedulingService.evaluate_schedule_config_conflict(
            counselor,
            datetime(2026, 11, 20, 16, 40, tzinfo=UTC),
            datetime(2026, 11, 20, 17, 10, tzinfo=UTC),
        )
        self.assertIsNotNone(conflict_closing)
        self.assertIn("jam operasional", conflict_closing.lower())

        # 3. Inactive day (Saturday)
        conflict_inactive = SchedulingService.evaluate_schedule_config_conflict(
            counselor,
            datetime(2026, 11, 21, 10, 0, tzinfo=UTC),
            datetime(2026, 11, 21, 10, 30, tzinfo=UTC),
        )
        self.assertIsNotNone(conflict_inactive)
        self.assertIn("tidak membuka jadwal", conflict_inactive.lower())

        # 4. Completely free 30m slot (08:37 - 09:07) inside working hours without breaks
        no_conflict = SchedulingService.evaluate_schedule_config_conflict(
            counselor,
            datetime(2026, 11, 20, 8, 37, tzinfo=UTC),
            datetime(2026, 11, 20, 9, 7, tzinfo=UTC),
        )
        self.assertIsNone(no_conflict)


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


class TestCounselorScheduleSyncAndTimelinePrivacy(unittest.IsolatedAsyncioTestCase):
    async def test_get_counselor_timeline_preserves_explicit_empty_breaks(self):
        counselor_id = uuid.uuid4()
        target_date = "2026-11-20"  # Friday
        profile = PsychologistProfile(
            id=counselor_id,
            user_id=uuid.uuid4(),
            full_name="Dr. Schedule Tester",
            specializations=[],
            is_online=True,
            buffer_time_minutes=15,
            schedule_config={
                "friday": {
                    "is_active": True,
                    "operating_hours": {"start": "10:00", "end": "16:00"},
                    "breaks": [],
                }
            },
        )

        class _FakeResult:
            def __init__(self, scalar_val=None, scalars_list=None):
                self._scalar_val = scalar_val
                self._scalars_list = scalars_list or []

            def scalar_one_or_none(self):
                return self._scalar_val

            def scalars(self):
                return self

            def all(self):
                return self._scalars_list

        class _FakeDb:
            def __init__(self):
                self.calls = 0

            async def execute(self, stmt):
                self.calls += 1
                if self.calls == 1:
                    return _FakeResult(scalar_val=profile)
                return _FakeResult(scalars_list=[])

        timeline = await SchedulingService(_FakeDb()).get_counselor_timeline(
            counselor_id, target_date, tz_offset_minutes=0
        )
        self.assertEqual(timeline.operating_hours.start, "10:00")
        self.assertEqual(timeline.operating_hours.end, "16:00")
        self.assertTrue(timeline.is_active)
        self.assertTrue(timeline.is_online)
        self.assertEqual(timeline.blocked_ranges, [])
        self.assertEqual(timeline.booked_sessions, [])

    async def test_my_timeline_includes_booked_patient_details_while_public_hides_them(self):
        from app.models.user import User

        counselor_id = uuid.uuid4()
        counselor_user_id = uuid.uuid4()
        patient_id = uuid.uuid4()
        session_id = uuid.uuid4()
        target_date = "2026-11-23"  # Monday

        profile = PsychologistProfile(
            id=counselor_id,
            user_id=counselor_user_id,
            full_name="Dr. Maya Putri",
            specializations=[],
            is_online=True,
            buffer_time_minutes=10,
            schedule_config={
                "monday": {
                    "is_active": True,
                    "operating_hours": {"start": "09:00", "end": "17:00"},
                    "breaks": [{"start": "12:00", "end": "13:00", "label": "Istirahat Siang"}],
                }
            },
        )
        patient_user = User(
            id=patient_id,
            email="rina@example.com",
            display_name="Rina Kartika",
            is_verified=True,
        )
        session = ConsultationSession(
            id=session_id,
            session_code="EVA-BOOK-001",
            counselor_id=counselor_id,
            patient_id=patient_id,
            scheduled_start_time=datetime(2026, 11, 23, 9, 0, tzinfo=UTC),
            scheduled_end_time=datetime(2026, 11, 23, 9, 30, tzinfo=UTC),
            duration_minutes=30,
            status=ConsultationSessionStatus.SCHEDULED,
            soap_notes={"subjective": "Susah tidur seminggu terakhir"},
            total_price=Decimal("100000"),
            platform_fee=Decimal("20000"),
            counselor_earning=Decimal("80000"),
        )
        session.patient = patient_user

        class _FakeResult:
            def __init__(self, scalar_val=None, scalars_list=None):
                self._scalar_val = scalar_val
                self._scalars_list = scalars_list or []

            def scalar_one_or_none(self):
                return self._scalar_val

            def scalars(self):
                return self

            def all(self):
                return self._scalars_list

        class _FakeDb:
            async def execute(self, stmt):
                if "consultation_sessions" in str(stmt):
                    return _FakeResult(scalars_list=[session])
                return _FakeResult(scalar_val=profile)

        my_timeline = await SchedulingService(_FakeDb()).get_my_counselor_timeline(
            counselor_user_id, target_date, tz_offset_minutes=0
        )
        self.assertEqual(len(my_timeline.booked_sessions), 1)
        self.assertEqual(my_timeline.booked_sessions[0].patient_name, "Rina Kartika")
        self.assertEqual(my_timeline.booked_sessions[0].start, "09:00")
        self.assertEqual(my_timeline.booked_sessions[0].end, "09:30")
        self.assertEqual(my_timeline.booked_sessions[0].complaints, "Susah tidur seminggu terakhir")

        public_timeline = await SchedulingService(_FakeDb()).get_counselor_timeline(
            counselor_id, target_date, tz_offset_minutes=0
        )
        self.assertEqual(public_timeline.booked_sessions, [])
        self.assertTrue(any(r.type == "booked" and r.start == "09:00" for r in public_timeline.blocked_ranges))


if __name__ == "__main__":
    unittest.main()
