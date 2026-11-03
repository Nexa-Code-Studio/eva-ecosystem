import {
  ArrowUpCircle,
  Building2,
  Crown,
  GraduationCap,
  HeartHandshake,
  Users,
} from 'lucide-react'
import { cn } from '@/lib/cn'

export type PsyFilterTab =
  | 'all'
  | 'mitra'
  | 'relawan_profesional'
  | 'relawan_utama'
  | 'relawan'
  | 'relawan_pro' // legacy alias
  | 'relawan_biasa' // legacy alias
  | 'pending_action'

export interface PsychologistKpiCounts {
  total: number
  mitra: number
  relawanProfesional: number
  relawanUtama: number
  relawan: number
  pendingAction: number
  pendingVerifikasi: number
  pendingUpgrade: number
  // Legacy aliases
  relawanPro?: number
  relawanBiasa?: number
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
      id: 'all' as PsyFilterTab,
      label: 'Semua Terdaftar',
      value: counts.total,
      sublabel: `${counts.mitra} Mitra · ${counts.relawanProfesional + counts.relawanUtama + counts.relawan} Relawan`,
      icon: <Users className="size-4 text-primary" />,
      accentBorder: 'hover:border-primary/50',
      activeClass: 'border-primary ring-1 ring-primary/20 bg-[#EEF0FF]/30',
    },
    {
      id: 'mitra' as PsyFilterTab,
      label: 'Profesional Mitra',
      value: counts.mitra,
      sublabel: 'RS / Klinik Faskes Mitra',
      icon: <Building2 className="size-4 text-emerald-600" />,
      accentBorder: 'hover:border-emerald-500/50',
      activeClass: 'border-emerald-500 ring-1 ring-emerald-500/20 bg-emerald-50/40',
    },
    {
      id: 'relawan_profesional' as PsyFilterTab,
      label: 'Relawan Profesional',
      value: counts.relawanProfesional,
      sublabel: 'Profesi S2 Psikolog + SIPP',
      icon: <GraduationCap className="size-4 text-indigo-600" />,
      accentBorder: 'hover:border-indigo-500/50',
      activeClass: 'border-indigo-500 ring-1 ring-indigo-500/20 bg-indigo-50/40',
    },
    {
      id: 'relawan_utama' as PsyFilterTab,
      label: 'Relawan Utama',
      value: counts.relawanUtama,
      sublabel: 'Prioritas Tampil di Mobile',
      icon: <Crown className="size-4 text-amber-500" />,
      accentBorder: 'hover:border-amber-500/50',
      activeClass: 'border-amber-400 ring-1 ring-amber-400/20 bg-amber-50/40',
    },
    {
      id: 'relawan' as PsyFilterTab,
      label: 'Relawan',
      value: counts.relawan,
      sublabel: 'Pendampingan Konseling Sebaya',
      icon: <HeartHandshake className="size-4 text-sky-600" />,
      accentBorder: 'hover:border-sky-500/50',
      activeClass: 'border-sky-500 ring-1 ring-sky-500/20 bg-sky-50/40',
    },
    {
      id: 'pending_action' as PsyFilterTab,
      label: 'Antrean Tindakan',
      value: counts.pendingAction,
      sublabel: `${counts.pendingVerifikasi} baru · ${counts.pendingUpgrade} upgrade`,
      icon: <ArrowUpCircle className="size-4 text-[#D97706]" />,
      valueClass: counts.pendingAction > 0 ? 'text-[#B45309]' : 'text-ink',
      accentBorder: 'hover:border-[#F59E0B]/50',
      activeClass: 'border-[#F59E0B] ring-1 ring-[#F59E0B]/20 bg-[#FEF3C7]/40',
    },
  ]

  return (
    <div className="hidden gap-3 sm:grid sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-6">
      {cards.map((card) => {
        const isActive = activeFilter === card.id
        return (
          <button
            key={card.id}
            type="button"
            onClick={() => onSelectFilter(card.id)}
            className={cn(
              'group flex cursor-pointer flex-col justify-between rounded-[12px] border border-[#E2E8F0] bg-white p-3.5 text-left transition-all',
              card.accentBorder,
              isActive ? card.activeClass : 'hover:bg-[#F8FAFC]',
            )}
          >
            <div className="flex items-center justify-between gap-1">
              <span className="line-clamp-1 text-xs font-semibold text-ink-muted group-hover:text-ink">
                {card.label}
              </span>
              <span className="flex size-7 shrink-0 items-center justify-center rounded-[8px] bg-[#F8FAFC]">
                {card.icon}
              </span>
            </div>

            <div className="mt-2">
              <span className={cn('text-2xl font-bold tracking-tight text-ink', card.valueClass)}>
                {card.value}
              </span>
              <p className="mt-0.5 line-clamp-1 text-[10px] text-ink-muted">{card.sublabel}</p>
            </div>
          </button>
        )
      })}
    </div>
  )
}
