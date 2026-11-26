import {
  BadgeCheck,
  BookOpen,
  Brain,
  CalendarClock,
  FileCheck2,
  Flame,
  Gauge,
  HeartHandshake,
  Lock,
  Mic,
  ShieldCheck,
  Smile,
  Stethoscope,
  Video,
  Wallet,
  type LucideIcon,
} from 'lucide-react'
import apkMetadata from '@/config/apkMetadata.json'
import type { IconTileTone } from '@/components/ui'

/* ------------------------------------------------------------------ */
/* Navigation                                                          */
/* ------------------------------------------------------------------ */
export const navLinks = [
  { id: 'fitur', label: 'Fitur' },
  { id: 'cara-kerja', label: 'Cara Kerja' },
  { id: 'keunggulan', label: 'Keunggulan' },
  { id: 'psikolog', label: 'Psikolog' },
  { id: 'faq', label: 'FAQ' },
] as const

export type NavId = (typeof navLinks)[number]['id']

export const DOWNLOAD_APK_URL =
  'https://github.com/Nexa-Code-Studio/eva-ecosystem/releases/latest/download/eva-mobile-release.apk'

export const DOWNLOAD_COUNSELOR_APK_URL =
  'https://github.com/Nexa-Code-Studio/eva-ecosystem/releases/download/prototype/eva-counselor-mobile-release.apk'

/* ------------------------------------------------------------------ */
/* ------------------------------------------------------------------ */
/* Hero                                                                */
/* ------------------------------------------------------------------ */
export const hero = {
  kicker: 'Teman Curhat Suara 24/7',
  titleLead: 'Tenangkan Pikiran Kalut,',
  titleAccent: 'Cukup Bicara Bebas.',
  subtitle:
    'Tak perlu mengetik panjang saat lelah. Curhatkan suaramu, pulihkan tenangmu dalam hitungan menit.',
  primaryCta: 'Mulai Curhat Suara (Gratis)',
  secondaryCta: 'Unduh Versi Beta (APK)',
  microcopy: ['100% Privat di Ponsel', 'Tanpa Biaya Langganan', 'Bebas Stigma'],
  stats: [
    { value: '24/7', label: 'Selalu siap mendengar' },
    { value: '3 mnt', label: 'Misi pemulihan cepat' },
    { value: 'HIMPSI', label: 'Disupervisi psikolog klinis' },
  ],
}

/* ------------------------------------------------------------------ */
/* Features                                                            */
/* ------------------------------------------------------------------ */
export type FeatureId = 'voice' | 'quest' | 'avatar' | 'diary' | 'screening' | 'safety'

export const FEATURE_SCREENSHOTS: Record<FeatureId, string> = {
  voice: '/images/mockups/voice.webp',
  quest: '/images/mockups/quest.webp',
  avatar: '/images/mockups/avatar.webp',
  diary: '/images/mockups/diary.webp',
  screening: '/images/mockups/screening.webp',
  safety: '/images/mockups/safety.webp',
}

export interface Feature {
  id: FeatureId
  icon: LucideIcon
  tone: IconTileTone
  tag: string
  title: string
  body: string
  problem: string
}

