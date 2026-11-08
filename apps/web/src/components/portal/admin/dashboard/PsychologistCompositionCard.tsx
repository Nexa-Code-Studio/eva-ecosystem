import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts'
import { cn } from '@/lib/cn'
import type { PsychologistCompositionItem } from '@/types/adminDashboard'

interface PsychologistCompositionCardProps {
  data: PsychologistCompositionItem[]
  className?: string
}

interface CustomPieTooltipProps {
  active?: boolean
  payload?: Array<{ payload: PsychologistCompositionItem }>
}

function CustomPieTooltip({ active, payload }: CustomPieTooltipProps) {
  if (active && payload && payload.length) {
    const item = payload[0].payload
    return (
      <div className="rounded-[8px] border border-[#CBD5E1] bg-white p-2 shadow-md">
        <p className="text-xs font-bold text-ink">{item.name}</p>
        <p className="mt-0.5 text-xs text-ink-muted">
          Jumlah: <span className="font-semibold text-primary">{item.value}</span> psikolog
        </p>
      </div>
    )
  }
  return null
}

export function PsychologistCompositionCard({
  data,
  className,
}: PsychologistCompositionCardProps) {
  const total = data.reduce((sum, item) => sum + item.value, 0)

  return (
    <div className={cn('flex flex-col justify-between rounded-[12px] border border-[#E2E8F0] bg-white p-5', className)}>
      <div>
        <div className="border-b border-[#E2E8F0] pb-3.5">
          <h2 className="text-sm font-bold text-ink">Komposisi Psikolog &amp; Relawan</h2>
          <p className="text-xs text-ink-muted">
            Distribusi psikolog mitra faskes, relawan terdaftar, dan antrean verifikasi.
          </p>
        </div>

        {/* Donut Chart with Centered Total */}
        <div className="relative mt-2 flex h-44 items-center justify-center">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Tooltip content={<CustomPieTooltip />} />
              <Pie
                data={data}
                dataKey="value"
                nameKey="name"
                cx="50%"
                cy="50%"
                innerRadius={46}
                outerRadius={66}
                paddingAngle={3}
              >
                {data.map((entry) => (
                  <Cell key={entry.name} fill={entry.color} stroke="#FFFFFF" strokeWidth={2} />
                ))}
              </Pie>
            </PieChart>
          </ResponsiveContainer>

          <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center text-center">
            <span className="text-xl font-bold text-ink">{total}</span>
            <span className="text-[10px] font-semibold text-ink-muted">Total</span>
          </div>
        </div>
      </div>

      {/* Legend */}
      <div className="mt-2 space-y-2 border-t border-[#E2E8F0] pt-3">
        {data.map((item) => {
          const pct = total > 0 ? Math.round((item.value / total) * 100) : 0
          return (
            <div key={item.name} className="flex items-center justify-between text-xs">
              <div className="flex items-center gap-2">
                <span className="size-2.5 shrink-0 rounded-full" style={{ backgroundColor: item.color }} />
                <span className="text-ink-soft">{item.name}</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="font-semibold text-ink">{item.value}</span>
                <span className="w-8 text-right font-mono text-[11px] text-ink-muted">{pct}%</span>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

