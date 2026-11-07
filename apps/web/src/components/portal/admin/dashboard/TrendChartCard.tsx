import { useState } from 'react'
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { cn } from '@/lib/cn'
import type { DailyPoint, DashboardRange, TrendMetric } from '@/types/adminDashboard'

interface TrendChartCardProps {
  series: DailyPoint[]
  range: DashboardRange
  onRangeChange: (range: DashboardRange) => void
  className?: string
}

interface CustomTooltipProps {
  active?: boolean
  payload?: Array<{ value: number }>
  label?: string
  metricLabel: string
  unit: string
}

function CustomTooltip({ active, payload, label, metricLabel, unit }: CustomTooltipProps) {
  if (active && payload && payload.length) {
    return (
      <div className="rounded-[8px] border border-[#CBD5E1] bg-white p-2.5 shadow-md">
        <p className="text-[11px] font-semibold text-ink-muted">{label}</p>
        <p className="mt-1 text-xs font-bold text-ink">
          {metricLabel}: <span className="text-primary">{payload[0].value.toLocaleString('id-ID')}</span> {unit}
        </p>
      </div>
    )
  }
  return null
}

export function TrendChartCard({
  series,
  range,
  onRangeChange,
  className,
}: TrendChartCardProps) {
  const [metric, setMetric] = useState<TrendMetric>('newUsers')

  const metricConfig: Record<TrendMetric, { label: string; unit: string; color: string }> = {
    newUsers: { label: 'Pengguna Baru', unit: 'pengguna', color: '#5358cb' },
    voiceSessions: { label: 'Sesi Suara AI', unit: 'sesi', color: '#6c63ff' },
    referrals: { label: 'Rujukan DASS-21', unit: 'pasien', color: '#10b981' },
  }

  const activeConf = metricConfig[metric]
  const totalInPeriod = series.reduce((sum, pt) => sum + pt[metric], 0)

  return (
    <div className={cn('rounded-[12px] border border-[#E2E8F0] bg-white p-5', className)}>
      <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-sm font-bold text-ink">Tren Aktivitas Layanan</h2>
            <span className="rounded-[5px] bg-[#EEF0FF] px-2 py-0.5 text-[10px] font-bold text-primary">
              Total {totalInPeriod.toLocaleString('id-ID')} {activeConf.unit}
            </span>
          </div>
          <p className="text-xs text-ink-muted">
            Volume interaksi pengguna pada aplikasi mobile EVA.
          </p>
        </div>

        {/* 7d / 30d Toggle */}
        <div className="inline-flex rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-1">
          <button
            type="button"
            onClick={() => onRangeChange(7)}
            className={cn(
              'cursor-pointer rounded-[6px] px-2.5 py-1 text-xs font-semibold transition-colors',
              range === 7 ? 'bg-white text-ink shadow-2xs' : 'text-ink-muted hover:text-ink',
            )}
          >
            7 Hari
          </button>
          <button
            type="button"
            onClick={() => onRangeChange(30)}
            className={cn(
              'cursor-pointer rounded-[6px] px-2.5 py-1 text-xs font-semibold transition-colors',
              range === 30 ? 'bg-white text-ink shadow-2xs' : 'text-ink-muted hover:text-ink',
            )}
          >
            30 Hari
          </button>
        </div>
      </div>

      {/* Metric Tabs */}
      <div className="mt-4 flex flex-wrap gap-1.5 border-b border-[#E2E8F0] pb-3">
        {(['newUsers', 'voiceSessions', 'referrals'] as const).map((mKey) => (
          <button
            key={mKey}
            type="button"
            onClick={() => setMetric(mKey)}
            className={cn(
              'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
              metric === mKey
                ? 'bg-primary text-white'
                : 'border border-[#CBD5E1] bg-white text-ink-soft hover:bg-[#F8FAFC] hover:text-ink',
            )}
          >
            {metricConfig[mKey].label}
          </button>
        ))}
      </div>

      {/* Main Area Chart */}
      <div className="mt-4 h-64 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={series} margin={{ top: 10, right: 10, left: -15, bottom: 0 }}>
            <defs>
              <linearGradient id="trendAreaGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={activeConf.color} stopOpacity={0.28} />
                <stop offset="100%" stopColor={activeConf.color} stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#F1F5F9" />
            <XAxis
              dataKey="label"
              tickLine={false}
              axisLine={{ stroke: '#E2E8F0' }}
              tick={{ fontSize: 11, fill: '#9EA0AB' }}
            />
            <YAxis
              tickLine={false}
              axisLine={false}
              tick={{ fontSize: 11, fill: '#9EA0AB' }}
              width={40}
            />
            <Tooltip
              content={
                <CustomTooltip
                  metricLabel={activeConf.label}
                  unit={activeConf.unit}
                />
              }
            />
            <Area
              type="monotone"
              dataKey={metric}
              stroke={activeConf.color}
              strokeWidth={2.4}
              fill="url(#trendAreaGradient)"
              activeDot={{ r: 5, fill: activeConf.color, stroke: '#FFFFFF', strokeWidth: 2 }}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}

