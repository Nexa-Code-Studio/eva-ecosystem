import { APP_CONFIG } from '@/config/appConfig'
import type { IPortalDataSource } from '@/services/contracts/portalDataSource'
import {
  MockPortalDataSource,
  PORTAL_DB_CHANGE_EVENT,
} from '@/services/mock/mockPortalDataSource'
import { RemotePortalDataSource } from '@/services/remote/remotePortalDataSource'
import type { DashboardAnalyticsBaseline } from '@/types/domain/dashboard'
import type { PortalDatabase, PortalSession } from '@/types/domain/portal'

const activeDataSource: IPortalDataSource = APP_CONFIG.useMockData
  ? new MockPortalDataSource()
  : new RemotePortalDataSource()

export const STORAGE_KEY = activeDataSource.storageKey
export const SESSION_KEY = activeDataSource.sessionKey
export const CHANGE_EVENT = PORTAL_DB_CHANGE_EVENT

export function getActivePortalDataSource(): IPortalDataSource {
  return activeDataSource
}

export function isDevToolsEnabled(): boolean {
  return APP_CONFIG.enableDevTools
}

export function loadPortalDb(): PortalDatabase {
  return activeDataSource.loadSnapshot()
}

export function savePortalDb(db: PortalDatabase): void {
  activeDataSource.saveSnapshot(db)
}

export function resetPortalDbToDefault(): void {
  activeDataSource.resetSnapshot()
}

export function getPortalSession(): PortalSession | null {
  return activeDataSource.getSession()
}

export function setPortalSession(session: PortalSession | null): void {
  activeDataSource.setSession(session)
}

export function getDashboardAnalyticsBaseline(): DashboardAnalyticsBaseline {
  return activeDataSource.getDashboardBaseline()
}

export function getAdminAccountConfig() {
  return activeDataSource.getAdminAccount()
}
