import { cn } from '@/lib/cn'
import type { DassDistributionItem } from '@/types/adminDashboard'

interface DassDistributionCardProps {
  data: DassDistributionItem[]
  className?: string
}

export function DassDistributionCard({ data, className }: DassDistributionCardProps) {
  const totalUsers = data.reduce((sum, item) => sum + item.count, 0)
  const clinicalAttentionPct = data
    .filter((d) => d.key === 'Severe' || d.key === 'Extreme')
    .reduce((sum, d) => sum + d.pct, 0)

  return (
    <div className={cn('rounded-[12px] border border-[#E2E8F0] bg-white p-5', className)}>
      <div className="flex items-center justify-between border-b border-[#E2E8F0] pb-3.5">
        <div>
          <h2 className="text-sm font-bold text-ink">Distribusi Skrining DASS-21</h2>
          <p className="text-xs text-ink-muted">
            Tingkat stres, kecemasan, &amp; depresi {totalUsers.toLocaleString('id-ID')} pengguna.
          </p>
        </div>
      </div>

      {/* Multi-segment distribution bar */}
      <div className="mt-4 flex h-3 w-full overflow-hidden rounded-full bg-[#F1F5F9]">
        {data.map((item) => (
          <div
            key={item.key}
            style={{ width: `${item.pct}%`, backgroundColor: item.color }}
            title={`${item.label}: ${item.pct}%`}
            className="h-full transition-all"
          />
        ))}
      </div>

      {/* Itemized severity breakdown list */}
      <div className="mt-4 space-y-2.5">
        {data.map((item) => (
          <div key={item.key} className="flex items-center justify-between text-xs">
            <div className="flex items-center gap-2">
              <span
                className="size-2.5 shrink-0 rounded-full"
                style={{ backgroundColor: item.color }}
              />
              <span className="font-medium text-ink">{item.label}</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="font-semibold text-ink">
                {item.count.toLocaleString('id-ID')}
              </span>
              <span className="w-10 text-right font-mono text-[11px] text-ink-muted">
                {item.pct}%
              </span>
            </div>
          </div>
        ))}
      </div>

      {/* Clinical Attention Summary Footnote */}
      <div className="mt-4 rounded-[8px] border border-[#FECACA] bg-[#FEF2F2]/60 p-2.5 text-center text-xs">
        <span className="font-bold text-[#991B1B]">
          {clinicalAttentionPct}% Membutuhkan Perhatian Klinis
        </span>
        <span className="block text-[11px] text-[#B91C1C]">
          Kategori Berat &amp; Sangat Berat diprioritaskan rujukan ke Psikolog.
        </span>
      </div>
    </div>
  )
}

