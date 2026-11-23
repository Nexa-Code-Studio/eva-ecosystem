import { useMemo } from 'react'
import { getDashboardAnalyticsBaseline, type PortalDatabase } from '@/lib/portalStore'
import type {
  ActionSummary,
  DailyPoint,
  DashboardRange,
  DassDistributionItem,
  KpiMetric,
  PsychologistCompositionItem,
  QueueItem,
  SparkPoint,
} from '@/types/adminDashboard'

export function useAdminDashboardMetrics(db: PortalDatabase, range: DashboardRange) {
  return useMemo(() => {
    const baseline = getDashboardAnalyticsBaseline()
    const basePoints = baseline.historySeries
    const pointMap = new Map<string, DailyPoint>()
    basePoints.forEach((p) => pointMap.set(p.date, { ...p }))

    db.generalUsers.forEach((u) => {
      const dateKey = u.joinedAt?.slice(0, 10)
      if (dateKey && pointMap.has(dateKey)) {
        const pt = pointMap.get(dateKey)!
        pt.newUsers += 1
      }
    })

    db.consultationSessions.forEach((s) => {
      const dateKey = s.scheduledStartTime?.slice(0, 10)
      if (dateKey && pointMap.has(dateKey)) {
        const pt = pointMap.get(dateKey)!
        pt.consultations += 1
      }
    })

    const fullSeries = Array.from(pointMap.values())
    const currentSlice = fullSeries.slice(-range)
    const prevSlice = fullSeries.slice(-range * 2, -range)

    const calcDelta = (curr: number, prev: number): number | null => {
      if (prev <= 0) return null
      return Math.round(((curr - prev) / prev) * 1000) / 10
    }

    const totalUsers = baseline.baselineUsers + db.generalUsers.length
    const currNewUsers = currentSlice.reduce((s, p) => s + p.newUsers, 0)
    const prevNewUsers = prevSlice.reduce((s, p) => s + p.newUsers, 0)
    const usersDelta = calcDelta(currNewUsers, prevNewUsers)

    const verifiedPsy = db.psychologists.filter((p) => p.verificationStatus === 'verified').length
    const pendingPsy = db.psychologists.filter((p) => p.verificationStatus === 'pending').length
    const revisionPsy = 0
    const rejectedPsy = db.psychologists.filter(
      (p) => p.verificationStatus === 'rejected' || p.verificationStatus === 'suspended',
    ).length

    const totalSessions = db.consultationSessions.length
    const extendedSessions = db.consultationSessions.filter(
      (s) => s.isExtended || s.durationMinutes === 60,
    ).length
    const currConsultations = currentSlice.reduce((s, p) => s + p.consultations, 0)
    const prevConsultations = prevSlice.reduce((s, p) => s + p.consultations, 0)
    const sessionsDelta = calcDelta(currConsultations, prevConsultations)

    let cumulativeUsers = totalUsers - currNewUsers
    const usersSpark: SparkPoint[] = currentSlice.map((p) => {
      cumulativeUsers += p.newUsers
      return { date: p.date, value: cumulativeUsers }
    })

    const psySpark: SparkPoint[] = currentSlice.map((p, idx) => ({
      date: p.date,
      value: Math.max(1, verifiedPsy - Math.max(0, Math.floor((range - idx) / 10))),
    }))

    const sessionsSpark: SparkPoint[] = currentSlice.map((p) => ({
      date: p.date,
      value: p.consultations,
    }))

    const pricingSpark: SparkPoint[] = currentSlice.map((p) => ({
      date: p.date,
      value: db.pricingConfig.pricePerSession,
    }))

    const kpis: KpiMetric[] = [
      {
        id: 'users',
        label: 'Total Pengguna App',
        value: totalUsers,
        formattedValue: totalUsers.toLocaleString('id-ID'),
        deltaPct: usersDelta,
        sublabel: `+${currNewUsers} pengguna baru (${range} hari)`,
        spark: usersSpark,
        targetModule: 'users_coins',
      },
      {
        id: 'psychologists',
        label: 'Psikolog Terverifikasi',
        value: verifiedPsy,
        formattedValue: String(verifiedPsy),
        deltaPct: verifiedPsy > 0 ? 12.5 : 0,
        sublabel: `${pendingPsy + revisionPsy} menunggu verifikasi STR/SIP`,
        spark: psySpark,
        targetModule: 'psychologists',
      },
      {
        id: 'sessions',
        label: 'Sesi Telekonsultasi',
        value: totalSessions,
        formattedValue: String(totalSessions),
        deltaPct: sessionsDelta,
        sublabel: `${extendedSessions} sesi diperpanjang (60 menit)`,
        spark: sessionsSpark,
        targetModule: 'monitoring',
      },
      {
        id: 'pricing',
        label: 'Tarif Master (30 Menit)',
        value: db.pricingConfig.pricePerSession,
        formattedValue: `${Math.round(db.pricingConfig.pricePerSession).toLocaleString('id-ID')} Koin`,
        deltaPct: null,
        sublabel: `Split ${db.pricingConfig.counselorSharePercentage}% Psikolog : ${db.pricingConfig.platformFeePercentage}% Platform`,
        spark: pricingSpark,
        targetModule: 'settings',
      },
    ]

    const dassCounts = { ...baseline.baselineDass }
    db.generalUsers.forEach((u) => {
      if (u.lastDassSeverity && dassCounts[u.lastDassSeverity] !== undefined) {
        dassCounts[u.lastDassSeverity] += 1
      }
    })
    const totalDass = Object.values(dassCounts).reduce((a, b) => a + b, 0) || 1

    const dassDistribution: DassDistributionItem[] = [
      { key: 'Normal', label: 'Normal', count: dassCounts.Normal, pct: Math.round((dassCounts.Normal / totalDass) * 100), color: '#2e7d32' },
      { key: 'Mild', label: 'Ringan', count: dassCounts.Mild, pct: Math.round((dassCounts.Mild / totalDass) * 100), color: '#fbc02d' },
      { key: 'Moderate', label: 'Sedang', count: dassCounts.Moderate, pct: Math.round((dassCounts.Moderate / totalDass) * 100), color: '#f57c00' },
      { key: 'Severe', label: 'Berat', count: dassCounts.Severe, pct: Math.round((dassCounts.Severe / totalDass) * 100), color: '#e65100' },
      { key: 'Extreme', label: 'Sangat Berat', count: dassCounts.Extreme, pct: Math.round((dassCounts.Extreme / totalDass) * 100), color: '#d32f2f' },
    ]

    const psychologistComposition: PsychologistCompositionItem[] = [
      { name: 'Terverifikasi Aktif', value: verifiedPsy, color: '#10b981' },
      { name: 'Menunggu Verifikasi', value: pendingPsy, color: '#f59e0b' },
      { name: 'Ditolak / Nonaktif', value: rejectedPsy, color: '#ef4444' },
    ].filter((item) => item.value > 0)

    const crisisUsers = db.generalUsers.filter(
      (u) => u.crisisProtocolTriggered || u.accountStatus === 'flagged_crisis',
    ).length

    const actionSummary: ActionSummary = {
      pendingVerifications: pendingPsy,
      needRevision: 0,
      crisisUsers,
      total: pendingPsy + crisisUsers,
    }

    const queue: QueueItem[] = []

    db.psychologists
      .filter((p) => p.verificationStatus === 'pending')
      .forEach((p) => {
        queue.push({
          id: `psy-${p.id}`,
          kind: 'verification',
          title: `${p.fullName}, ${p.titleDegree}`,
          subtitle: `${p.strNumber ? `STR ${p.strNumber}` : `SIP ${p.sipNumber ?? '-'}`} · ${p.documents?.length ?? 0} dokumen`,
          date: p.submittedAt,
          timeAgo: 'Baru',
          badgeLabel: 'Verifikasi STR/SIP',
          targetModule: 'psychologists',
        })
      })

    db.generalUsers
      .filter((u) => u.crisisProtocolTriggered || u.accountStatus === 'flagged_crisis')
      .forEach((u) => {
        queue.push({
          id: `crisis-${u.id}`,
          kind: 'crisis',
          title: `${u.displayName} (${u.userCode})`,
          subtitle: `Pantauan Krisis · DASS-21: ${u.lastDassSeverity} · Kota ${u.city}`,
          date: u.lastActiveAt.slice(0, 10),
          timeAgo: 'Krisis',
          badgeLabel: 'Pantauan Krisis',
          targetModule: 'users_coins',
        })
      })

    queue.sort((a, b) => b.date.localeCompare(a.date))
    const recentQueue = queue.slice(0, 5)

    return {
      rangeSeries: currentSlice,
      kpis,
      dassDistribution,
      psychologistComposition,
      actionSummary,
      recentQueue,
    }
  }, [db, range])
}