export const features: Feature[] = [
  {
    id: 'voice',
    icon: Mic,
    tone: 'primary',
    tag: 'Respon Suara Real-Time',
    title: 'Curhat Suara Satu Sentuhan',
    body: 'Bicara bebas kapan pun. EVA menangkap intonasi suaramu secara langsung dan membalas dengan kehangatan manusiawi.',
    problem: 'Capek mengetik panjang saat sedang kalut atau menangis.',
  },
  {
    id: 'quest',
    icon: Flame,
    tone: 'blush',
    tag: 'Misi Koping Terpandu',
    title: 'Misi Koping 3 Menit',
    body: 'Latihan pemulihan singkat berbasis sains (WHO) untuk redakan panik dan cemas seketika.',
    problem: 'Modul teori psikologi tebal jarang dipraktikkan saat stres memuncak.',
  },
  {
    id: 'avatar',
    icon: Smile,
    tone: 'secondary',
    tag: 'Avatar Suasana Hati',
    title: 'Avatar Emosi Interaktif',
    body: 'Pantau suasana hatimu lewat avatar ekspresif yang tumbuh dan merayakan setiap langkah kecilmu.',
    problem: 'Mood tracker angka biasa terasa dingin dan membosankan.',
  },
  {
    id: 'diary',
    icon: BookOpen,
    tone: 'tertiary',
    tag: 'Diari Refleksi Pintar',
    title: 'Diari Otomatis Tanpa Ngetik',
    body: 'Setiap curhat otomatis dirangkum jadi refleksi bermakna dan aksi nyata tanpa perlu kamu ketik.',
    problem: 'Sering bingung harus menulis apa saat ingin rutin journaling.',
  },
  {
    id: 'screening',
    icon: Gauge,
    tone: 'success',
    tag: 'Skrining DASS-21 & Rujukan',
    title: 'Skrining Klinis & Rujukan',
    body: 'Ukur tingkat stres berkala (DASS-21) dan hubungkan ke psikolog profesional saat kamu butuh bantuan lanjutan.',
    problem: 'Sulit menilai kapan stres sudah butuh bantuan klinis profesional.',
  },
  {
    id: 'safety',
    icon: ShieldCheck,
    tone: 'crisis',
    tag: 'Protokol Darurat 24/7',
    title: 'Proteksi Darurat 24/7',
    body: 'Protokol keselamatan standar WHO yang otomatis siaga menghubungkan ke Hotline 119 jika situasi krisis terdeteksi.',
    problem: 'Kekhawatiran AI tidak memiliki akuntabilitas etika saat situasi krisis nyata.',
  },
]

/* ------------------------------------------------------------------ */
/* How it works                                                        */
/* ------------------------------------------------------------------ */
export const steps = [
  {
    icon: Mic,
    title: '1. Sapa & Curhat Bebas',
    body: 'Tekan satu tombol untuk berbicara lepas atau ketik unek-unekmu di ruang privatmu.',
  },
  {
    icon: Brain,
    title: '2. Urai Benang Kusut',
    body: 'EVA memvalidasi emosimu dan membantumu melihat masalah dari sudut pandang baru.',
  },
  {
    icon: Smile,
    title: '3. Ambil Misi 3 Menit',
    body: 'Lakukan latihan koping mikro terpandu untuk mengembalikan rasa tenangmu.',
  },
  {
    icon: Flame,
    title: '4. Lihat Kemajuanmu',
    body: 'Avatar bertumbuh, kumpulkan kebiasaan baik, dan baca rangkuman diari otomatis.',
  },
] satisfies { icon: LucideIcon; title: string; body: string }[]

/* ------------------------------------------------------------------ */
/* USP / differentiation                                               */
/* ------------------------------------------------------------------ */
export const uspRows = [
  {
    icon: Mic,
    dimension: 'Respon Suara & Emosi',
    others: 'Teks kaku, tidak peka nada bicara, mayoritas berbahasa Inggris.',
    eva: 'Mendengar intonasi suara nyata secara langsung dalam bahasa Indonesia yang luwes.',
  },
  {
    icon: HeartHandshake,
    dimension: 'Pendekatan Interaksi',
    others: 'Kaku seperti pasien di klinik, atau sekadar bot pembaca FAQ.',
    eva: 'Sahabat sebaya suportif dengan misi kebiasaan mikro yang interaktif.',
  },
  {
    icon: Lock,
    dimension: 'Privasi & Keamanan Data',
    others: 'Riwayat curhat tersimpan di cloud publik yang rentan kebocoran.',
    eva: '100% tersimpan aman di perangkatmu (On-Device Data Sovereignty).',
  },
  {
    icon: Stethoscope,
    dimension: 'Validasi Klinis',
    others: 'Sering memberi diagnosa asal atau spekulasi medis tanpa dasar.',
    eva: 'Disupervisi psikolog klinis (HIMPSI) murni untuk pertolongan pertama emosi.',
  },
  {
    icon: ShieldCheck,
    dimension: 'Akses Bantuan Lanjutan',
    others: 'Terisolasi; pengguna bingung harus ke mana jika kondisi memburuk.',
    eva: 'Menyediakan ringkasan awal untuk psikolog tanpa membocorkan isi chat.',
  },
] satisfies { icon: LucideIcon; dimension: string; others: string; eva: string }[]

