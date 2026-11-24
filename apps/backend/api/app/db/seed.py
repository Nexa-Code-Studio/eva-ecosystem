import asyncio
from datetime import date, datetime, timedelta, UTC
from decimal import Decimal
import logging
from sqlalchemy import func, select

from app.db.session import AsyncSessionLocal, engine
from app.core.security import hash_password
from app.core.tz import get_wib_today
from app.models.base import BaseModel
from app.models.certificate import CertificateTemplate, PsychologistCertificate
from app.models.coin import CoinEconomyConfig, CoinPackage
from app.models.content import CrisisConfig, FaqEntry
from app.models.counselor import (
    ConsultationSession,
    CounselorTransaction,
    PatientConsent,
    PlatformPricingConfig,
    PsychologistProfile,
)
from app.models.conversation import Conversation, Message
from app.models.diary import DiaryEntry
from app.models.coping_activity import CopingActivity, UserActivityCompletion
from app.models.enums import (
    ConsultationSessionStatus,
    ConversationStatus,
    MessageType,
    PricingConfigStatus,
    PsychologistVerificationStatus,
    TransactionStatus,
    TransactionType,
)
from app.models.level import CounselorReview, PsychologistLevel
from app.models.recommendation import RecommendationItem
from app.models.user import EmergencyContact, User

logger = logging.getLogger(__name__)


