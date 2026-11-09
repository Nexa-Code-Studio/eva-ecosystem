import {
  BookOpen,
  Calendar,
  Clock,
  Coins,
  Edit3,
  GraduationCap,
  Mail,
  Phone,
  ShieldCheck,
  User,
  Users,
  X,
} from 'lucide-react'
import { useEffect } from 'react'
import { cn } from '@/lib/cn'
import type { Psychologist, PsychologistStatus } from '@/types/portal'

interface PartnerPsychologistDetailModalProps {
  psy: Psychologist | null
  onClose: () => void
  onEdit: (psy: Psychologist) => void
  onStatusChange: (psyId: string, status: PsychologistStatus) => void
}

export function PartnerPsychologistDetailModal({
  psy,
  onClose,
  onEdit,
  onStatusChange,
}: PartnerPsychologistDetailModalProps) {
  useEffect(() => {
    if (!psy) return
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose()
      }
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [psy, onClose])

  if (!psy) return null

  const feeCoins = psy.sessionFeeCoins ?? 50
  const durationMinutes = psy.sessionDurationMinutes ?? 45
  const weeklyQuota = psy.weeklyQuota ?? 10

  const initials = psy.fullName
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join('')

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="partner-psy-detail-title"
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink/45 p-4 backdrop-blur-[1px]"
      onClick={onClose}
    >
      <div
        className="flex max-h-[90vh] w-full max-w-3xl flex-col rounded-[16px] border border-[#E2E8F0] bg-white shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Top Header */}
        <div className="flex items-start justify-between gap-3 border-b border-[#E2E8F0] px-6 py-4">
          <div>
            <h2
              id="partner-psy-detail-title"
              className="text-base font-bold text-ink"
            >
              Detail Profil Psikolog
            </h2>
            <p className="mt-0.5 text-xs text-ink-muted">
              Informasi lengkap kredensial legalitas, jadwal praktik, dan fokus layanan klinis.
            </p>
          </div>

          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup modal detail psikolog"
            className="inline-flex size-8 cursor-pointer items-center justify-center rounded-[8px] border border-[#CBD5E1] text-ink-muted transition-colors hover:bg-slate-100 hover:text-ink focus:outline-none focus:ring-2 focus:ring-primary/20"
          >
            <X className="size-4" />
          </button>
        </div>

        {/* Scrollable Body Content */}
        <div className="flex-1 space-y-4 overflow-y-auto p-6 text-xs">
          {/* 1. Header Identitas Utama */}
          <div className="rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-4">
            <div className="flex flex-col gap-3.5 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex items-center gap-3.5">
                <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-base ring-2 ring-primary/20">
                  {initials || <User className="size-6" />}
                </div>
                <div>
                  <h3 className="text-base font-bold text-ink">{psy.fullName}</h3>
                  <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-ink-muted">
                    <span className="font-mono font-medium text-ink">
                      SIPP: {psy.sippNumber}
                    </span>
                    {psy.yearsExperience && (
                      <span>· {psy.yearsExperience} tahun pengalaman praktik</span>
                    )}
                  </div>
                </div>
              </div>

              {/* Status Praktik Badge */}
              <div className="self-start sm:self-auto">
                <span
                  className={cn(
                    'inline-flex items-center rounded-[6px] border px-2.5 py-1 text-xs font-semibold',
                    psy.status === 'active' &&
                      'border-emerald-300 bg-emerald-50 text-emerald-800',
                    psy.status === 'on_leave' &&
                      'border-amber-300 bg-amber-50 text-amber-800',
                    psy.status === 'inactive' &&
                      'border-slate-300 bg-slate-100 text-slate-700',
                  )}
                >
                  <span
                    className={cn(
                      'mr-1.5 size-2 rounded-full',
                      psy.status === 'active' && 'bg-emerald-600',
                      psy.status === 'on_leave' && 'bg-amber-600',
                      psy.status === 'inactive' && 'bg-slate-500',
                    )}
                  />
                  {psy.status === 'active'
                    ? 'Aktif Praktik'
                    : psy.status === 'on_leave'
                      ? 'Sedang Cuti'
                      : 'Nonaktif'}
                </span>
              </div>
            </div>
          </div>

          {/* 2. Highlight Card Layanan & Tarif Koin Sesi */}
          <div className="rounded-[12px] border border-amber-200/80 bg-amber-50/40 p-4">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold tracking-wider text-amber-900 uppercase">
                Pengaturan Layanan Konseling Faskes
              </span>
              <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-bold text-amber-800">
                Koin EVA
              </span>
            </div>

            <div className="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-2.5">
              <div className="rounded-[8px] border border-amber-200/60 bg-white p-3">
                <span className="block text-[11px] text-amber-800/80">Tarif Sesi</span>
                <div className="mt-1 flex items-center gap-1.5 font-bold text-amber-950">
                  <Coins className="size-4 shrink-0 text-amber-600" />
                  <span className="text-sm">{feeCoins} Koin</span>
                </div>
              </div>

              <div className="rounded-[8px] border border-amber-200/60 bg-white p-3">
                <span className="block text-[11px] text-amber-800/80">Durasi Sesi</span>
                <div className="mt-1 flex items-center gap-1.5 font-bold text-amber-950">
                  <Clock className="size-4 shrink-0 text-amber-600" />
                  <span className="text-sm">{durationMinutes} Menit</span>
                </div>
              </div>

              <div className="rounded-[8px] border border-amber-200/60 bg-white p-3">
                <span className="block text-[11px] text-amber-800/80">Kapasitas Rujukan</span>
                <div className="mt-1 flex items-center gap-1.5 font-bold text-amber-950">
                  <Users className="size-4 shrink-0 text-amber-600" />
                  <span className="text-sm">{weeklyQuota} pasien / minggu</span>
                </div>
              </div>
            </div>
          </div>

          {/* 3. Grid 2 Kolom: Kredensial Legalitas & Pendidikan */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            {/* Legalitas */}
            <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
              <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2">
                <ShieldCheck className="size-3.5 text-primary" />
                <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
                  Legalitas &amp; STR
                </span>
              </div>
              <div className="mt-2.5 space-y-2 text-xs">
                <div className="flex items-center justify-between">
                  <span className="text-ink-muted">Nomor SIPP:</span>
                  <span className="font-mono font-bold text-ink">{psy.sippNumber}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-ink-muted">Nomor STR:</span>
                  {psy.strNumber ? (
                    <span className="font-mono font-bold text-ink">{psy.strNumber}</span>
                  ) : (
                    <span className="text-ink-muted">Penjaminan Mitra Faskes</span>
                  )}
                </div>
              </div>
            </div>

            {/* Pendidikan & Pengalaman */}
            <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
              <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2">
                <GraduationCap className="size-3.5 text-primary" />
                <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
                  Pendidikan Profesi
                </span>
              </div>
              <div className="mt-2.5 space-y-2 text-xs">
                <div>
                  <span className="text-ink-muted block text-[10px]">Pendidikan Terakhir</span>
                  <p className="mt-0.5 font-semibold text-ink">
                    {psy.education || 'Magister Psikologi Profesi Klinis'}
                  </p>
                </div>
                <div className="flex items-center justify-between pt-1">
                  <span className="text-ink-muted">Lama Praktik:</span>
                  <span className="font-bold text-ink">
                    {psy.yearsExperience ? `${psy.yearsExperience} Tahun` : 'Tersertifikasi'}
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* 4. Jadwal Praktik & Kontak */}
          <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
            <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2">
              <Calendar className="size-3.5 text-primary" />
              <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
                Jadwal Praktik &amp; Kontak Komunikasi
              </span>
            </div>

            <div className="mt-2.5 grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div className="flex items-start gap-2">
                <Clock className="size-3.5 shrink-0 text-ink-muted mt-0.5" />
                <div>
                  <span className="text-ink-muted block text-[10px]">Jadwal Praktik Faskes</span>
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

          {/* 5. Spesialisasi Klinis Lengkap */}
          {psy.specializations.length > 0 && (
            <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-4">
              <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2">
                <BookOpen className="size-3.5 text-primary" />
                <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
                  Fokus Spesialisasi Klinis ({psy.specializations.length})
                </span>
              </div>
              <div className="mt-2.5 flex flex-wrap gap-1.5">
                {psy.specializations.map((spec) => (
                  <span
                    key={spec}
                    className="rounded-[6px] border border-[#E2E8F0] bg-[#F8FAFC] px-2.5 py-1 text-xs font-medium text-ink"
                  >
                    {spec}
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* 6. Pengaturan Cepat Status Operasional Praktik */}
          <div className="rounded-[12px] border border-slate-200 bg-[#F8FAFC] p-4">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div>
                <p className="font-bold text-ink">Ubah Status Operasional Praktik</p>
                <p className="mt-0.5 text-xs text-ink-muted">
                  Psikolog berstatus aktif dapat didelegasikan rujukan intake DASS-21 faskes.
                </p>
              </div>

              <div className="sm:w-56">
                <select
                  aria-label={`Ubah status operasional ${psy.fullName}`}
                  value={psy.status}
                  onChange={(e) =>
                    onStatusChange(psy.id, e.target.value as PsychologistStatus)
                  }
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink shadow-2xs focus:border-primary focus:outline-none cursor-pointer"
                >
                  <option value="active">Aktif Praktik</option>
                  <option value="on_leave">Sedang Cuti</option>
                  <option value="inactive">Nonaktif</option>
                </select>
              </div>
            </div>
          </div>
        </div>

        {/* Sticky Footer */}
        <div className="flex items-center justify-between border-t border-[#E2E8F0] bg-[#F8FAFC] px-6 py-3.5">
          <button
            type="button"
            onClick={onClose}
            className="h-9 cursor-pointer rounded-[8px] border border-[#CBD5E1] bg-white px-4 text-xs font-semibold text-ink-soft transition-colors hover:bg-slate-50 hover:text-ink focus:outline-none focus:ring-2 focus:ring-primary/20"
          >
            Tutup
          </button>

          <button
            type="button"
            onClick={() => {
              onClose()
              onEdit(psy)
            }}
            className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white transition-colors hover:bg-primary-hover focus:outline-none focus:ring-2 focus:ring-primary/20"
          >
            <Edit3 className="size-3.5" />
            <span>Edit Data Psikolog</span>
          </button>
        </div>
      </div>
    </div>
  )
}