/* ------------------------------------------------------------------ */
/* FAQ                                                                 */
/* ------------------------------------------------------------------ */
export interface FaqItem {
  id: string
  question: string
  answer: string
  category: string
}

export const faqs: FaqItem[] = [
  {
    id: 'privacy',
    category: 'Privasi & Keamanan',
    question: 'Apakah rekaman suara dan isi curhat saya benar-benar aman?',
    answer:
      'Ya, 100% privat. EVA menerapkan arsitektur On-Device Data Sovereignty: catatan refleksi dan riwayat percakapanmu dienkripsi langsung di perangkatmu, tidak dijual ke pihak ketiga, dan tidak digunakan untuk melatih model iklan publik.',
  },
  {
    id: 'pricing',
    category: 'Biaya & EVA Coin',
    question: 'Bagaimana sistem biaya dan penggunaan Koin di aplikasi EVA?',
    answer:
      'Fitur Misi Koping Harian, Diari Otomatis, dan Skrining DASS-21 dapat diakses gratis. Untuk seluruh layanan berbayar EVA — baik Curhat Suara AI 24/7 (1 Koin = 1 menit berbicara) maupun telekonsultasi psikolog profesional (tarif Koin per sesi 30 menit) — EVA menggunakan mata uang terpadu EVA Coin (kurs dasar Rp1.000/Koin dengan pilihan paket top-up hemat). Setiap pengguna baru otomatis mendapatkan bonus 10 Koin gratis.',
  },
  {
    id: 'clinical',
    category: 'Batas Klinis',
    question: 'Apakah EVA menggantikan peran psikolog atau psikiater?',
    answer:
      'Tidak. EVA adalah pendamping pertolongan pertama emosional (digital first-aid) yang disupervisi oleh psikolog klinis (HIMPSI) dan bersifat non-diagnostik. Jika hasil skrining DASS-21 menunjukkan perlunya pendampingan lanjutan, EVA justru membantumu terhubung ke psikolog profesional.',
  },
  {
    id: 'crisis',
    category: 'Protokol Darurat',
    question: 'Apa yang terjadi jika saya berada dalam kondisi krisis darurat?',
    answer:
      'EVA dilengkapi protokol keselamatan 24/7 SafetyNet berstandar WHO. Ketika terdeteksi indikasi krisis atau bahaya diri, EVA segera menghentikan percakapan biasa dan menyediakan akses satu sentuhan ke layanan darurat bebas pulsa Kemenkes (119 Ext 8) serta kontak orang kepercayaanmu.',
  },
  {
    id: 'devices',
    category: 'Ketersediaan Perangkat',
    question: 'Di perangkat apa saja saya bisa mengunduh EVA?',
    answer:
      'Saat ini versi Beta (APK) dapat langsung kamu unduh dan pasang untuk perangkat Android melalui tombol unduh di halaman ini. Versi iOS sedang dalam tahap pengujian akhir.',
  },
]

/* ------------------------------------------------------------------ */
/* Clinical Evaluation Summary (Evidence-backed Modal Data)           */
/* ------------------------------------------------------------------ */
export interface ClinicalEvaluationItem {
  id: string
  title: string
  badge: string
  summary: string
  details: string[]
}