async def seed_master_data() -> User:
    """Seed comprehensive initial data for mobile app consumption."""
    logger.info("Initializing database tables...")
    async with engine.begin() as conn:
        await conn.run_sync(BaseModel.metadata.create_all)

    async with AsyncSessionLocal() as session:
        # 1. Seed Master User (Samsul)
        query_user = select(User).where(User.email == "samsul@gmail.com")
        res_user = await session.execute(query_user)
        user = res_user.scalar_one_or_none()

        # Check for legacy user.luna@gmail.com to migrate/update
        if not user:
            query_old = select(User).where(User.email == "user.luna@gmail.com")
            res_old = await session.execute(query_old)
            old_user = res_old.scalar_one_or_none()
            if old_user:
                user = old_user
                user.email = "samsul@gmail.com"
                user.username = "samsul"
                user.display_name = "Samsul"
                user.password_hash = hash_password("password123")
                await session.commit()
                await session.refresh(user)
                logger.info(f"Migrated existing user to Samsul: samsul@gmail.com ({user.id})")

        if not user:
            user = User(
                email="samsul@gmail.com",
                username="samsul",
                display_name="Samsul",
                password_hash=hash_password("password123"),
                is_active=True,
                is_verified=True,
                is_admin=False,
                coin_balance=300,
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)
            logger.info(f"Seeded Master User: samsul@gmail.com ({user.id})")
        else:
            user.display_name = "Samsul"
            user.username = "samsul"
            await session.commit()
            logger.info(f"Existing Master User updated: {user.email}")

        # 1b. Seed Default Admin Account (admin@eva.id)
        admin_email = "admin@eva.id"
        res_admin = await session.execute(select(User).where(User.email == admin_email))
        admin_user = res_admin.scalar_one_or_none()
        if not admin_user:
            admin_user = User(
                email=admin_email,
                username="admin",
                display_name="Administrator Pusat Ekosistem EVA",
                password_hash=hash_password("AdminEva2026!"),
                is_active=True,
                is_verified=True,
                is_admin=True,
                coin_balance=0,
            )
            session.add(admin_user)
            await session.commit()
            logger.info("Seeded Admin User: admin@eva.id")
        elif not admin_user.is_admin:
            admin_user.is_admin = True
            await session.commit()

        # 2. Seed Emergency Contacts (for Demo User)
        query_contacts = select(EmergencyContact).where(EmergencyContact.user_id == user.id)
        res_contacts = await session.execute(query_contacts)
        existing_contacts = res_contacts.scalars().all()

        if not existing_contacts:
            c1 = EmergencyContact(
                user_id=user.id,
                name="Ibu (Siti Rahma)",
                relationship="Ibu",
                phone_number="0812-3456-7890",
                is_primary=True,
            )
            c2 = EmergencyContact(
                user_id=user.id,
                name="Dr. Handoko (Psikiater)",
                relationship="Dokter",
                phone_number="0811-9876-5432",
                is_primary=False,
            )
            session.add_all([c1, c2])
            await session.commit()
            logger.info("Seeded Emergency Contacts for master user.")

        # 3. Seed Full Diary Entries History (for Demo User)
        today = get_wib_today()
        yesterday = today - timedelta(days=1)
        two_days_ago = today - timedelta(days=2)

        target_entries = [
            {
                "entry_date": today,
                "title": "Jurnal Refleksi Hari Ini",
                "summary": "Samsul merasa lebih semangat dan positif setelah berdiskusi mengenai target pribadi dan afirmasi pagi bersama EVA.",
                "content": "Catatan harian mengenai target positif dan meditasi.",
                "mood_tag": "Bahagia 😃",
                "mood_emoji": "😃",
                "emotional_level": 5,
                "ai_insight": "Progres emosional Samsul menunjukkan peningkatan kebahagiaan dan motivasi positif.",
                "emotional_reflection": "Merasa optimis menghadapi tantangan hari ini.",
                "important_events": ["[Sesi #1] Afirmasi positif pagi dan perencanaan aktivitas produktif."],
                "mental_health_scores": {"depression": 0.15, "anxiety": 0.20, "stress": 0.10},
            },
            {
                "entry_date": yesterday,
                "title": "Catatan Refleksi Emosi Harian",
                "summary": "Samsul merasakan ketenangan setelah menyelesaikan sesi konsultasi mengenai manajemen waktu dan relaksasi pikiran.",
                "content": "Diskusi relaksasi emosional.",
                "mood_tag": "Tenang 😌",
                "mood_emoji": "😌",
                "emotional_level": 4,
                "ai_insight": "Kondisi emosional Samsul tergolong stabil dan terjaga.",
                "emotional_reflection": "Merasa lebih lega dan siap melanjutkan aktivitas esok hari.",
                "important_events": ["[Sesi #1] Refleksi mengenai rutinitas harian dan teknik olah napas."],
                "mental_health_scores": {"depression": 0.25, "anxiety": 0.35, "stress": 0.20},
            },
            {
                "entry_date": two_days_ago,
                "title": "Diskusi Beban Kerja & Stres",
                "summary": "Samsul mengutarakan rasa kecemasan dan kelelahan mental terkait beban kerja dan tenggat waktu tugas.",
                "content": "Sesi konseling mengindikasikan kecemasan mendalam terhadap evaluasi pekerjaan.",
                "mood_tag": "Cemas 😰",
                "mood_emoji": "😰",
                "emotional_level": 2,
                "ai_insight": "Teridentifikasi stres situasional akibat beban kognitif kerja. Disarankan istirahat teratur.",
                "emotional_reflection": "Merasa lebih tenang setelah mencurahkan kekhawatiran.",
                "important_events": [
                    "[Sesi #1] Samsul menyampaikan keluhan kelelahan fisik dan kecemasan pekerjaan.",
                    "[Sesi #2] Diskusi teknik grounding 5-4-3-2-1 bersama EVA.",
                ],
                "mental_health_scores": {"depression": 0.35, "anxiety": 0.65, "stress": 0.55},
            },
        ]

        for entry_data in target_entries:
            query_d = select(DiaryEntry).where(
                DiaryEntry.user_id == user.id,
                DiaryEntry.entry_date == entry_data["entry_date"],
            )
            res_d = await session.execute(query_d)
            existing_d = res_d.scalar_one_or_none()

            if not existing_d:
                new_d = DiaryEntry(user_id=user.id, **entry_data)
                session.add(new_d)
                await session.commit()
                logger.info(f"Seeded Diary Entry for date {entry_data['entry_date']}: {entry_data['title']}")

        # 4. Seed Recommendations
        query_recs = select(RecommendationItem)
        res_recs = await session.execute(query_recs)
        existing_recs = res_recs.scalars().all()

        if not existing_recs:
            r1 = RecommendationItem(
                user_id=user.id,
                title="Latihan Pernapasan 4-7-8",
                category="Mindfulness",
                duration="5 Menit",
                level="Pemula",
                description="Teknik pernapasan sederhana untuk menenangkan sistem saraf.",
                icon_name="air",
                is_completed=False,
            )
            r2 = RecommendationItem(
                user_id=user.id,
                title="Jurnal Ekspresif Malam",
                category="Refleksi",
                duration="10 Menit",
                level="Pemula",
                description="Tuliskan 3 hal yang kamu syukuri sebelum tidur.",
                icon_name="edit_note",
                is_completed=False,
            )
            r3 = RecommendationItem(
                user_id=user.id,
                title="Jeda Digital 15 Menit",
                category="Self-care",
                duration="15 Menit",
                level="Menengah",
                description="Matikan notifikasi dan istirahatkan mata dari layar HP.",
                icon_name="phonelink_off",
                is_completed=True,
            )
            session.add_all([r1, r2, r3])
            await session.commit()
            logger.info("Seeded Recommendations.")

        # 4b. Seed Evidence-Based Coping Activities (Condition-Specific)
        query_coping = select(CopingActivity)
        res_coping = await session.execute(query_coping)
        existing_coping = res_coping.scalars().all()

        if not existing_coping:
            c1 = CopingActivity(
                title="Teknik Grounding 5-4-3-2-1",
                category="CBT Somatis",
                target_condition="anxiety",
                duration="5 Menit",
                difficulty="Pemula",
                description="Mengaktifkan panca indra untuk memutus siklus kecemasan dan membawa kesadaran kembali ke saat ini.",
                instructions=[
                    "Perhatikan 5 benda yang bisa kamu lihat di sekitarmu.",
                    "Rasakan 4 hal yang bisa kamu sentuh atau rasakan fisiknya.",
                    "Dengarkan 3 suara berbeda di lingkunganmu.",
                    "Kenali 2 aroma yang tercium saat ini.",
                    "Rasakan 1 cita rasa di lidahmu.",
                ],
                rationale="Membantu menstabilkan amigdala yang hiperaktif dan mengalihkan fokus dari pikiran katastrofik ke realitas sensorik.",
                icon_name="accessibility_new",
                is_active=True,
            )
            c2 = CopingActivity(
                title="Box Breathing (Pernapasan Kotak)",
                category="Mindfulness",
                target_condition="anxiety",
                duration="4 Menit",
                difficulty="Pemula",
                description="Latihan pernapasan berirama 4 detik untuk meredakan denyut jantung dan kepanikan.",
                instructions=[
                    "Tarik napas perlahan melalui hidung selama 4 detik.",
                    "Tahan napasmu selama 4 detik dengan tenang.",
                    "Hembuskan napas perlahan melalui mulut selama 4 detik.",
                    "Tahan ruang kosong di paru-parumu selama 4 detik.",
                    "Ulangi siklus ini sebanyak 4 hingga 6 kali.",
                ],
                rationale="Menyeimbangkan sistem saraf otonom dan menurunkan kadar hormon stres secara instan.",
                icon_name="air",
                is_active=True,
            )
            c3 = CopingActivity(
                title="Latihan Pernapasan 4-7-8",
                category="Mindfulness",
                target_condition="stress",
                duration="5 Menit",
                difficulty="Pemula",
                description="Teknik pernapasan relaksasi mendalam untuk mengaktifkan sistem saraf parasimpatik.",
                instructions=[
                    "Buang napas sepenuhnya melalui mulut.",
                    "Tarik napas tenang lewat hidung dalam 4 detik.",
                    "Tahan napasmu selama 7 detik.",
                    "Hembuskan kuat-kuat melalui mulut dalam 8 detik.",
                    "Ulangi hingga 4 siklus pernapasan.",
                ],
                rationale="Memperlambat detak jantung dan meredakan ketegangan otot akibat stres kronis.",
                icon_name="spa",
                is_active=True,
            )
            c4 = CopingActivity(
                title="Progressive Muscle Relaxation (PMR)",
                category="Somatis",
                target_condition="stress",
                duration="7 Menit",
                difficulty="Menengah",
                description="Menegangkan dan melemaskan kelompok otot secara bergantian untuk melepaskan beban somatis.",
                instructions=[
                    "Duduk atau berbaringlah dengan nyaman.",
                    "Kepalkan kedua tangan kuat-kuat selama 5 detik, lalu lepaskan seketika.",
                    "Tarik bahu ke arah telinga selama 5 detik, lalu lepaskan dan rasakan kelegaannya.",
                    "Kencangkan otot betis dan kaki selama 5 detik, lalu rilekskan.",
                    "Rasakan perbedaan antara rasa tegang dan rasa rileks.",
                ],
                rationale="Memecah akumulasi ketegangan fisik somatis yang sering tidak disadari oleh tubuh.",
                icon_name="self_improvement",
                is_active=True,
            )
            c5 = CopingActivity(
                title="Aktivasi Perilaku: Jalan Pagi 10 Menit",
                category="Aktivasi Perilaku",
                target_condition="depression",
                duration="10 Menit",
                difficulty="Pemula",
                description="Aktivitas fisik ringan untuk merangsang produksi dopamin dan endorfin secara alami.",
                instructions=[
                    "Kenakan pakaian santai dan sepatu yang nyaman.",
                    "Berjalanlah santai di luar ruangan atau sekitar rumah selama 10 menit.",
                    "Biarkan sinar matahari pagi menyentuh kulitmu.",
                    "Tidak perlu terburu-buru, nikmati setiap langkahmu.",
                ],
                rationale="Mengatasi kelembaman (inertia) dan anhedonia dengan memicu pelepasan neurotransmiter penstabil suasana hati.",
                icon_name="directions_walk",
                is_active=True,
            )
            c6 = CopingActivity(
                title="Catatan Tiga Hal Syukur (Gratitude)",
                category="Refleksi Kognitif",
                target_condition="depression",
                duration="5 Menit",
                difficulty="Pemula",
                description="Menuliskan 3 hal kecil yang bermakna untuk mengimbangi bias negatif kognitif.",
                instructions=[
                    "Ambil buku catatan atau buka aplikasi Eva.",
                    "Pikirkan 3 hal kecil yang memberi kenyamanan hari ini.",
                    "Tuliskan mengapa hal tersebut membuatmu merasa bersyukur.",
                    "Resapi perasaan hangat yang muncul di hatimu.",
                ],
                rationale="Membiasakan otak melatih perhatian selektif terhadap aspek positif kehidupan.",
                icon_name="edit_note",
                is_active=True,
            )
            c7 = CopingActivity(
                title="Jeda Digital & Istirahat Mata",
                category="Self-care",
                target_condition="general",
                duration="15 Menit",
                difficulty="Pemula",
                description="Menjauh sejenak dari layar gadget untuk memulihkan kelelahan sensorik mental.",
                instructions=[
                    "Matikan layar ponsel dan laptopmu.",
                    "Tatap pemandangan jauh atau tanaman hijau selama beberapa saat.",
                    "Minum segelas air putih dengan perlahan dan sadar.",
                    "Regangkan otot leher dan punggungmu.",
                ],
                rationale="Meredakan kelelahan sensorik visual dan kognitif akibat paparan informasi berlebih.",
                icon_name="phonelink_off",
                is_active=True,
            )
            c8 = CopingActivity(
                title="Mindful Body Scan Singkat",
                category="Mindfulness",
                target_condition="general",
                duration="5 Menit",
                difficulty="Pemula",
                description="Memeriksa kondisi tubuh dari kepala hingga kaki dengan penuh penerimaan.",
                instructions=[
                    "Duduk tegak namun rileks, pejamkan matamu.",
                    "Arahkan perhatianmu ke puncak kepala, dahi, hingga rahang.",
                    "Turunkan perhatian ke bahu, dada, perut, dan punggung.",
                    "Lanjutkan hingga ujung jari kaki.",
                    "Sambut sensasi apa pun tanpa menghakimi.",
                ],
                rationale="Meningkatkan kesadaran interoseptif (hubungan tubuh dan pikiran) untuk menjaga kestabilan emosi.",
                icon_name="psychology",
                is_active=True,
            )
            c9 = CopingActivity(
                title="Metode Notice and Name (Unhooking)",
                category="CBT Kognitif",
                target_condition="anxiety",
                duration="5 Menit",
                difficulty="Pemula",
                description="Melepaskan diri dari jebakan pikiran overthinking dan kecemasan dengan formula sadar, beri label, dan fokus kembali.",
                instructions=[
                    "Sadari (Notice): Perhatikan pikiran cemas yang sedang berputar di kepalamu tanpa melawannya.",
                    "Beri Nama (Name): Ucapkan dalam hati: 'Saya menyadari di sini ada pikiran bahwa [sebutkan pikiranmu]'.",
                    "Fokus Kembali (Refocus): Arahkan kembali perhatian fisikmu pada apa yang sedang kamu kerjakan saat ini.",
                ],
                rationale="Berdasarkan panduan klinis WHO (Doing What Matters in Times of Stress, Modul 2), teknik unhooking mencegah pikiran cemas mengendalikan tindakan kita.",
                icon_name="psychology",
                is_active=True,
            )
            c10 = CopingActivity(
                title="Metode Stop, Think, Go (Solusi Bertahap)",
                category="Problem Solving",
                target_condition="stress",
                duration="8 Menit",
                difficulty="Menengah",
                description="Mengurai rasa kewalahan akibat tumpukan masalah menjadi langkah-langkah solusi praktis yang terukur.",
                instructions=[
                    "STOP: Berhentilah sejenak dari kesibukan. Tarik napas panjang dan pilih satu masalah yang paling mendesak.",
                    "THINK: Tuliskan minimal 3 hingga 5 kemungkinan ide solusi, tanpa menghakimi apakah ide tersebut konyol atau tidak.",
                    "GO: Pilih satu ide yang paling mudah dan dapat kamu jalankan sekarang juga. Lakukan langkah pertama.",
                ],
                rationale="Berdasarkan panduan WHO EASE (Aktivitas 5.4), metode ini memulihkan fungsi eksekutif kognitif yang terhambat saat stres tinggi.",
                icon_name="task_alt",
                is_active=True,
            )
            c11 = CopingActivity(
                title="Stabilisasi Krisis & Grounding Darurat",
                category="Bantuan Krisis",
                target_condition="crisis",
                duration="3 Menit",
                difficulty="Darurat",
                description="Langkah stabilisasi sensorik segera saat emosi terasa sangat meluap atau muncul pemikiran menyakiti diri.",
                instructions=[
                    "Hentikan aktivitasmu saat ini dan duduklah bersandar dengan aman di kursi atau lantai.",
                    "Tekan kedua telapak kakimu kuat-kuat ke lantai, rasakan bumi menopang tubuhmu.",
                    "Pegang benda bersuhu dingin (seperti air es atau batu) untuk memutus badai impuls emosional.",
                    "Tolong hubungi Hotline Kemenkes di 119 ext 8 atau kontak terdekatmu sekarang juga.",
                ],
                rationale="Berdasarkan standar rujukan WHO EASE (Tabel 5), grounding sensorik fisik menstabilkan kesadaran sebelum intervensi profesional diberikan.",
                icon_name="emergency",
                is_active=True,
            )
            session.add_all([c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11])
            await session.commit()
            logger.info("Seeded Evidence-Based Coping Activities (including crisis, anxiety unhooking, and problem solving).")

        # 5. Conversations & Messages (Skipped: Start with 0 conversations for clean user state)
        logger.info("Skipping conversation seeding for 100% clean conversation history.")

        # 6. Seed Psychologist & Counselor Master Data
        await seed_counselor_master_data(session, user)

        # 7. Seed Coin Economy Config & Initial Packages (only if empty)
        econ_count = await session.scalar(select(func.count(CoinEconomyConfig.id)))
        if (econ_count or 0) == 0:
            session.add(
                CoinEconomyConfig(
                    base_price_per_coin_idr=1000,
                    free_trial_coins_new_user=10,
                )
            )
            await session.commit()
            logger.info("Seeded default CoinEconomyConfig.")

        pkg_count = await session.scalar(select(func.count(CoinPackage.id)))
        if (pkg_count or 0) == 0:
            session.add_all(
                [
                    CoinPackage(
                        code="COIN-15",
                        name="Paket Sesi Singkat",
                        coins=15,
                        bonus_coins=0,
                        price_idr=15000,
                        description="15 menit berbicara intensif bersama EVA (Rp1.000/menit).",
                        is_popular=False,
                        is_active=True,
                    ),
                    CoinPackage(
                        code="COIN-35",
                        name="Paket Reguler Tenang",
                        coins=30,
                        bonus_coins=5,
                        price_idr=30000,
                        description="Total 35 menit sesi suara (30 koin pokok + 5 koin bonus gratis).",
                        is_popular=True,
                        is_active=True,
                    ),
                    CoinPackage(
                        code="COIN-120",
                        name="Paket Pendamping Bulanan",
                        coins=100,
                        bonus_coins=20,
                        price_idr=90000,
                        description="Total 120 menit sesi suara dengan potongan paket hemat Rp30.000.",
                        is_popular=False,
                        is_active=True,
                    ),
                    CoinPackage(
                        code="COIN-310",
                        name="Paket Intensif Semester",
                        coins=250,
                        bonus_coins=60,
                        price_idr=210000,
                        description="Total 310 menit pendampingan suara jangka panjang untuk mahasiswa.",
                        is_popular=False,
                        is_active=True,
                    ),
                ]
            )
            await session.commit()
            logger.info("Seeded initial 4 CoinPackage catalog items.")

        # 8. Seed SafetyNet Crisis Config & Website FAQs (only if empty)
        crisis_count = await session.scalar(select(func.count(CrisisConfig.id)))
        if (crisis_count or 0) == 0:
            session.add(
                CrisisConfig(
                    hotline_number="119 EXT 8",
                    hotline_label="Layanan Darurat Kemenkes RI",
                    extreme_depression_threshold=28,
                    extreme_anxiety_threshold=20,
                    auto_safety_net_modal=True,
                    allow_direct_independent_referral=True,
                )
            )
            await session.commit()
            logger.info("Seeded default CrisisConfig.")

        faq_count = await session.scalar(select(func.count(FaqEntry.id)))
        if (faq_count or 0) == 0:
            session.add_all(
                [
                    FaqEntry(
                        category="PRIVASI & KEAMANAN",
                        question="Apakah rekaman suara dan isi curhat saya benar-benar aman?",
                        answer="Ya, 100% privat. EVA menerapkan arsitektur On-Device Data Sovereignty: catatan refleksi dan riwayat percakapanmu dienkripsi langsung di perangkatmu, tidak dijual ke pihak ketiga, dan tidak digunakan untuk melatih model iklan publik.",
                        is_published=True,
                        sort_order=1,
                    ),
                    FaqEntry(
                        category="BIAYA & EVA COIN",
                        question="Bagaimana sistem biaya dan penggunaan Koin di aplikasi EVA?",
                        answer="Fitur Misi Koping Harian, Diari Otomatis, dan Skrining DASS-21 dapat diakses gratis. Untuk seluruh layanan berbayar EVA — baik Curhat Suara AI 24/7 (1 Koin = 1 menit berbicara) maupun telekonsultasi psikolog profesional (tarif Koin per sesi 30 menit) — EVA menggunakan mata uang terpadu EVA Coin (kurs dasar Rp1.000/Koin dengan pilihan paket top-up hemat). Setiap pengguna baru otomatis mendapatkan bonus 10 Koin gratis.",
                        is_published=True,
                        sort_order=2,
                    ),
                    FaqEntry(
                        category="BATAS KLINIS",
                        question="Apakah EVA menggantikan peran psikolog atau psikiater?",
                        answer="Tidak. EVA adalah pendamping pertolongan pertama emosional (digital first-aid) yang disupervisi oleh psikolog klinis (HIMPSI) dan bersifat non-diagnostik. Jika hasil skrining DASS-21 menunjukkan perlunya pendampingan lanjutan, EVA justru membantumu terhubung ke psikolog profesional.",
                        is_published=True,
                        sort_order=3,
                    ),
                    FaqEntry(
                        category="PROTOKOL DARURAT",
                        question="Apa yang terjadi jika saya berada dalam kondisi krisis darurat?",
                        answer="EVA dilengkapi protokol keselamatan 24/7 SafetyNet berstandar WHO. Ketika terdeteksi indikasi krisis atau bahaya diri, EVA segera menghentikan percakapan biasa dan menyediakan akses satu sentuhan ke layanan darurat bebas pulsa Kemenkes (119 Ext 8) serta kontak orang kepercayaanmu.",
                        is_published=True,
                        sort_order=4,
                    ),
                    FaqEntry(
                        category="KETERSEDIAAN PERANGKAT",
                        question="Di perangkat apa saja saya bisa mengunduh EVA?",
                        answer="Saat ini versi Beta (APK) dapat langsung kamu unduh dan pasang untuk perangkat Android melalui tombol unduh di halaman ini. Versi iOS sedang dalam tahap pengujian akhir.",
                        is_published=True,
                        sort_order=5,
                    ),
                ]
            )
            await session.commit()
            logger.info("Seeded initial 5 website FAQ entries.")

        return user


