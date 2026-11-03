import {
  AlertCircle,
  ArrowUpCircle,
  BookOpen,
  Clock,
  Mail,
  MapPin,
  Phone,
  ShieldCheck,
  Sparkles,
} from 'lucide-react'
import type { PartnerAccount, Psychologist } from '@/types/portal'
import { PsychologistRoleBadge } from '@/components/portal/PortalBadges'

interface PsychologistProfileSidebarProps {
  psy: Psychologist
  partner: PartnerAccount | null
}

export function PsychologistProfileSidebar({
  psy,
  partner,
}: PsychologistProfileSidebarProps) {
  const isMitra = psy.role === 'professional_mitra' || (!psy.role && psy.partnerId)

  return (
    <div className="space-y-3.5 text-xs">
      {/* Rejection Alert if rejected */}
      {psy.rejectionReason && (
        <div className="rounded-[10px] border border-[#FECACA] bg-[#FEF2F2] p-3 text-[#991B1B]">
          <div className="flex items-center gap-1.5 font-bold">
            <AlertCircle className="size-3.5 shrink-0" />
            <span>
              {psy.verificationStatus === 'rejected'
                ? 'Catatan Evaluasi / Penolakan Pendaftaran:'
                : 'Catatan Evaluasi / Penolakan Upgrade:'}
            </span>
          </div>
          <p className="mt-1 text-[11px] leading-relaxed">{psy.rejectionReason}</p>
        </div>
      )}

      {/* Upgrade Pending Banner in Sidebar */}
      {psy.upgradeRequest && (
        <div className="rounded-[10px] border border-amber-300 bg-amber-50 p-3 text-amber-900">
          <div className="flex items-center gap-1.5 font-bold">
            <ArrowUpCircle className="size-4 shrink-0 text-amber-700" />
            <span>Pengajuan Upgrade Menunggu Verifikasi:</span>
          </div>
          <p className="mt-1 text-[11px] font-medium leading-relaxed">
            Mengajukan upgrade ke{' '}
            <strong>
              {psy.upgradeRequest.targetRole === 'relawan_utama' ||
              (psy.upgradeRequest.targetRole as string) === 'relawan_pro'
                ? 'Relawan Utama'
                : 'Relawan Profesional'}
            </strong>{' '}
            pada {psy.upgradeRequest.requestedAt}.
          </p>
        </div>
      )}

      {/* Peran & Status Klasifikasi */}
      <div className="rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5">
        <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
          Peran &amp; Hak Akses
        </span>
        <div className="mt-2 space-y-2">
          <div>
            <PsychologistRoleBadge role={psy.role} isPriorityMobile={psy.isPriorityMobile} />
          </div>

          {(psy.role === 'relawan_utama' || psy.role === 'relawan_pro') && (
            <div className="rounded-[8px] border border-amber-200 bg-amber-50/80 p-2.5 text-[11px] text-amber-900">
              <div className="flex items-center gap-1 font-bold text-amber-800">
                <Sparkles className="size-3 text-amber-600" />
                <span>Prioritas Relawan Utama:</span>
              </div>
              <p className="mt-0.5 text-[10px] leading-relaxed text-amber-800/90">
                Profil tampil di urutan teratas pada daftar konseling aplikasi mobile EVA.
              </p>
            </div>
          )}

          {psy.role === 'relawan_biasa' && (
            <p className="text-[11px] text-ink-muted leading-relaxed">
              Relawan pendamping sebaya. Memenuhi syarat mengajukan upgrade ke <strong>Relawan Utama</strong> atau <strong>Relawan Profesional</strong>.
            </p>
          )}

          {psy.role === 'relawan_profesional' && (
            <p className="text-[11px] text-ink-muted leading-relaxed">
              Psikolog berpendidikan Magister Profesi (S2) dengan izin praktik SIPP dan STR aktif.
            </p>
          )}
        </div>
      </div>

      {/* Kredensial & Afiliasi */}
      <div className="rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5">
        <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
          Kredensial &amp; Afiliasi
        </span>
        <div className="mt-2 space-y-1.5 font-mono text-[11px]">
          <div className="flex items-center justify-between">
            <span className="text-ink-muted">SIPP / ID:</span>
            <span className="font-bold text-ink">{psy.sippNumber}</span>
          </div>
          {psy.strNumber ? (
            <div className="flex items-center justify-between">
              <span className="text-ink-muted">STR:</span>
              <span className="font-bold text-ink">{psy.strNumber}</span>
            </div>
          ) : (
            <div className="flex items-center justify-between">
              <span className="text-ink-muted">STR:</span>
              <span className="font-sans text-[10px] text-ink-muted">
                {isMitra ? 'STR via Faskes' : 'Non-STR (Relawan)'}
              </span>
            </div>
          )}
          <div className="flex items-center justify-between gap-2 pt-1 font-sans">
            <span className="shrink-0 text-ink-muted">Afiliasi:</span>
            <span
              className="max-w-[180px] truncate font-semibold text-primary"
              title={isMitra ? (partner?.facilityName ?? 'Faskes Mitra') : 'Komunitas Relawan EVA'}
            >
              {isMitra ? (partner?.facilityName ?? 'Faskes Mitra') : 'Komunitas Relawan EVA'}
            </span>
          </div>
        </div>
      </div>

      {/* Pendidikan & Pengalaman */}
      <div className="rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5">
        <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
          Pendidikan &amp; Pengalaman
        </span>
        <div className="mt-2 flex items-start gap-2">
          <BookOpen className="size-4 shrink-0 text-primary mt-0.5" />
          <div>
            <p className="font-semibold text-ink leading-tight">
              {psy.education || 'Sarjana / Magister Psikologi'}
            </p>
            <div className="mt-1.5 flex flex-wrap gap-2 text-[11px] text-ink-muted">
              <span className="inline-flex items-center gap-1">
                <ShieldCheck className="size-3 text-[#16A34A]" /> {psy.yearsExperience ?? 3} Tahun Pengalaman
              </span>
              <span>·</span>
              <span>Kuota: {psy.weeklyQuota ?? 10} klien/minggu</span>
            </div>
          </div>
        </div>
      </div>

      {/* Jadwal & Kontak Praktik */}
      <div className="rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5">
        <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
          Jadwal &amp; Kontak Praktik
        </span>
        <div className="mt-2 space-y-2">
          <div className="flex items-center gap-2 text-ink">
            <Clock className="size-3.5 shrink-0 text-ink-muted" />
            <span className="font-medium text-[11px]">{psy.practiceSchedule}</span>
          </div>
          <div className="flex items-center gap-2 text-ink">
            <MapPin className="size-3.5 shrink-0 text-ink-muted" />
            <span className="text-[11px] font-medium">{psy.city ?? 'Indonesia'}</span>
          </div>
          {psy.email && (
            <div className="flex items-center gap-2 text-ink-soft">
              <Mail className="size-3.5 shrink-0 text-ink-muted" />
              <span className="text-[11px] truncate">{psy.email}</span>
            </div>
          )}
          {psy.phone && (
            <div className="flex items-center gap-2 text-ink-soft">
              <Phone className="size-3.5 shrink-0 text-ink-muted" />
              <span className="text-[11px] font-mono">{psy.phone}</span>
            </div>
          )}
        </div>
      </div>

      {/* Spesialisasi Pendampingan */}
      <div className="rounded-[12px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5">
        <span className="text-[10px] font-bold tracking-wider text-ink-muted uppercase">
          Fokus Layanan
        </span>
        <div className="mt-2 flex flex-wrap gap-1.5">
          {psy.specializations.map((spec) => (
            <span
              key={spec}
              className="rounded-[6px] border border-[#CBD5E1] bg-white px-2 py-0.5 text-[11px] font-medium text-ink shadow-2xs"
            >
              {spec}
            </span>
          ))}
        </div>
      </div>
    </div>
  )
}