export const clinicalEvaluationData: ClinicalEvaluationItem[] = [
  {
    id: 'supervision',
    title: 'Supervisi Psikologi Klinis (HIMPSI)',
    badge: 'Etika & Batas Layanan',
    summary:
      'Psikolog klinis berlisensi HIMPSI ikut mengawasi alur percakapan EVA agar tetap berfungsi sebagai pendamping awal, bukan pengganti terapi.',
    details: [
      'Berperan sebagai pertolongan pertama emosi sehari-hari, bukan untuk memberi terapi medis atau diagnosis gangguan kejiwaan.',
      'Percakapan dirancang agar mendengarkan dengan hangat dan menerima perasaan pengguna tanpa menghakimi.',
      'Tim klinis meninjau gaya bahasa dan panduan respon EVA secara berkala.',
    ],
  },
  {
    id: 'screening',
    title: 'Pemeriksaan Stres DASS-21',
    badge: 'Alat Ukur Teruji',
    summary:
      'EVA memakai kuesioner DASS-21 versi bahasa Indonesia yang terstandar untuk membantu pengguna mengenali tingkat stresnya sejak dini.',
    details: [
      'Berisi 21 pertanyaan tervalidasi dengan rentang hasil dari Normal hingga Sangat Berat.',
      'Hasil ditampilkan apa adanya dengan bahasa yang tenang agar tidak memicu rasa takut berlebih.',
      'Pengguna dapat membagikan ringkasan hasil ini kepada psikolog saat butuh rujukan lanjutan.',
    ],
  },
  {
    id: 'safetynet',
    title: 'Siaga Kondisi Krisis 24/7 (Standar WHO)',
    badge: 'Protokol Keselamatan',
    summary:
      'Saat terdeteksi tanda bahaya diri atau krisis berat, EVA menghentikan obrolan santai dan langsung mengarahkan ke bantuan darurat.',
    details: [
      'Menyediakan tombol panggil cepat ke Layanan Krisis Bebas Pulsa Kemenkes (Hotline 119 Ext 8).',
      'Menampilkan nomor wali atau orang kepercayaan yang disimpan pengguna di ponselnya sendiri.',
      'Catatan kondisi krisis tidak dibagikan ke pihak mana pun demi menjaga penuh privasi pengguna.',
    ],
  },
]

/* ------------------------------------------------------------------ */
/* Eva Counselor (Psikolog Klinis)                                     */
/* ------------------------------------------------------------------ */
export type CounselorFeatureId = 'schedule' | 'consent' | 'teleconsult' | 'finance'

export const COUNSELOR_SCREENSHOTS: Record<CounselorFeatureId, string> = {
  schedule: '/images/mockups/counselor/schedule.webp',
  consent: '/images/mockups/counselor/consent.webp',
  teleconsult: '/images/mockups/counselor/teleconsult.webp',
  finance: '/images/mockups/counselor/finance.webp',
}

export interface CounselorFeature {
  id: CounselorFeatureId
  icon: LucideIcon
  tone: IconTileTone
  tag: string
  title: string
  body: string
  workflow: string
}

export const counselorSection = {
  kicker: 'Khusus Psikolog Klinis (HIMPSI)',
  titleLead: 'Ruang Praktik di Ponsel',
  titleAccent: 'Untuk Psikolog.',
  subtitle:
    'Atur jadwal praktik, baca ringkasan kondisi pasien sebelum bertemu, dan jalani konsultasi video lewat satu aplikasi Android.',
  verifyHeading: 'Cara Bergabung & Aturan Privasi',
  verifyNote:
    'Psikolog mendaftar langsung di aplikasi Eva Counselor dengan mengunggah berkas STR dan SIP aktif untuk kami periksa.',
  secondaryCta: 'Lihat Standar Layanan EVA',
}

