import { useEffect, useRef, useState } from 'react'
import {
  CHANGE_EVENT,
  SESSION_KEY,
  STORAGE_KEY,
  getPortalSession,
  loadPortalDb,
} from '@/services/portal/storage'
import type { PortalDatabase, PortalSession } from '@/types/portal'

function readRawStorageKey(key: string): string | null {
  if (typeof window === 'undefined') return null
  return window.localStorage.getItem(key)
}

export function usePortalDb() {
  const [db, setDb] = useState<PortalDatabase>(() => loadPortalDb())
  const [session, setSession] = useState<PortalSession | null>(() => getPortalSession())
  const lastDbRawRef = useRef<string | null>(readRawStorageKey(STORAGE_KEY))
  const lastSessionRawRef = useRef<string | null>(readRawStorageKey(SESSION_KEY))

  useEffect(() => {
    const sync = () => {
      const nextDbRaw = readRawStorageKey(STORAGE_KEY)
      if (nextDbRaw !== lastDbRawRef.current) {
        lastDbRawRef.current = nextDbRaw
        setDb(loadPortalDb())
      }

      const nextSessionRaw = readRawStorageKey(SESSION_KEY)
      if (nextSessionRaw !== lastSessionRawRef.current) {
        lastSessionRawRef.current = nextSessionRaw
        setSession(getPortalSession())
      }
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

