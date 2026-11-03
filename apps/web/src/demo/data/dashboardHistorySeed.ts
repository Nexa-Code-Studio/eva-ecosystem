import { DEMO_CONFIG } from '@/config/demoConfig'
import type { DailyPoint } from '@/types/adminDashboard'

export const BASELINE_USERS = DEMO_CONFIG.useDummySeedData ? 1240 : 0

export const BASELINE_DASS = DEMO_CONFIG.useDummySeedData
  ? {
      Normal: 540,
      Mild: 320,
      Moderate: 215,
      Severe: 115,
      Extreme: 50,
    }
  : {
      Normal: 0,
      Mild: 0,
      Moderate: 0,
      Severe: 0,
      Extreme: 0,
    }

function mulberry32(a: number) {
  return function () {
    let t = (a += 0x6d2b79f5)
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function formatDateIso(d: Date): string {
  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function formatDateLabel(d: Date): string {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des']
  return `${d.getDate()} ${months[d.getMonth()]}`
}

export function buildHistorySeed(today = new Date('2026-10-29T12:00:00Z'), days = 60): DailyPoint[] {
  if (!DEMO_CONFIG.useDummySeedData) {
    return []
  }

  const rand = mulberry32(20261029)
  const result: DailyPoint[] = []

  for (let i = 0; i < days; i++) {
    const d = new Date(today)
    d.setDate(today.getDate() - (days - 1 - i))

    const weekday = d.getDay()
    const weekendFactor = weekday === 0 || weekday === 6 ? 0.72 : 1.05
    const growth = 1 + (i / days) * 0.38

    const newUsers = Math.max(8, Math.round((14 + rand() * 12) * growth * weekendFactor))
    const voiceSessions = Math.max(90, Math.round((180 + rand() * 110) * growth * weekendFactor))
    const referrals = Math.max(0, Math.round((1.2 + rand() * 3.4) * growth))

    result.push({
      date: formatDateIso(d),
      label: formatDateLabel(d),
      newUsers,
      voiceSessions,
      referrals,
    })
  }

  return result
}
