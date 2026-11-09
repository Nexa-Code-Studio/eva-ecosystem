import {
  BookOpen,
  Building2,
  Calendar,
  Clock,
  Coins,
  GraduationCap,
  Mail,
  MapPin,
  Phone,
  ShieldCheck,
  User,
  Users,
} from 'lucide-react'
import type { PartnerAccount, Psychologist, PsychologistStatus } from '@/types/portal'
import { PsychologistRoleBadge, PsychologistShieldBadge } from '@/components/portal/PortalBadges'

interface MitraPsychologistDetailViewProps {
  psy: Psychologist
  partner: PartnerAccount | null
  onUpdateStatus: (status: PsychologistStatus) => void
}

export function MitraPsychologistDetailView({
  psy,
  partner,
  onUpdateStatus,
}: MitraPsychologistDetailViewProps) {
  const feeCoins = psy.sessionFeeCoins ?? 100
  const durationMinutes = psy.sessionDurationMinutes ?? 45

  const initials = psy.fullName
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join('')

  return (
    <div className="space-y-4 p-5 sm:p-6 text-xs">
      {/* 1. Header Profil Psikolog Mitra */}
      <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-4 shadow-2xs">
        <div className="flex items-start gap-3.5">
          <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-emerald-50 text-emerald-800 text-sm font-bold ring-2 ring-emerald-200">
            {initials || <User className="size-5" />}
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2 flex-wrap">
              <h3 className="text-base font-bold text-ink" title={psy.fullName}>
                {psy.fullName}
              </h3>
              <PsychologistShieldBadge
                role={psy.role}
                partnerName={partner?.facilityName}
                verificationStatus={psy.verificationStatus}
              />
            </div>
            <div className="mt-1 flex flex-wrap items-center gap-2">
              <PsychologistRoleBadge
                role={psy.role}
                verificationStatus={psy.verificationStatus}
              />
              <span className="inline-flex items-center gap-1 font-semibold text-emerald-700 bg-emerald-50 border border-emerald-200/80 rounded-[6px] px-2 py-0.5 text-[11px]">
                <Building2 className="size-3" />
                {partner?.facilityName ?? 'Faskes Mitra'}
              </span>
            </div>
            <div className="mt-2 flex items-center gap-1.5 text-[11px] text-ink-muted">
              <MapPin className="size-3 shrink-0 text-ink-muted/80" />
              <span>{psy.city ?? 'Indonesia'}</span>
              <span>·</span>
              <span className="text-ink">Afiliasi Faskes Mitra Terverifikasi</span>
            </div>
          </div>
        </div>
      </div>

      {/* 2. Highlight Card Layanan & Tarif Sesi */}
      <div className="rounded-[14px] border border-amber-200/80 bg-amber-50/35 p-4 shadow-2xs">
        <div className="flex items-center justify-between">
          <span className="text-[10px] font-bold tracking-wider text-amber-900 uppercase">
            Tarif &amp; Layanan Sesi Mitra
          </span>
          <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[9.5px] font-bold text-amber-800">
            Koin EVA
          </span>
        </div>

        <div className="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-2.5">
          <div className="rounded-[10px] border border-amber-200/60 bg-white/90 p-3">
            <span className="block text-[10px] text-amber-800/80">Biaya per Sesi</span>
            <div className="mt-1 flex items-center gap-1.5 font-bold text-amber-950">
              <Coins className="size-4 shrink-0 text-amber-600" />
              <span className="text-sm">{feeCoins} Koin</span>
            </div>
          </div>

          <div className="rounded-[10px] border border-amber-200/60 bg-white/90 p-3">
            <span className="block text-[10px] text-amber-800/80">Durasi Sesi</span>
            <div className="mt-1 flex items-center gap-1.5 font-bold text-amber-950">
              <Clock className="size-4 shrink-0 text-amber-600" />
              <span className="text-sm">{durationMinutes} Menit</span>
            </div>
          </div>

          <div className="rounded-[10px] border border-amber-200/60 bg-white/90 p-3">
            <span className="block text-[10px] text-amber-800/80">Kuota Rujukan</span>
            <div className="mt-1 flex items-center gap-1.5 font-bold text-amber-950">
              <Users className="size-4 shrink-0 text-amber-600" />
              <span className="text-sm">{psy.weeklyQuota ?? 15} klien / mgg</span>
            </div>
          </div>
        </div>
      </div>

      {/* 3. Grid 2-Kolom: Legalitas & Pendidikan */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
        {/* Kolom A: Legalitas Faskes */}
        <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-4 shadow-2xs">
          <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2.5">
            <ShieldCheck className="size-3.5 text-emerald-600" />
            <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
              Kredensial &amp; Penjaminan Faskes
            </span>
          </div>

          <div className="mt-3 space-y-2 text-[11px]">
            <div className="flex items-center justify-between">
              <span className="text-ink-muted">Nomor SIPP:</span>
              <span className="font-mono font-bold text-ink">{psy.sippNumber}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-ink-muted">Nomor STR:</span>
              {psy.strNumber ? (
                <span className="font-mono font-bold text-ink">{psy.strNumber}</span>
              ) : (
                <span className="text-emerald-700 font-medium">STR via Faskes Mitra</span>
              )}
            </div>
            <div className="flex items-center justify-between pt-1">
              <span className="text-ink-muted">Penjaminan:</span>
              <span className="font-medium text-ink">MoU / PKS Resmi</span>
            </div>
          </div>
        </div>

        {/* Kolom B: Pendidikan & Pengalaman */}
        <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-4 shadow-2xs">
          <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2.5">
            <GraduationCap className="size-3.5 text-indigo-600" />
            <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
              Pendidikan &amp; Pengalaman
            </span>
          </div>

          <div className="mt-3 space-y-2 text-[11px]">
            <div>
              <span className="text-ink-muted block text-[10px]">Pendidikan Terakhir</span>
              <p className="mt-0.5 font-semibold text-ink">
                {psy.education || 'Magister Psikologi Profesi'}
              </p>
            </div>
            <div className="flex items-center justify-between pt-1">
              <span className="text-ink-muted">Pengalaman Praktik:</span>
              <span className="font-bold text-ink">
                {psy.yearsExperience ?? 5} Tahun Praktik
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* 4. Jadwal Praktik & Kontak */}
      <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-4 shadow-2xs">
        <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2.5">
          <Calendar className="size-3.5 text-teal-600" />
          <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
            Jadwal Praktik di Faskes &amp; Kontak
          </span>
        </div>

        <div className="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-3 text-[11px]">
          <div className="flex items-start gap-2">
            <Clock className="size-3.5 shrink-0 text-ink-muted mt-0.5" />
            <div>
              <span className="text-ink-muted block text-[10px]">Jadwal Praktik</span>
              <span className="font-semibold text-ink">{psy.practiceSchedule}</span>
            </div>
          </div>

          <div className="space-y-1.5">
            {psy.email && (
              <div className="flex items-center gap-2">
                <Mail className="size-3.5 shrink-0 text-ink-muted" />
                <span className="truncate text-ink-soft">{psy.email}</span>
              </div>
            )}
            {psy.phone && (
              <div className="flex items-center gap-2">
                <Phone className="size-3.5 shrink-0 text-ink-muted" />
                <span className="font-mono text-ink-soft">{psy.phone}</span>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* 5. Fokus Layanan Klinis */}
      {psy.specializations.length > 0 && (
        <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-4 shadow-2xs">
          <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2.5">
            <BookOpen className="size-3.5 text-primary" />
            <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
              Fokus Layanan &amp; Spesialisasi Klinis
            </span>
          </div>
          <div className="mt-3 flex flex-wrap gap-1.5">
            {psy.specializations.map((spec) => (
              <span
                key={spec}
                className="rounded-[6px] border border-[#E2E8F0] bg-[#F8FAFC] px-2.5 py-1 text-[11px] font-medium text-ink shadow-2xs"
              >
                {spec}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* 6. Kartu Pengaturan Status Praktik Admin */}
      <div className="rounded-[14px] border border-slate-200 bg-[#F8FAFC] p-4 shadow-2xs">
        <div className="flex items-center justify-between gap-2 border-b border-[#E2E8F0] pb-2.5">
          <div className="flex items-center gap-2">
            <span className="size-2 rounded-full bg-primary" />
            <span className="text-xs font-bold text-ink">
              Pengaturan Status Operasional Praktik
            </span>
          </div>
          <span className="text-[10px] font-medium text-ink-muted">
            Kontrol Akses Rujukan
          </span>
        </div>

        <div className="mt-3 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div className="max-w-md">
            <p className="text-xs text-ink-muted leading-relaxed">
              Tentukan apakah psikolog mitra ini dapat menerima penugasan pasien rujukan skrining DASS-21 di portal admin.
            </p>
          </div>

          <div className="sm:w-60">
            <label htmlFor="mitra-status-select" className="sr-only">
              Status Praktik Psikolog Mitra
            </label>
            <select
              id="mitra-status-select"
              value={psy.status}
              onChange={(e) => onUpdateStatus(e.target.value as PsychologistStatus)}
              className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink shadow-2xs focus:border-primary focus:outline-none"
            >
              <option value="active">Aktif Menerima Rujukan</option>
              <option value="on_leave">Sedang Cuti</option>
              <option value="inactive">Nonaktif</option>
            </select>
          </div>
        </div>
      </div>
    </div>
  )
}

