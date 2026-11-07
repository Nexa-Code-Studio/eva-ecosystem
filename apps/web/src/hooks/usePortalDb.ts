import { useEffect, useState } from 'react'
import { CHANGE_EVENT, getPortalSession, loadPortalDb } from '@/services/portal/storage'
import type { PortalDatabase, PortalSession } from '@/types/portal'

export function usePortalDb() {
  const [db, setDb] = useState<PortalDatabase>(() => loadPortalDb())
  const [session, setSession] = useState<PortalSession | null>(() => getPortalSession())

  useEffect(() => {
    const sync = () => {
      setDb(loadPortalDb())
      setSession(getPortalSession())
    }
    window.addEventListener(CHANGE_EVENT, sync)
    window.addEventListener('storage', sync)
    return () => {
      window.removeEventListener(CHANGE_EVENT, sync)
      window.removeEventListener('storage', sync)
    }
  }, [])

  return { db, session }
}

