import { ArrowDownRight, ArrowUpRight } from 'lucide-react'
import { Area, AreaChart, ResponsiveContainer } from 'recharts'
import { cn } from '@/lib/cn'
import type { KpiMetric } from '@/types/adminDashboard'
import type { AdminModule } from '@/components/portal/admin/AdminSidebarAndKpi'

interface KpiCardProps {
  metric: KpiMetric
  onSelect: (mod: AdminModule) => void
}

export function KpiCard({ metric, onSelect }: KpiCardProps) {
  const isPositive = metric.deltaPct !== null && metric.deltaPct > 0
  const isNegative = metric.deltaPct !== null && metric.deltaPct < 0
  const chartGradientId = `grad-${metric.id}`

  return (
    <button
      type="button"
      onClick={() => onSelect(metric.targetModule)}
      className="group flex cursor-pointer flex-col justify-between rounded-[12px] border border-[#E2E8F0] bg-white p-4 text-left transition-all hover:border-primary/40 hover:shadow-subtle"
    >
      <div>
        <div className="flex items-center justify-between">
          <span className="text-xs font-semibold text-ink-muted group-hover:text-ink">
            {metric.label}
          </span>
          {metric.deltaPct !== null && (
            <span
              className={cn(
                'inline-flex items-center gap-0.5 rounded-[5px] px-1.5 py-0.5 text-[10px] font-bold',
                isPositive && 'bg-[#F0FDF4] text-[#166534]',
                isNegative && 'bg-[#FEF2F2] text-[#991B1B]',
                !isPositive && !isNegative && 'bg-[#F1F5F9] text-ink-muted',
              )}
            >
              {isPositive && <ArrowUpRight className="size-3" />}
              {isNegative && <ArrowDownRight className="size-3" />}
              {isPositive ? `+${metric.deltaPct}%` : `${metric.deltaPct}%`}
            </span>
          )}
        </div>

        <div className="mt-2 text-2xl font-bold tracking-tight text-ink sm:text-3xl">
          {metric.formattedValue}
        </div>
        <p className="mt-0.5 text-[11px] text-ink-muted">{metric.sublabel}</p>
      </div>

      {/* Mini Sparkline Chart */}
      <div className="mt-3 h-9 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={metric.spark} margin={{ top: 2, right: 2, left: 2, bottom: 2 }}>
            <defs>
              <linearGradient id={chartGradientId} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#5358cb" stopOpacity={0.3} />
                <stop offset="100%" stopColor="#5358cb" stopOpacity={0} />
              </linearGradient>
            </defs>
            <Area
              type="monotone"
              dataKey="value"
              stroke="#5358cb"
              strokeWidth={1.8}
              fill={`url(#${chartGradientId})`}
              isAnimationActive={false}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </button>
  )
}

