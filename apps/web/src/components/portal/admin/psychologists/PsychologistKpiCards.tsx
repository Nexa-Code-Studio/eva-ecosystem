import {
  CheckCircle2,
  Clock,
  Users,
  XCircle,
} from 'lucide-react'
import { cn } from '@/lib/cn'

export type PsyFilterTab =
  | 'pending_review'
  | 'all'
  | 'verified'
  | 'rejected'

export interface PsychologistKpiCounts {
  total: number
  pending: number
  verified: number
  rejected: number
  pendingReview: number
}

interface PsychologistKpiCardsProps {
  counts: PsychologistKpiCounts
  activeFilter: PsyFilterTab
  onSelectFilter: (filter: PsyFilterTab) => void
}

export function PsychologistKpiCards({
  counts,
  activeFilter,
  onSelectFilter,
}: PsychologistKpiCardsProps) {
  const cards = [
    {
      id: 'pending_review' as PsyFilterTab,
      label: 'Antrean Verifikasi',
      value: counts.pendingReview,
      sublabel: `${counts.pending} pendaftar baru`,
      icon: <Clock className="size-4 text-[#D97706]" />,
      valueClass: counts.pendingReview > 0 ? 'text-[#B45309]' : 'text-ink',
      accentBorder: 'hover:border-[#F59E0B]/50',
      activeClass: 'border-[#F59E0B] ring-1 ring-[#F59E0B]/20 bg-[#FEF3C7]/40',
    },
    {
      id: 'all' as PsyFilterTab,
      label: 'Semua Psikolog',
      value: counts.total,
      sublabel: 'Kategori Psikolog Mandiri',
      icon: <Users className="size-4 text-primary" />,
      accentBorder: 'hover:border-primary/50',
      activeClass: 'border-primary ring-1 ring-primary/20 bg-[#EEF0FF]/30',
    },
    {
      id: 'verified' as PsyFilterTab,
      label: 'Terverifikasi Aktif',
      value: counts.verified,
      sublabel: 'STR/SIP disetujui',
      icon: <CheckCircle2 className="size-4 text-emerald-600" />,
      accentBorder: 'hover:border-emerald-500/50',
      activeClass: 'border-emerald-500 ring-1 ring-emerald-500/20 bg-emerald-50/40',
    },
    {
      id: 'rejected' as PsyFilterTab,
      label: 'Ditolak / Nonaktif',
      value: counts.rejected,
      sublabel: 'Tidak memenuhi syarat',
      icon: <XCircle className="size-4 text-rose-600" />,
      accentBorder: 'hover:border-rose-500/50',
      activeClass: 'border-rose-500 ring-1 ring-rose-500/20 bg-rose-50/40',
    },
  ]

  return (
    <div className="hidden gap-3 sm:grid sm:grid-cols-2 lg:grid-cols-4">
      {cards.map((card) => {
        const isActive = activeFilter === card.id
        return (
          <button
            key={card.id}
            type="button"
            onClick={() => onSelectFilter(card.id)}
            className={cn(
              'flex cursor-pointer flex-col justify-between rounded-[12px] border bg-white p-4 text-left transition-all',
              isActive
                ? card.activeClass
                : cn('border-[#E2E8F0] hover:shadow-xs', card.accentBorder),
            )}
          >
            <div className="flex items-center justify-between gap-2">
              <span className="text-[11px] font-semibold text-ink-muted">{card.label}</span>
              {card.icon}
            </div>
            <div className="mt-2.5">
              <p className={cn('text-2xl font-bold tracking-tight', card.valueClass ?? 'text-ink')}>
                {card.value}
              </p>
              <p className="mt-0.5 text-[11px] text-ink-muted">{card.sublabel}</p>
            </div>
          </button>
        )
      })}
    </div>
  )
}
