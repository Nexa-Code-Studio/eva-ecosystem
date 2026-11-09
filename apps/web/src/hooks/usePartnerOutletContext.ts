import { useOutletContext } from 'react-router'
import type { PartnerDashboardState } from './usePartnerDashboard'

export function usePartnerOutletContext() {
  return useOutletContext<PartnerDashboardState>()
}
