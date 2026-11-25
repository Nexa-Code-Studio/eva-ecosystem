import type { ComponentType } from 'react'
import {
  BadgeCheck,
  CalendarClock,
  Check,
  FileCheck2,
  Home,
  Mic,
  PhoneOff,
  ShieldCheck,
  User,
  Users,
  Video,
  VideoOff,
  Wallet,
} from 'lucide-react'
import type { CounselorFeatureId } from '@/content/landing'
import { cn } from '@/lib/cn'
import { glassMini, ScreenHeader } from './MockupPrimitives'

function CounselorBottomNav({ active }: { active: number }) {
  const items = [
    { icon: Home, label: 'Beranda' },
    { icon: Users, label: 'Pasien' },
    { icon: Wallet, label: 'Keuangan' },
    { icon: User, label: 'Profil' },
  ]
  return (
    <div className="absolute inset-x-3 bottom-3 flex h-[54px] items-center justify-around rounded-pill border border-white/80 bg-white/95 px-2 shadow-nav">
      {items.map((item, idx) => {
        const Icon = item.icon
        const isActive = idx === active
        return (
          <span
            key={item.label}
            className={cn(
              'flex flex-col items-center justify-center rounded-[14px] px-3 py-1 transition-colors',
              isActive ? 'bg-primary-container text-primary' : 'text-ink-muted',
            )}
          >
            <Icon className="size-4" strokeWidth={isActive ? 2.3 : 1.8} />
            <span className="mt-0.5 text-[8px] font-bold">{item.label}</span>
          </span>
        )
      })}
    </div>
  )
}

export function CounselorScheduleScreen() {
  const days = [
    { d: 'Sen', n: '24' },
    { d: 'Sel', n: '25', active: true },
    { d: 'Rab', n: '26' },
    { d: 'Kam', n: '27' },
    { d: 'Jum', n: '28' },
  ]

  return (
    <div className="h-full px-0.5">
      <div className="flex items-center justify-between px-5 pt-3">
        <div>
          <p className="text-[10px] font-extrabold tracking-[0.1em] text-primary uppercase">
            Eva Counselor
          </p>
          <p className="mt-0.5 text-[16px] font-bold text-ink">Jadwal Praktik</p>
        </div>
        <span className="inline-flex items-center gap-1 rounded-pill bg-[#E8F5E9] px-2.5 py-1 text-[9.5px] font-bold text-[#2E7D32]">
          <BadgeCheck className="size-3" /> STR Terverifikasi
        </span>
      </div>

      <div className="mt-3.5 grid grid-cols-5 gap-1.5 px-4">
        {days.map((item) => (
          <div
            key={item.d}
            className={cn(
              'flex flex-col items-center rounded-[14px] border py-2 text-center',
              item.active
                ? 'border-primary bg-primary text-white shadow-btn'
                : 'border-border-subtle bg-white text-ink-soft',
            )}
          >
            <span className="text-[9px] font-semibold opacity-80">{item.d}</span>
            <span className="mt-0.5 text-[12px] font-extrabold">{item.n}</span>
          </div>
        ))}
      </div>

      <div className="mt-3.5 space-y-2.5 px-4">
        <div className={cn(glassMini, 'border-primary/20 bg-white/95 p-3')}>
          <div className="flex items-center justify-between">
            <span className="rounded-pill bg-primary-container px-2 py-0.5 text-[9px] font-bold text-primary">
              14:00 - 14:30 WIB
            </span>
            <span className="text-[9.5px] font-bold text-[#2E7D32]">Consent Aktif</span>
          </div>
          <p className="mt-2 text-[12px] font-bold text-ink">Sesi Telekonsultasi (30 mnt)</p>
          <p className="mt-0.5 text-[10px] text-ink-soft">Pasien #A-104 • Ringkasan DASS-21 siap ditinjau</p>
        </div>

        <div className={cn(glassMini, 'p-3')}>
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1 text-[10px] font-bold text-ink-muted">
              <CalendarClock className="size-3 text-primary" /> Slot Tersedia
            </span>
            <span className="text-[9.5px] font-semibold text-primary">Aktif</span>
          </div>
          <p className="mt-1.5 text-[11px] font-semibold text-ink">16:00 - 19:00 WIB</p>
          <p className="text-[9.5px] text-ink-muted">3 slot konsultasi terbuka untuk pemesanan</p>
        </div>
      </div>

      <CounselorBottomNav active={0} />
    </div>
  )
}