async def seed_counselor_master_data(session: AsyncSessionLocal, patient_user: User) -> PsychologistProfile:
    """Seed certified professional psychologist, platform pricing, and realistic consultation history."""
    # 1. Platform Pricing Config
    query_pricing = select(PlatformPricingConfig).where(
        PlatformPricingConfig.status == PricingConfigStatus.ACTIVE.value
    )
    res_pricing = await session.execute(query_pricing)
    pricing = res_pricing.scalars().first()
    if not pricing:
        pricing = PlatformPricingConfig(
            session_duration_minutes=30,
            price_per_session=Decimal("150.00"),
            counselor_share_percentage=Decimal("80.00"),
            platform_fee_percentage=Decimal("20.00"),
            extension_price_per_session=Decimal("150.00"),
            status=PricingConfigStatus.ACTIVE.value,
        )
        session.add(pricing)
        await session.commit()
        await session.refresh(pricing)
        logger.info("Seeded Platform Pricing Config.")

    # 2. Seed Psychologist User Account
    counselor_email = "khoirotunnisa2507@gmail.com"
    query_c_user = select(User).where(User.email == counselor_email)
    res_c_user = await session.execute(query_c_user)
    counselor_user = res_c_user.scalar_one_or_none()

    if not counselor_user:
        # Check if legacy demo counselor email exists and migrate to user's real email
        old_user_query = select(User).where(User.email == "psikolog.mandiri@eva.id")
        old_res = await session.execute(old_user_query)
        old_user = old_res.scalar_one_or_none()
        if old_user:
            counselor_user = old_user
            counselor_user.email = counselor_email
            counselor_user.display_name = "dr. Sarah Amelia, M.Psi., Psikolog"
            counselor_user.password_hash = hash_password("password123")
            await session.commit()
            logger.info(f"Migrated legacy demo counselor email to {counselor_email}")
        else:
            counselor_user = User(
                email=counselor_email,
                username="dr_sarah_amelia",
                display_name="dr. Sarah Amelia, M.Psi., Psikolog",
                password_hash=hash_password("password123"),
                is_active=True,
                is_verified=True,
            )
            session.add(counselor_user)
            await session.commit()
            await session.refresh(counselor_user)
            logger.info(f"Seeded Counselor User: {counselor_email}")
    else:
        counselor_user.display_name = "dr. Sarah Amelia, M.Psi., Psikolog"
        counselor_user.password_hash = hash_password("password123")
        await session.commit()

    # 3. Seed PsychologistProfile
    query_prof = select(PsychologistProfile).where(PsychologistProfile.user_id == counselor_user.id)
    res_prof = await session.execute(query_prof)
    profile = res_prof.scalar_one_or_none()

    if not profile:
        profile = PsychologistProfile(
            user_id=counselor_user.id,
            full_name="dr. Sarah Amelia, M.Psi., Psikolog",
            title_degree="M.Psi., Psikolog Klinis",
            education="S2 Magister Psikologi Profesi (Psikolog Klinis)",
            str_number="STR-PSI-19940822-2024",
            str_issuing_institution="Kemenkes RI / KTKI",
            str_expiry_date="Seumur Hidup (UU Kesehatan No. 17/2023)",
            str_verified=True,
            sip_number="SIP-PK-2024-0089",
            sip_issuing_institution="Dinas Kesehatan Provinsi DKI Jakarta",
            sip_expiry_date="2029-08-22",
            sip_verified=True,
            association="Himpunan Psikologi Indonesia (HIMPSI)",
            specializations=["Anxiety & Stress", "Trauma & PTSD", "Depression", "Family & Relationship"],
            years_of_experience=7,
            verification_status=PsychologistVerificationStatus.VERIFIED.value,
            is_online=True,
            bio="Psikolog klinis spesialis regulasi emosi, trauma, dan manajemen kecemasan.",
            bank_name="BCA",
            bank_account_number="8830192831",
            bank_account_holder="dr. Sarah Amelia",
            wallet_balance=Decimal("360000.00"),
        )
        session.add(profile)
        await session.commit()
        await session.refresh(profile)
        logger.info("Seeded Verified Psychologist Profile.")
    else:
        profile.verification_status = PsychologistVerificationStatus.VERIFIED.value
        profile.education = profile.education or "S2 Magister Psikologi Profesi (Psikolog Klinis)"
        profile.str_issuing_institution = profile.str_issuing_institution or "Kemenkes RI / KTKI"
        profile.str_expiry_date = profile.str_expiry_date or "Seumur Hidup (UU Kesehatan No. 17/2023)"
        profile.str_verified = True
        profile.sip_issuing_institution = profile.sip_issuing_institution or "Dinas Kesehatan Provinsi DKI Jakarta"
        profile.sip_expiry_date = profile.sip_expiry_date or "2029-08-22"
        profile.sip_verified = True
        profile.wallet_balance = Decimal("360000.00")
        profile.is_online = True
        await session.commit()

    # 3b. Seed 1 Sample Pending Psychologist Applicant for Admin Portal Verification Queue
    pending_email = "larasati.psi@praktikmandiri.id"
    res_pending = await session.execute(select(User).where(User.email == pending_email))
    pending_user = res_pending.scalar_one_or_none()
    if not pending_user:
        pending_user = User(
            email=pending_email,
            username="larasati_psi",
            display_name="Larasati Kusumawardhani",
            password_hash=hash_password("password123"),
            is_active=True,
            is_verified=False,
        )
        session.add(pending_user)
        await session.flush()

        pending_profile = PsychologistProfile(
            user_id=pending_user.id,
            full_name="Larasati Kusumawardhani",
            title_degree="M.Psi., Psikolog",
            education="S2 Magister Psikologi Profesi (Psikolog Klinis)",
            str_number="STR-PK-2022-884120",
            str_issuing_institution="Kemenkes RI / KTKI (Konsil Tenaga Kesehatan Indonesia)",
            str_expiry_date="Seumur Hidup (UU Kesehatan No. 17/2023)",
            str_verified=False,
            sip_number="20220618-2027-01-1402",
            sip_issuing_institution="Dinas Kesehatan Kabupaten / Kota",
            sip_expiry_date="2027-06-18",
            sip_verified=False,
            association="Himpunan Psikologi Indonesia (HIMPSI)",
            specializations=["Kecemasan Dewasa", "Trauma & Regulasi Emosi", "Quarter-life Crisis"],
            years_of_experience=5,
            verification_status=PsychologistVerificationStatus.PENDING.value,
            is_online=False,
            bio="Psikolog klinis dewasa yang berfokus pada kecemasan, regulasi emosi, dan quarter-life crisis.",
        )
        session.add(pending_profile)
        await session.commit()
        logger.info("Seeded Pending Psychologist Applicant: larasati.psi@praktikmandiri.id")

    # 4. Patient Consent
    query_consent = select(PatientConsent).where(
        PatientConsent.patient_id == patient_user.id,
        PatientConsent.counselor_id == profile.id,
    )
    res_consent = await session.execute(query_consent)
    existing_consent = res_consent.scalar_one_or_none()
    if not existing_consent:
        consent = PatientConsent(
            patient_id=patient_user.id,
            counselor_id=profile.id,
            status="granted",
            granted_at=datetime.now(UTC),
        )
        session.add(consent)
        await session.commit()
        logger.info("Seeded Patient Consent between Samsul & Sarah Amelia.")
    else:
        existing_consent.status = "granted"
        existing_consent.granted_at = datetime.now(UTC)
        await session.commit()
        logger.info("Ensured Patient Consent status is granted for Samsul.")

    # 5. Consultation Sessions & SOAP Notes
    query_sess = select(ConsultationSession).where(
        ConsultationSession.counselor_id == profile.id,
        ConsultationSession.patient_id == patient_user.id,
    )
    res_sess = await session.execute(query_sess)
    existing_sessions = res_sess.scalars().all()

    if not existing_sessions:
        now = datetime.now(UTC)
        past_session = ConsultationSession(
            session_code="EVA-20261120-001",
            patient_id=patient_user.id,
            counselor_id=profile.id,
            pricing_config_id=pricing.id if pricing else None,
            scheduled_start_time=now - timedelta(hours=3),
            scheduled_end_time=now - timedelta(hours=2, minutes=30),
            actual_start_time=now - timedelta(hours=3),
            actual_end_time=now - timedelta(hours=2, minutes=30),
            duration_minutes=30,
            status=ConsultationSessionStatus.COMPLETED.value,
            total_price=Decimal("150.00"),
            counselor_earning=Decimal("120.00"),
            platform_fee=Decimal("30.00"),
            soap_notes={
                "subjective": "Pasien merasa cemas dan kesulitan tidur karena beban pekerjaan meningkat.",
                "objective": "Kontak mata baik, respon afektif cemas ringan, skor DASS kecemasan sedang.",
                "assessment": "Mild Generalized Anxiety Disorder yang dipicu oleh stres lingkungan kerja.",
                "plan": "Latihan pernapasan 4-7-8, pembatasan kafein setelah jam 4 sore, dan evaluasi dalam 1 minggu.",
                "recommended_tasks": ["Latihan napas 4-7-8 pagi & malam", "Jurnal pemicu kecemasan harian"],
            },
        )
        upcoming_session = ConsultationSession(
            session_code="EVA-20261120-002",
            patient_id=patient_user.id,
            counselor_id=profile.id,
            pricing_config_id=pricing.id if pricing else None,
            scheduled_start_time=now + timedelta(hours=3),
            scheduled_end_time=now + timedelta(hours=3, minutes=30),
            duration_minutes=30,
            status=ConsultationSessionStatus.SCHEDULED.value,
            total_price=Decimal("150.00"),
            counselor_earning=Decimal("120.00"),
            platform_fee=Decimal("30.00"),
        )
        extended_session = ConsultationSession(
            session_code="EVA-20261120-003",
            patient_id=patient_user.id,
            counselor_id=profile.id,
            pricing_config_id=pricing.id if pricing else None,
            scheduled_start_time=now - timedelta(days=1, hours=2),
            scheduled_end_time=now - timedelta(days=1, hours=1),
            actual_start_time=now - timedelta(days=1, hours=2),
            actual_end_time=now - timedelta(days=1, hours=1),
            duration_minutes=60,
            is_extended=True,
            extension_requested_at=now - timedelta(days=1, hours=1, minutes=35),
            extension_granted_at=now - timedelta(days=1, hours=1, minutes=35),
            status=ConsultationSessionStatus.COMPLETED.value,
            total_price=Decimal("300.00"),
            counselor_earning=Decimal("240.00"),
            platform_fee=Decimal("60.00"),
        )
        session.add_all([past_session, upcoming_session, extended_session])
        await session.commit()
        await session.refresh(past_session)
        logger.info("Seeded Consultation Sessions (Completed, Scheduled, and Extended 60m).")

        # 6. Counselor Transactions
        tx1 = CounselorTransaction(
            counselor_id=profile.id,
            session_id=past_session.id,
            transaction_type=TransactionType.EARNING.value,
            status=TransactionStatus.COMPLETED.value,
            amount=Decimal("120000.00"),
            description="Honorarium Sesi Konsultasi #EVA-20261120-001 (Samsul)",
            reference_number="TX-20261118-001",
        )
        tx2 = CounselorTransaction(
            counselor_id=profile.id,
            session_id=None,
            transaction_type=TransactionType.EARNING.value,
            status=TransactionStatus.COMPLETED.value,
            amount=Decimal("120000.00"),
            description="Honorarium Sesi Konsultasi Sebelumnya",
            reference_number="TX-20261115-002",
        )
        tx3 = CounselorTransaction(
            counselor_id=profile.id,
            session_id=None,
            transaction_type=TransactionType.EARNING.value,
            status=TransactionStatus.COMPLETED.value,
            amount=Decimal("120000.00"),
            description="Honorarium Sesi Konseling Kelompok",
            reference_number="TX-20261110-003",
        )
        session.add_all([tx1, tx2, tx3])
        await session.commit()
        logger.info("Seeded Counselor Transactions.")
    else:
        now = datetime.now(UTC)
        has_extended_sample = any(s.session_code == "EVA-20261120-003" for s in existing_sessions)
        for s in existing_sessions:
            if s.session_code == "EVA-20261120-001":
                s.scheduled_start_time = now - timedelta(hours=3)
                s.scheduled_end_time = now - timedelta(hours=2, minutes=30)
                s.actual_start_time = now - timedelta(hours=3)
                s.actual_end_time = now - timedelta(hours=2, minutes=30)
            if s.total_price > Decimal("1000.00"):
                s.total_price = Decimal("300.00") if s.is_extended else Decimal("150.00")
                s.counselor_earning = Decimal("240.00") if s.is_extended else Decimal("120.00")
                s.platform_fee = Decimal("60.00") if s.is_extended else Decimal("30.00")
        if not has_extended_sample:
            session.add(
                ConsultationSession(
                    session_code="EVA-20261120-003",
                    patient_id=patient_user.id,
                    counselor_id=profile.id,
                    pricing_config_id=pricing.id if pricing else None,
                    scheduled_start_time=now - timedelta(days=1, hours=2),
                    scheduled_end_time=now - timedelta(days=1, hours=1),
                    actual_start_time=now - timedelta(days=1, hours=2),
                    actual_end_time=now - timedelta(days=1, hours=1),
                    duration_minutes=60,
                    is_extended=True,
                    extension_requested_at=now - timedelta(days=1, hours=1, minutes=35),
                    extension_granted_at=now - timedelta(days=1, hours=1, minutes=35),
                    status=ConsultationSessionStatus.COMPLETED.value,
                    total_price=Decimal("300.00"),
                    counselor_earning=Decimal("240.00"),
                    platform_fee=Decimal("60.00"),
                    patient_rating=Decimal("4.95"),
                )
            )
        for s in existing_sessions:
            if s.status == ConsultationSessionStatus.COMPLETED.value and s.patient_rating is None:
                s.patient_rating = Decimal("4.95")
        await session.commit()
        logger.info("Updated existing sessions and ensured extended 60m sample.")

    # 7. Seed Default Certificate Templates & Initial Issued Certificate (only if empty)
    tpl_count = await session.scalar(select(func.count(CertificateTemplate.id)))
    if (tpl_count or 0) == 0:
        t1 = CertificateTemplate(
            code="CERT-PRO-01",
            title="SERTIFIKAT PRAKTIK TELEKONSELING KLINIS",
            subtitle="Clinical Tele-Psychology Excellence & Competence",
            category_code="PRO",
            category_label="Psikolog Mandiri",
            milestone_criteria="Penyelesaian 25 Sesi Klinis Terverifikasi",
            description=(
                "Diberikan kepada {psychologist_name} (STR: {str_number}) atas dedikasi dan kompetensi "
                "klinis prima dalam menyelenggarakan telekonsultasi kesehatan mental dengan standar etika tertinggi. "
                "Nomor Registrasi Sertifikat: {certificate_number} (Diterbitkan {issue_date})."
            ),
            badge_color="#2563EB",
            trigger_type="sessions_milestone",
            min_completed_sessions=25,
            min_average_rating=None,
            auto_issue_enabled=True,
            is_active=True,
        )
        t2 = CertificateTemplate(
            code="CERT-PRO-02",
            title="SERTIFIKAT KEPATUHAN REKAM MEDIS SOAP",
            subtitle="Certified Clinical Medical Record Standard",
            category_code="SOAP",
            category_label="Psikolog Mandiri",
            milestone_criteria="Kepatuhan Rekam SOAP 100% pada 50 Sesi",
            description=(
                "Diberikan kepada {psychologist_name} (STR: {str_number}) atas komitmen integritas dokumentasi "
                "SOAP klinis terenkripsi aman demi keselamatan pasien. Nomor: {certificate_number}."
            ),
            badge_color="#D97706",
            trigger_type="sessions_milestone",
            min_completed_sessions=50,
            min_average_rating=None,
            auto_issue_enabled=True,
            is_active=True,
        )
        t3 = CertificateTemplate(
            code="CERT-PRO-03",
            title="SERTIFIKAT KONSELOR TELADAN EVA",
            subtitle="Distinguished Clinical Practitioner",
            category_code="TOP",
            category_label="Psikolog Mandiri",
            milestone_criteria="100+ Sesi Terlaksana dengan Rating Kepuasan >= 4.8",
            description=(
                "Penghargaan tertinggi platform EVA kepada {psychologist_name} (STR: {str_number}) atas loyalitas "
                "pelayanan intervensi krisis dan kepuasan pasien prima. Nomor: {certificate_number}."
            ),
            badge_color="#7E22CE",
            trigger_type="rating_milestone",
            min_completed_sessions=100,
            min_average_rating=Decimal("4.80"),
            auto_issue_enabled=True,
            is_active=True,
        )
        session.add_all([t1, t2, t3])
        await session.commit()
        await session.refresh(t1)
        logger.info("Seeded 3 default CertificateTemplate milestones.")

        cert_count = await session.scalar(select(func.count(PsychologistCertificate.id)))
        if (cert_count or 0) == 0:
            now_cert = datetime.now(UTC)
            cert_num = f"EVA/CERT/{now_cert.year}/PRO/00001"
            session.add(
                PsychologistCertificate(
                    certificate_number=cert_num,
                    sequence_number=1,
                    issue_year=now_cert.year,
                    category_code="PRO",
                    counselor_id=profile.id,
                    template_id=t1.id,
                    title=t1.title,
                    subtitle=t1.subtitle,
                    recipient_name=profile.full_name,
                    str_number=profile.str_number,
                    milestone_criteria=t1.milestone_criteria,
                    category_label=t1.category_label,
                    description=(
                        f"Diberikan kepada {profile.full_name} (STR: {profile.str_number}) atas dedikasi "
                        f"telekonseling klinis resmi EVA. Nomor: {cert_num}."
                    ),
                    badge_color=t1.badge_color,
                    trigger_source="manual",
                    status="active",
                    issued_at=now_cert,
                )
            )
            await session.commit()
            logger.info(f"Seeded initial official certificate {cert_num} for {profile.full_name}.")

    # 8. Seed Dynamic Master Psychologist Levels & Sample Per-Session Reviews
    level_count = await session.scalar(select(func.count(PsychologistLevel.id)))
    if (level_count or 0) == 0:
        lvl1 = PsychologistLevel(
            level_tier=1,
            name="Junior Practitioner",
            badge_icon="award",
            min_completed_sessions=0,
            min_average_rating=Decimal("0.00"),
            min_consultation_hours=Decimal("0.00"),
            min_review_count=0,
            default_session_price=Decimal("120.00"),
            platform_fee_percentage=Decimal("25.00"),
            allow_custom_price=False,
            min_custom_price=None,
            max_custom_price=None,
            is_active=True,
        )
        lvl2 = PsychologistLevel(
            level_tier=2,
            name="Registered Counselor",
            badge_icon="shield-check",
            min_completed_sessions=2,
            min_average_rating=Decimal("4.20"),
            min_consultation_hours=Decimal("1.00"),
            min_review_count=1,
            default_session_price=Decimal("150.00"),
            platform_fee_percentage=Decimal("20.00"),
            allow_custom_price=False,
            min_custom_price=None,
            max_custom_price=None,
            is_active=True,
        )
        lvl3 = PsychologistLevel(
            level_tier=3,
            name="Senior Specialist",
            badge_icon="star",
            min_completed_sessions=15,
            min_average_rating=Decimal("4.60"),
            min_consultation_hours=Decimal("7.50"),
            min_review_count=8,
            default_session_price=Decimal("200.00"),
            platform_fee_percentage=Decimal("15.00"),
            allow_custom_price=True,
            min_custom_price=Decimal("160.00"),
            max_custom_price=Decimal("260.00"),
            is_active=True,
        )
        lvl4 = PsychologistLevel(
            level_tier=4,
            name="Master Expert",
            badge_icon="crown",
            min_completed_sessions=40,
            min_average_rating=Decimal("4.80"),
            min_consultation_hours=Decimal("20.00"),
            min_review_count=20,
            default_session_price=Decimal("260.00"),
            platform_fee_percentage=Decimal("12.00"),
            allow_custom_price=True,
            min_custom_price=Decimal("200.00"),
            max_custom_price=Decimal("400.00"),
            is_active=True,
        )
        session.add_all([lvl1, lvl2, lvl3, lvl4])
        await session.commit()
        logger.info("Seeded 4 default dynamic PsychologistLevel career tiers.")

    review_count = await session.scalar(select(func.count(CounselorReview.id)))
    if (review_count or 0) == 0:
        completed_res = await session.execute(
            select(ConsultationSession).where(
                ConsultationSession.status == ConsultationSessionStatus.COMPLETED.value
            )
        )
        completed_list = list(completed_res.scalars().all())
        for idx, cs in enumerate(completed_list):
            existing_rev = await session.scalar(
                select(CounselorReview).where(CounselorReview.session_id == cs.id)
            )
            if not existing_rev:
                session.add(
                    CounselorReview(
                        session_id=cs.id,
                        counselor_id=cs.counselor_id,
                        patient_id=cs.patient_id,
                        rating=cs.patient_rating or Decimal("4.95"),
                        highlight_label="Sangat Sabar & Empati" if idx % 2 == 0 else "Solusi Praktis & Terarah",
                        review_text=(
                            "Konseling berjalan hangat dan terstruktur, membantu memahami pemicu stres dengan jelas."
                            if idx % 2 == 0
                            else "Penjelasan mudah dipahami dan teknik regulasi emosi langsung bisa dipraktikkan."
                        ),
                        is_anonymous=(idx % 2 == 1),
                    )
                )
        await session.commit()

    from app.services.level import LevelService

    await LevelService(session).evaluate_all_counselors()

    return profile


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    logger.info("Starting database seeding...")
    asyncio.run(seed_master_data())
    logger.info("Seeding completed successfully.")


if __name__ == "__main__":
    main()
