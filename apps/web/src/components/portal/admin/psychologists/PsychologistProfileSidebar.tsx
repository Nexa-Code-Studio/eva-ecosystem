import {
  AlertCircle,
  BookOpen,
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
import type { PartnerAccount, Psychologist } from '@/types/portal'
import {
  PsychologistRoleBadge,
  UpgradeRequestBadge,
} from '@/components/portal/PortalBadges'
import { PsychologistShieldBadge } from '@/components/portal/PsychologistShieldBadge'

interface PsychologistProfileSidebarProps {
  psy: Psychologist
  partner: PartnerAccount | null
}

export function PsychologistProfileSidebar({
  psy,
  partner,
}: PsychologistProfileSidebarProps) {
  const isMitra = psy.role === 'professional_mitra' || (!psy.role && psy.partnerId)
  const feeCoins = psy.sessionFeeCoins ?? (psy.role === 'relawan_biasa' ? 0 : 100)
  const durationMinutes =
    psy.sessionDurationMinutes ?? (psy.role === 'relawan_biasa' ? 30 : 45)

  // Inisial nama untuk avatar
  const initials = psy.fullName
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join('')

  return (
    <div className="space-y-4 text-xs">
      {/* Rejection Alert if rejected */}
      {psy.rejectionReason && (
        <div className="rounded-[12px] border border-[#FECACA] bg-[#FEF2F2] p-3.5 text-[#991B1B]">
          <div className="flex items-center gap-1.5 font-bold">
            <AlertCircle className="size-4 shrink-0 text-[#DC2626]" />
            <span>
              {psy.verificationStatus === 'rejected'
                ? 'Catatan Evaluasi / Penolakan Pendaftaran:'
                : 'Catatan Evaluasi / Penolakan Upgrade:'}
            </span>
          </div>
          <p className="mt-1 text-[11px] leading-relaxed">{psy.rejectionReason}</p>
        </div>
      )}

      {/* Profile Header Block: Avatar, Nama, Role & Domisili */}
      <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-4 shadow-2xs">
        <div className="flex items-start gap-3.5">
          <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-bold text-primary ring-2 ring-primary/20">
            {initials || <User className="size-5" />}
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <h3 className="text-base font-bold text-ink" title={psy.fullName}>
                {psy.fullName}
              </h3>
              <PsychologistShieldBadge
                role={psy.role}
                partnerName={partner?.facilityName}
                upgradeRequest={psy.upgradeRequest}
                verificationStatus={psy.verificationStatus}
              />
            </div>
            <div className="mt-1 flex flex-wrap items-center gap-1.5">
              <PsychologistRoleBadge
                role={psy.role}
                verificationStatus={psy.verificationStatus}
              />
              {psy.verificationStatus === 'pending' && !isMitra && (
                <span className="inline-flex items-center gap-1 rounded-[6px] border border-amber-300 bg-amber-50 px-2 py-0.5 text-[10px] font-bold text-amber-900">
                  Pendaftaran Baru (Menunggu Verifikasi)
                </span>
              )}
              {psy.upgradeRequest && psy.verificationStatus === 'approved' && (
                <UpgradeRequestBadge request={psy.upgradeRequest} />
              )}
            </div>
            <div className="mt-2 flex items-center gap-1 text-[11px] text-ink-muted">
              <MapPin className="size-3 shrink-0 text-ink-muted/80" />
              <span>{psy.city ?? 'Indonesia'}</span>
              <span>·</span>
              <span className="truncate">
                {isMitra
                  ? (partner?.facilityName ?? 'Faskes Mitra')
                  : psy.verificationStatus === 'pending'
                    ? 'Pendaftaran Relawan Baru'
                    : 'Praktik Mandiri / Relawan'}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Highlight Card: Tarif, Durasi & Kuota Rujukan */}
      <div className="rounded-[14px] border border-amber-200/80 bg-amber-50/35 p-3.5 shadow-2xs">
        <div className="flex items-center justify-between">
          <span className="text-[10px] font-bold tracking-wider text-amber-900 uppercase">
            Tarif &amp; Layanan Sesi
          </span>
          <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[9.5px] font-bold text-amber-800">
            Koin EVA
          </span>
        </div>

        <div className="mt-3 grid grid-cols-2 gap-2">
          <div className="rounded-[10px] border border-amber-200/60 bg-white/90 p-2.5">
            <span className="block text-[10px] text-amber-800/80">Biaya per Sesi</span>
            <div className="mt-1 flex items-center gap-1.5 font-bold text-amber-950">
              <Coins className="size-4 shrink-0 text-amber-600" />
              <span className="text-sm">
                {feeCoins === 0 ? 'Gratis' : `${feeCoins} Koin`}
              </span>
            </div>
          </div>

          <div className="rounded-[10px] border border-amber-200/60 bg-white/90 p-2.5">
            <span className="block text-[10px] text-amber-800/80">Durasi Sesi</span>
            <div className="mt-1 flex items-center gap-1.5 font-bold text-amber-950">
              <Clock className="size-4 shrink-0 text-amber-600" />
              <span className="text-sm">{durationMinutes} Menit</span>
            </div>
          </div>
        </div>

        <div className="mt-2.5 flex items-center justify-between border-t border-amber-200/60 pt-2 text-[11px] text-amber-900">
          <span className="inline-flex items-center gap-1">
            <Users className="size-3 text-amber-700" /> Kuota Rujukan Klien:
          </span>
          <span className="font-bold">{psy.weeklyQuota ?? 10} klien / minggu</span>
        </div>
      </div>

      {/* Seksi Kredensial Legalitas */}
      <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 shadow-2xs">
        <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2">
          <ShieldCheck className="size-3.5 text-primary" />
          <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
            Kredensial &amp; Legalitas
          </span>
        </div>

        <div className="mt-2.5 space-y-2 text-[11px]">
          <div className="flex items-center justify-between">
            <span className="text-ink-muted">Nomor SIPP:</span>
            <span className="font-mono font-bold text-ink">{psy.sippNumber}</span>
          </div>

          <div className="flex items-center justify-between">
            <span className="text-ink-muted">Nomor STR:</span>
            {psy.strNumber ? (
              <span className="font-mono font-bold text-ink">{psy.strNumber}</span>
            ) : (
              <span className="text-ink-muted">
                {isMitra ? 'STR via Faskes' : 'Non-STR (Relawan)'}
              </span>
            )}
          </div>

          <div className="flex items-center justify-between gap-2">
            <span className="shrink-0 text-ink-muted">Afiliasi:</span>
            <span
              className="truncate font-semibold text-primary"
              title={isMitra ? (partner?.facilityName ?? 'Faskes Mitra') : 'Komunitas Relawan EVA'}
            >
              {isMitra ? (partner?.facilityName ?? 'Faskes Mitra') : 'Komunitas Relawan EVA'}
            </span>
          </div>
        </div>
      </div>

      {/* Seksi Pendidikan, Pengalaman & Praktik */}
      <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 shadow-2xs">
        <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2">
          <GraduationCap className="size-3.5 text-indigo-600" />
          <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
            Pendidikan &amp; Pengalaman
          </span>
        </div>

        <div className="mt-2.5 space-y-2 text-[11px]">
          <div>
            <span className="text-ink-muted block text-[10px]">Pendidikan Terakhir</span>
            <p className="mt-0.5 font-semibold text-ink">
              {psy.education || 'Sarjana / Magister Psikologi'}
            </p>
          </div>

          <div className="flex items-center justify-between pt-1">
            <span className="text-ink-muted">Pengalaman Klinis:</span>
            <span className="font-bold text-ink">
              {psy.yearsExperience ?? 3} Tahun Praktik
            </span>
          </div>
        </div>
      </div>

      {/* Seksi Jadwal & Kontak */}
      <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 shadow-2xs">
        <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2">
          <Calendar className="size-3.5 text-teal-600" />
          <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
            Jadwal &amp; Kontak
          </span>
        </div>

        <div className="mt-2.5 space-y-2 text-[11px]">
          <div className="flex items-start gap-2">
            <Clock className="size-3.5 shrink-0 text-ink-muted mt-0.5" />
            <div>
              <span className="text-ink-muted block text-[10px]">Jadwal Praktik</span>
              <span className="font-semibold text-ink">{psy.practiceSchedule}</span>
            </div>
          </div>

          {psy.email && (
            <div className="flex items-center gap-2 pt-1">
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

      {/* Seksi Fokus Layanan & Spesialisasi */}
      {psy.specializations.length > 0 && (
        <div className="rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 shadow-2xs">
          <div className="flex items-center gap-1.5 border-b border-[#E2E8F0] pb-2">
            <BookOpen className="size-3.5 text-primary" />
            <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
              Fokus Layanan Klinis
            </span>
          </div>
          <div className="mt-2.5 flex flex-wrap gap-1.5">
            {psy.specializations.map((spec) => (
              <span
                key={spec}
                className="rounded-[6px] border border-[#E2E8F0] bg-[#F8FAFC] px-2 py-0.5 text-[10.5px] font-medium text-ink shadow-2xs"
              >
                {spec}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