export function CounselorConsentScreen() {
  const scores = [
    { label: 'Depresi', level: 'Ringan', width: '38%', color: 'bg-primary' },
    { label: 'Kecemasan', level: 'Sedang', width: '62%', color: 'bg-amber-500' },
    { label: 'Stres', level: 'Sedang', width: '58%', color: 'bg-primary-light' },
  ]

  return (
    <div className="h-full">
      <ScreenHeader subtitle="Izin Pasien Aktif" title="Ringkasan Klinis Awal" />

      <div className="mx-4 mt-3 flex items-center gap-2 rounded-[14px] border border-[#2E7D32]/20 bg-[#E8F5E9] px-3 py-2">
        <FileCheck2 className="size-4 shrink-0 text-[#2E7D32]" />
        <p className="text-[9.5px] font-semibold leading-tight text-[#1B5E20]">
          Hanya skor DASS-21 dan ringkasan klinis terenkripsi. Log curhat pribadi tetap di perangkat pasien.
        </p>
      </div>

      <div className={cn(glassMini, 'mx-4 mt-3 p-3.5')}>
        <p className="text-[10px] font-extrabold tracking-[0.08em] text-ink-muted uppercase">
          Profil Skrining DASS-21
        </p>
        <div className="mt-2.5 space-y-2.5">
          {scores.map((s) => (
            <div key={s.label}>
              <div className="flex items-center justify-between text-[10px]">
                <span className="font-semibold text-ink">{s.label}</span>
                <span className="font-bold text-primary">{s.level}</span>
              </div>
              <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-primary-container">
                <div className={cn('h-full rounded-full', s.color)} style={{ width: s.width }} />
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="mx-4 mt-2.5 rounded-[16px] bg-luna-insight p-3">
        <p className="flex items-center gap-1 text-[9px] font-extrabold tracking-[0.08em] text-primary uppercase">
          <ShieldCheck className="size-3" /> Fokus Pendampingan
        </p>
        <p className="mt-1 text-[10px] leading-snug text-secondary-dark">
          Pola tidur tidak teratur dalam 7 hari terakhir dan beban akademik menjelang tenggat akhir bulan.
        </p>
      </div>

      <CounselorBottomNav active={1} />
    </div>
  )
}

export function CounselorTeleconsultScreen() {
  return (
    <div className="relative flex h-full flex-col justify-between bg-obsidian px-4 pt-4 pb-5 text-white">
      <div className="flex items-center justify-between">
        <span className="inline-flex items-center gap-1.5 rounded-pill bg-white/10 px-2.5 py-1 text-[9.5px] font-bold text-white">
          <span className="size-1.5 rounded-full bg-emerald-400" /> WebRTC Terenkripsi
        </span>
        <span className="rounded-pill bg-primary/30 px-2.5 py-1 text-[10px] font-bold text-primary-light">
          18:24 tersisa
        </span>
      </div>

      <div className="relative my-3 flex flex-1 flex-col items-center justify-center rounded-[22px] border border-white/10 bg-[linear-gradient(160deg,#25285A_0%,#191C2E_100%)] p-4 text-center">
        <div className="flex size-16 items-center justify-center rounded-full bg-primary/25 text-primary-light ring-2 ring-primary-light/30">
          <Video className="size-7" />
        </div>
        <p className="mt-3 text-[13px] font-bold text-white">Ruang Telekonsultasi 30 Menit</p>
        <p className="mt-1 text-[10px] text-white/70">Pasien #A-104 • Consent DASS-21 Aktif</p>

        <div className="absolute right-2.5 bottom-2.5 flex h-16 w-12 flex-col items-center justify-center rounded-[12px] border border-white/20 bg-white/10 backdrop-blur-sm">
          <User className="size-4 text-white/80" />
          <span className="mt-1 text-[8px] font-semibold text-white/70">Psikolog</span>
        </div>
      </div>

      <div className="flex items-center justify-center gap-3">
        <span className="flex size-10 items-center justify-center rounded-full bg-white/12 text-white">
          <Mic className="size-4" />
        </span>
        <span className="flex size-10 items-center justify-center rounded-full bg-white/12 text-white">
          <VideoOff className="size-4" />
        </span>
        <span className="flex h-10 items-center gap-1.5 rounded-pill bg-crisis-text px-4 text-[10.5px] font-bold text-white">
          <PhoneOff className="size-3.5" /> Akhiri Sesi
        </span>
      </div>
    </div>
  )
}

export function CounselorFinanceScreen() {
  const entries = [
    { label: 'Sesi 30 mnt • #A-104', amount: '+40 Koin', status: 'Masuk' },
    { label: 'Sesi 30 mnt • #B-089', amount: '+40 Koin', status: 'Masuk' },
    { label: 'Pencairan Rekening BCA', amount: 'Rp450.000', status: 'Diproses' },
  ]

  return (
    <div className="h-full">
      <ScreenHeader subtitle="Honorarium Psikolog" title="Saldo & Pencairan" />

      <div className="mx-4 mt-3 rounded-[20px] bg-primary p-4 text-white shadow-btn">
        <p className="text-[9.5px] font-bold tracking-[0.08em] text-white/75 uppercase">
          Saldo Dapat Dicairkan
        </p>
        <p className="mt-1 text-[20px] font-extrabold">240 EVA Coin</p>
        <div className="mt-2.5 flex items-center justify-between text-[9.5px] text-white/85">
          <span className="inline-flex items-center gap-1">
            <Check className="size-3" /> Rekening Terverifikasi
          </span>
          <span className="rounded-pill bg-white px-2.5 py-0.5 font-bold text-primary">
            Ajukan Tarik
          </span>
        </div>
      </div>

      <div className="mt-3 space-y-2 px-4">
        {entries.map((e) => (
          <div key={e.label} className={cn(glassMini, 'flex items-center justify-between px-3 py-2.5')}>
            <div>
              <p className="text-[10.5px] font-bold text-ink">{e.label}</p>
              <p className="text-[9px] text-ink-muted">{e.status}</p>
            </div>
            <span className="text-[10.5px] font-extrabold text-primary">{e.amount}</span>
          </div>
        ))}
      </div>

      <CounselorBottomNav active={2} />
    </div>
  )
}

const counselorScreens: Record<CounselorFeatureId, ComponentType> = {
  schedule: CounselorScheduleScreen,
  consent: CounselorConsentScreen,
  teleconsult: CounselorTeleconsultScreen,
  finance: CounselorFinanceScreen,
}

export function CounselorScreen({ id }: { id: CounselorFeatureId }) {
  const Screen = counselorScreens[id]
  return <Screen />
}