export const counselorFeatures: CounselorFeature[] = [
  {
    id: 'schedule',
    icon: CalendarClock,
    tone: 'primary',
    tag: 'Daftar & Jadwal',
    title: 'Unggah STR/SIP dan Atur Jadwal Sendiri',
    body: 'Daftarkan akunmu langsung lewat aplikasi dengan mengunggah STR dan SIP. Setelah terverifikasi, kamu bebas memilih hari dan jam praktik.',
    workflow: 'Kamu tetap memegang kendali penuh atas jam aktif dan kesiapan menerima pasien baru.',
  },
  {
    id: 'consent',
    icon: FileCheck2,
    tone: 'success',
    tag: 'Izin Pasien',
    title: 'Gambaran Stres DASS-21 Sebelum Sesi',
    body: 'Sebelum panggilan mulai, baca skor DASS-21 dan catatan awal yang dibagikan atas izin pasien. Obrolan pribadi mereka di aplikasi tetap tertutup.',
    workflow: 'Membantu kamu memahami kondisi pasien sejak awal tanpa membuka isi curhat pribadinya.',
  },
  {
    id: 'teleconsult',
    icon: Video,
    tone: 'tertiary',
    tag: 'Konsultasi Video',
    title: 'Sesi Video 30 Menit di Dalam Aplikasi',
    body: 'Temui pasien langsung lewat panggilan video 30 menit di aplikasi. Jika obrolan selesai lebih cepat, sesi bisa ditutup bersama dengan satu konfirmasi.',
    workflow: 'Semua jadwal dan panggilan berjalan di tempat yang sama, tanpa perlu kirim tautan ke aplikasi lain.',
  },
  {
    id: 'finance',
    icon: Wallet,
    tone: 'secondary',
    tag: 'Pendapatan Sesi',
    title: 'Catatan Honorarium & Pencairan Jelas',
    body: 'Pantau perolehan EVA Coin dari setiap sesi konsultasi yang selesai, lalu ajukan pencairan dana ke rekening bank yang sudah terdaftar.',
    workflow: 'Rincian pendapatan tiap sesi dan status transfer tercatat rapi di halaman keuangan.',
  },
]

export const counselorOnboardingHighlights = [
  { icon: BadgeCheck, label: 'Unggah STR dan SIP aktif lewat aplikasi' },
  { icon: ShieldCheck, label: 'Catatan pasien hanya terbuka jika diizinkan' },
  { icon: Stethoscope, label: 'EVA memberi pendampingan awal, bukan diagnosa' },
]

/* ------------------------------------------------------------------ */
/* CTA                                                                 */
/* ------------------------------------------------------------------ */
export const waitlist = {
  badge: 'Untuk Pengguna',
  appName: 'Eva Mobile',
  kicker: 'Akses Awal Langsung',
  title: 'Mulai Perjalanan Tenangmu Bersama EVA.',
  subtitle: 'Curhat suara 24/7, misi koping 3 menit, dan skrining DASS-21 terenkripsi di ponselmu.',
  description:
    'Unduh versi beta sekarang untuk mencoba fitur curhat suara dan latihan koping terpandu langsung di ponsel Android kamu.',
  button: 'Unduh Eva Mobile (APK)',
  specs: ['Android 8.0+', `Rilis ${apkMetadata.mobile.version}`, apkMetadata.mobile.sizeFormatted, 'Bebas Biaya Langganan'],
  note: '100% Aman • Privasi tersimpan di ponsel • Bebas biaya langganan',
}

export const counselorCta = {
  badge: 'Untuk Psikolog',
  appName: 'Eva Counselor',
  subtitle:
    'Untuk psikolog mitra yang ingin mengatur jadwal praktik, membaca ringkasan izin pasien, menjalani sesi video 30 menit, dan mencairkan honorarium.',
  button: 'Unduh Eva Counselor (APK)',
  specs: ['Android 8.0+', `Rilis ${apkMetadata.counselor.version}`, apkMetadata.counselor.sizeFormatted, 'Verifikasi STR & SIP'],
  note: 'Verifikasi STR & SIP • Rekening pencairan tercatat',
}

export const psychologistCtas = ['Daftar Psikolog Mandiri', 'Baca Evaluasi Klinis Psikolog']

export const crisisHotline = 'Hubungi Layanan Krisis Bebas Pulsa (119 Ext 8)'

