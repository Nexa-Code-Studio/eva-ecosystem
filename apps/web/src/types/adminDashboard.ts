import type { AdminModule } from '@/components/portal/admin/AdminSidebarAndKpi'

export type DashboardRange = 7 | 30
export type TrendMetric = 'newUsers' | 'voiceSessions' | 'referrals'

export interface DailyPoint {
  date: string // ISO yyyy-mm-dd
  label: string // e.g. "24 Okt"
  newUsers: number
  voiceSessions: number
  referrals: number
}

export interface SparkPoint {
  date: string
  value: number
}

export interface KpiMetric {
  id: 'users' | 'psychologists' | 'partners' | 'referrals'
  label: string
  value: number
  formattedValue: string
  deltaPct: number | null
  sublabel: string
  spark: SparkPoint[]
  targetModule: AdminModule
}

export interface DassDistributionItem {
  key: string
  label: string
  count: number
  pct: number
  color: string
}

export interface PsychologistCompositionItem {
  name: string
  value: number
  color: string
}

export interface QueueItem {
  id: string
  kind: 'mandiri' | 'faskes' | 'referral'
  title: string
  subtitle: string
  date: string
  timeAgo: string
  badgeLabel: string
  targetModule: AdminModule
}

export interface ActionSummary {
  mandiri: number
  faskes: number
  crisisAndReferral: number
  total: number
}

