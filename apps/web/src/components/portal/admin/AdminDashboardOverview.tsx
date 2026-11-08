import { useState } from 'react'
import type { PortalDatabase } from '@/types/portal'
import type { DashboardRange } from '@/types/adminDashboard'
import type { AdminModule } from '@/components/portal/admin/AdminSidebarAndKpi'
import { useAdminDashboardMetrics } from '@/hooks/useAdminDashboardMetrics'
import { DashboardHeader } from './dashboard/DashboardHeader'
import { KpiCard } from './dashboard/KpiCard'
import { TrendChartCard } from './dashboard/TrendChartCard'
import { DassDistributionCard } from './dashboard/DassDistributionCard'
import { RecentQueueCard } from './dashboard/RecentQueueCard'
import { PsychologistCompositionCard } from './dashboard/PsychologistCompositionCard'

interface AdminDashboardOverviewProps {
  db: PortalDatabase
  onSelectModule: (mod: AdminModule) => void
}

export function AdminDashboardOverview({
  db,
  onSelectModule,
}: AdminDashboardOverviewProps) {
  const [range, setRange] = useState<DashboardRange>(30)
  const metrics = useAdminDashboardMetrics(db, range)

  return (
    <div className="space-y-6">
      {/* Layer 1: Greeting, Date, & Urgent Action Banner */}
      <DashboardHeader
        summary={metrics.actionSummary}
        onSelectModule={onSelectModule}
      />

      {/* Layer 2: 4 Health & Growth KPI Cards with Sparklines */}
      <div className="grid grid-cols-1 gap-3.5 sm:grid-cols-2 xl:grid-cols-4">
        {metrics.kpis.map((kpi) => (
          <KpiCard key={kpi.id} metric={kpi} onSelect={onSelectModule} />
        ))}
      </div>

      {/* Layer 3: Analytics & Priority Queue Grid */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        {/* Row 1: Interactive Trend Chart (8 cols) + DASS-21 Distribution (4 cols) */}
        <TrendChartCard
          className="lg:col-span-8"
          series={metrics.rangeSeries}
          range={range}
          onRangeChange={setRange}
        />
        <DassDistributionCard
          className="lg:col-span-4"
          data={metrics.dassDistribution}
        />

        {/* Row 2: Recent Action Queue (8 cols) + Psychologist Composition Donut (4 cols) */}
        <RecentQueueCard
          className="lg:col-span-8"
          items={metrics.recentQueue}
          onSelectModule={onSelectModule}
        />
        <PsychologistCompositionCard
          className="lg:col-span-4"
          data={metrics.psychologistComposition}
        />
      </div>
    </div>
  )
}
