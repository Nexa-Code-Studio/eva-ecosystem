import {
  ArrowRight,
  Award,
  CheckCircle2,
  ChevronRight,
  RefreshCw,
  ShieldAlert,
} from 'lucide-react'
import { cn } from '@/lib/cn'
import type { QueueItem } from '@/types/adminDashboard'
import type { AdminModule } from '@/components/portal/admin/AdminSidebarAndKpi'

interface RecentQueueCardProps {
  items: QueueItem[]
  onSelectModule: (mod: AdminModule) => void
  className?: string
}

export function RecentQueueCard({
  items,
  onSelectModule,
  className,
}: RecentQueueCardProps) {
  const getKindIcon = (kind: QueueItem['kind']) => {
    if (kind === 'verification') return <Award className="size-4 text-[#D97706]" />
    if (kind === 'revision') return <RefreshCw className="size-4 text-[#EA580C]" />
    return <ShieldAlert className="size-4 text-[#DC2626]" />
  }

  const getBadgeStyle = (kind: QueueItem['kind']) => {
    if (kind === 'verification') return 'bg-[#FEF3C7] text-[#92400E] border-[#FDE68A]'
    if (kind === 'revision') return 'bg-[#FFF7ED] text-[#C2410C] border-[#FDBA74]'
    return 'bg-[#FEF2F2] text-[#991B1B] border-[#FECACA]'
  }

  return (
    <div className={cn('rounded-[12px] border border-[#E2E8F0] bg-white p-5', className)}>
      <div className="flex items-center justify-between border-b border-[#E2E8F0] pb-3.5">
        <div>
          <h2 className="text-sm font-bold text-ink">Antrean Tindakan Terbaru</h2>
          <p className="text-xs text-ink-muted">
            Pendaftaran psikolog mandiri dan pantauan pengguna krisis yang memerlukan tinjauan.
          </p>
        </div>
      </div>

      {items.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-8 text-center">
          <CheckCircle2 className="size-8 text-[#16A34A]" />
          <p className="mt-2 text-xs font-semibold text-ink">Tidak ada antrean tertunda</p>
          <p className="text-[11px] text-ink-muted">
            Semua pengajuan verifikasi psikolog selesai diproses.
          </p>
        </div>
      ) : (
        <div className="mt-3 divide-y divide-[#E2E8F0]">
          {items.map((item) => (
            <button
              key={item.id}
              type="button"
              onClick={() => onSelectModule(item.targetModule)}
              className="group flex w-full cursor-pointer items-center justify-between gap-3 py-3 text-left transition-colors hover:bg-[#F8FAFC]"
            >
              <div className="flex items-start gap-3">
                <span className="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-[8px] border border-[#E2E8F0] bg-white shadow-2xs">
                  {getKindIcon(item.kind)}
                </span>
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <span
                      className={cn(
                        'rounded-[5px] border px-2 py-0.5 text-[10px] font-bold',
                        getBadgeStyle(item.kind),
                      )}
                    >
                      {item.badgeLabel}
                    </span>
                    <span className="text-xs font-semibold text-ink group-hover:text-primary">
                      {item.title}
                    </span>
                  </div>
                  <p className="mt-0.5 line-clamp-1 text-[11px] text-ink-muted">{item.subtitle}</p>
                </div>
              </div>

              <div className="flex shrink-0 items-center gap-2">
                <span className="hidden font-mono text-[11px] text-ink-muted sm:inline">
                  {item.timeAgo}
                </span>
                <ChevronRight className="size-4 text-ink-muted transition-transform group-hover:translate-x-0.5 group-hover:text-primary" />
              </div>
            </button>
          ))}
        </div>
      )}

      <div className="mt-4 flex flex-wrap items-center justify-between gap-2 border-t border-[#E2E8F0] pt-3 text-xs">
        <span className="text-ink-muted">Navigasi cepat:</span>
        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={() => onSelectModule('psychologists')}
            className="inline-flex cursor-pointer items-center gap-1 font-semibold text-primary hover:underline"
          >
            Verifikasi Psikolog <ArrowRight className="size-3" />
          </button>
          <span className="text-[#CBD5E1]">·</span>
          <button
            type="button"
            onClick={() => onSelectModule('settings')}
            className="inline-flex cursor-pointer items-center gap-1 font-semibold text-primary hover:underline"
          >
            Pengaturan Tarif <ArrowRight className="size-3" />
          </button>
          <span className="text-[#CBD5E1]">·</span>
          <button
            type="button"
            onClick={() => onSelectModule('monitoring')}
            className="inline-flex cursor-pointer items-center gap-1 font-semibold text-primary hover:underline"
          >
            Monitoring Sesi <ArrowRight className="size-3" />
          </button>
        </div>
      </div>
    </div>
  )
}
