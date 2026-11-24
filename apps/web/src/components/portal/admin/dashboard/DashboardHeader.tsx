import { AlertCircle, ArrowUpRight, Award, CheckCircle2, RefreshCw, ShieldAlert } from 'lucide-react'
import type { ActionSummary } from '@/types/adminDashboard'
import type { AdminModule } from '@/components/portal/admin/AdminSidebarAndKpi'

interface DashboardHeaderProps {
  summary: ActionSummary
  onSelectModule: (mod: AdminModule) => void
}

function getGreeting(): string {
  const hour = new Date().getHours()
  if (hour < 11) return 'Selamat pagi'
  if (hour < 15) return 'Selamat siang'
  if (hour < 18) return 'Selamat sore'
  return 'Selamat malam'
}

function getFormattedDate(): string {
  const days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu']
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ]
  const now = new Date()
  return `${days[now.getDay()]}, ${now.getDate()} ${months[now.getMonth()]} ${now.getFullYear()}`
}

export function DashboardHeader({ summary, onSelectModule }: DashboardHeaderProps) {
  const greeting = getGreeting()
  const dateStr = getFormattedDate()

  return (
    <div className="space-y-4">
      <div className="flex flex-col justify-between gap-1.5 sm:flex-row sm:items-baseline">
        <div className="min-w-0 flex-1">
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            {greeting}, <span className="text-primary">Admin EVA</span>
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Panel kendali verifikasi Psikolog Mandiri, pengaturan tarif platform, dan monitoring sesi telekonsultasi.
          </p>
        </div>
        <div className="shrink-0 text-xs font-medium text-ink-muted sm:text-right">{dateStr}</div>
      </div>

      {summary.total > 0 ? (
        <div className="flex flex-col gap-3 rounded-[12px] border border-[#FDE68A] bg-[#FEF9EE] p-3.5 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-2.5">
            <span className="flex size-7 shrink-0 items-center justify-center rounded-full bg-[#F59E0B]/20 text-[#B45309]">
              <AlertCircle className="size-4" />
            </span>
            <div className="text-xs">
              <span className="font-bold text-[#92400E]">
                {summary.total} item perlu perhatian:
              </span>
              <span className="hidden text-ink-soft sm:inline">
                {' '}
                Periksa berkas STR/SIP psikolog atau pantauan pengguna krisis.
              </span>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {summary.pendingVerifications > 0 && (
              <button
                type="button"
                onClick={() => onSelectModule('psychologists')}
                className="inline-flex cursor-pointer items-center gap-1.5 rounded-[6px] border border-[#FDE68A] bg-white px-2.5 py-1 text-[11px] font-semibold text-[#92400E] shadow-2xs hover:bg-[#FEF3C7]"
              >
                <Award className="size-3 text-[#D97706]" />
                <span>{summary.pendingVerifications} Verifikasi Psikolog</span>
                <ArrowUpRight className="size-3 opacity-60" />
              </button>
            )}

            {summary.needRevision > 0 && (
              <button
                type="button"
                onClick={() => onSelectModule('psychologists')}
                className="inline-flex cursor-pointer items-center gap-1.5 rounded-[6px] border border-[#FDBA74] bg-white px-2.5 py-1 text-[11px] font-semibold text-[#C2410C] shadow-2xs hover:bg-[#FFF7ED]"
              >
                <RefreshCw className="size-3 text-[#EA580C]" />
                <span>{summary.needRevision} Menunggu Revisi</span>
                <ArrowUpRight className="size-3 opacity-60" />
              </button>
            )}

            {summary.crisisUsers > 0 && (
              <button
                type="button"
                onClick={() => onSelectModule('users_coins')}
                className="inline-flex cursor-pointer items-center gap-1.5 rounded-[6px] border border-[#FECACA] bg-[#FEF2F2] px-2.5 py-1 text-[11px] font-semibold text-[#B91C1C] shadow-2xs hover:bg-[#FEE2E2]"
              >
                <ShieldAlert className="size-3 text-[#DC2626]" />
                <span>{summary.crisisUsers} Pantauan Krisis</span>
                <ArrowUpRight className="size-3 opacity-60" />
              </button>
            )}
          </div>
        </div>
      ) : (
        <div className="flex items-center gap-2.5 rounded-[12px] border border-[#BBF7D0] bg-[#F0FDF4] p-3 text-xs font-medium text-[#166534]">
          <CheckCircle2 className="size-4 shrink-0 text-[#16A34A]" />
          <span>Semua verifikasi STR/SIP dan pemantauan selesai diproses.</span>
        </div>
      )}
    </div>
  )
}
