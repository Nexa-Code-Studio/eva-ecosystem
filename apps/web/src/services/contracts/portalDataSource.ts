import type { DashboardAnalyticsBaseline } from '@/types/domain/dashboard'
import type { PortalDatabase, PortalSession } from '@/types/domain/portal'

export interface AdminCredentialConfig {
  email: string
  password?: string
  name: string
}

export interface IPortalDataSource {
  readonly mode: 'mock' | 'remote'
  readonly storageKey: string
  readonly sessionKey: string
  loadSnapshot(): PortalDatabase
  saveSnapshot(db: PortalDatabase): void
  resetSnapshot(): void
  getSession(): PortalSession | null
  setSession(session: PortalSession | null): void
  getDashboardBaseline(): DashboardAnalyticsBaseline
  getAdminAccount(): AdminCredentialConfig
}

