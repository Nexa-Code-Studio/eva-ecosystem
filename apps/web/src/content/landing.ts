import {
  BookOpen,
  Brain,
  Flame,
  Gauge,
  HeartHandshake,
  Lock,
  Mic,
  ShieldCheck,
  Smile,
  Stethoscope,
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
  { id: 'faq', label: 'FAQ' },
  { id: 'early-access', label: 'Early Access' },
] as const

export type NavId = (typeof navLinks)[number]['id']

export const DOWNLOAD_APK_URL = '/downloads/eva-beta.apk'

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
  primaryCta: 'Mulai Curhat Suara — Gratis',
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
    tag: 'Real-Time Voice Companion',
    title: 'Curhat Suara Satu Sentuhan',
    body: 'Bicara bebas kapan pun. EVA menangkap intonasi suaramu secara langsung dan membalas dengan kehangatan manusiawi.',
    problem: 'Capek mengetik panjang saat sedang kalut atau menangis.',
  },
  {
    id: 'quest',
    icon: Flame,
    tone: 'blush',
    tag: 'Emotional Resilience Quests',
    title: 'Misi Koping 3 Menit',
    body: 'Latihan pemulihan singkat berbasis sains (WHO) untuk redakan panik dan cemas seketika.',
    problem: 'Modul teori psikologi tebal jarang dipraktikkan saat stres memuncak.',
  },
  {
    id: 'avatar',
    icon: Smile,
    tone: 'secondary',
    tag: 'Dynamic Mood Avatar',
    title: 'Avatar Emosi Interaktif',
    body: 'Pantau suasana hatimu lewat avatar ekspresif yang tumbuh dan merayakan setiap langkah kecilmu.',
    problem: 'Mood tracker angka biasa terasa dingin dan membosankan.',
  },
  {
    id: 'diary',
    icon: BookOpen,
    tone: 'tertiary',
    tag: 'Smart Reflection Diary',
    title: 'Diari Otomatis Tanpa Ngetik',
    body: 'Setiap curhat otomatis dirangkum jadi refleksi bermakna dan aksi nyata tanpa perlu kamu ketik.',
    problem: 'Sering bingung harus menulis apa saat ingin rutin journaling.',
  },
  {
    id: 'screening',
    icon: Gauge,
    tone: 'success',
    tag: 'Evidence-Based Check & Bridge',
    title: 'Skrining Klinis & Rujukan',
    body: 'Ukur tingkat stres berkala (DASS-21) dan hubungkan ke psikolog profesional saat kamu butuh bantuan lanjutan.',
    problem: 'Sulit menilai kapan stres sudah butuh bantuan klinis profesional.',
  },
  {
    id: 'safety',
    icon: ShieldCheck,
    tone: 'crisis',
    tag: '24/7 SafetyNet',
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
      'Ya, 100% privat. EVA menerapkan arsitektur On-Device Data Sovereignty — catatan refleksi dan riwayat percakapanmu dienkripsi langsung di perangkatmu, tidak dijual ke pihak ketiga, dan tidak digunakan untuk melatih model iklan publik.',
  },
  {
    id: 'pricing',
    category: 'Biaya & Akses',
    question: 'Apakah aplikasi EVA gratis digunakan?',
    answer:
      'Selama periode Early Access, seluruh fitur inti EVA — termasuk Curhat Suara 24/7, Misi Koping 3 Menit, dan Diari Otomatis — dapat kamu gunakan sepenuhnya gratis tanpa biaya langganan.',
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
/* CTA                                                                 */
/* ------------------------------------------------------------------ */
export const waitlist = {
  kicker: 'Akses Awal Langsung',
  title: 'Mulai Perjalanan Tenangmu Bersama EVA.',
  description:
    'Unduh versi beta sekarang untuk mencoba fitur curhat suara dan latihan koping terpandu langsung di ponsel Android kamu.',
  button: 'Unduh Versi Beta (APK)',
  specs: ['Android 8.0+', apkMetadata.sizeFormatted, 'Bebas Biaya Langganan'],
  note: '100% Aman • Privasi tersimpan di ponsel • Bebas biaya',
}

export const partnerCtas = ['Ajukan Kemitraan Faskes', 'Baca Evaluasi Klinis Psikolog']

export const crisisHotline = 'Hubungi Layanan Krisis Bebas Pulsa (119 Ext 8)'

