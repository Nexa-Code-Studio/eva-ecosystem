export type AdminModuleId =
  | 'dashboard'
  | 'psychologists'
  | 'monitoring'
  | 'settings'
  | 'users_coins'
  | 'content_config'

export type DashboardRange = 7 | 30
export type TrendMetric = 'newUsers' | 'voiceSessions' | 'consultations'

export interface DailyPoint {
  date: string // ISO yyyy-mm-dd
  label: string // e.g. "24 Okt"
  newUsers: number
  voiceSessions: number
  consultations: number
}

export interface SparkPoint {
  date: string
  value: number
}

export interface KpiMetric {
  id: 'users' | 'psychologists' | 'sessions' | 'pricing'
  label: string
  value: number
  formattedValue: string
  deltaPct: number | null
  sublabel: string
  spark: SparkPoint[]
  targetModule: AdminModuleId
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
  kind: 'verification' | 'revision' | 'crisis'
  title: string
  subtitle: string
  date: string
  timeAgo: string
  badgeLabel: string
  targetModule: AdminModuleId
}

export interface ActionSummary {
  pendingVerifications: number
  needRevision: number
  crisisUsers: number
  total: number
}

export interface DashboardAnalyticsBaseline {
  baselineUsers: number
  baselineDass: {
    Normal: number
    Mild: number
    Moderate: number
    Severe: number
    Extreme: number
  }
  historySeries: DailyPoint[]
}
