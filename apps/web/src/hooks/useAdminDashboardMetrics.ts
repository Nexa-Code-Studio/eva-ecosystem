import { useMemo } from 'react'
import type { PortalDatabase } from '@/types/portal'
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
import {
  BASELINE_DASS,
  BASELINE_USERS,
  buildHistorySeed,
} from '@/demo/data/dashboardHistorySeed'

export function useAdminDashboardMetrics(db: PortalDatabase, range: DashboardRange) {
  return useMemo(() => {
    // 1. Combine deterministic 60-day seed with real store events
    const basePoints = buildHistorySeed()
    const pointMap = new Map<string, DailyPoint>()
    basePoints.forEach((p) => pointMap.set(p.date, { ...p }))

    // Add real users from db to matching date point
    db.generalUsers.forEach((u) => {
      const dateKey = u.joinedAt?.slice(0, 10)
      if (dateKey && pointMap.has(dateKey)) {
        const pt = pointMap.get(dateKey)!
        pt.newUsers += 1
      }
    })

    // Add real referrals from db to matching date point
    db.referrals.forEach((r) => {
      const dateKey = r.submittedAt?.slice(0, 10)
      if (dateKey && pointMap.has(dateKey)) {
        const pt = pointMap.get(dateKey)!
        pt.referrals += 1
      }
    })

    const fullSeries = Array.from(pointMap.values())
    const currentSlice = fullSeries.slice(-range)
    const prevSlice = fullSeries.slice(-range * 2, -range)

    // Helper for percentage delta
    const calcDelta = (curr: number, prev: number): number | null => {
      if (prev <= 0) return null
      return Math.round(((curr - prev) / prev) * 1000) / 10
    }

    // 2. Metrics calculation
    const totalUsers = BASELINE_USERS + db.generalUsers.length
    const currNewUsers = currentSlice.reduce((s, p) => s + p.newUsers, 0)
    const prevNewUsers = prevSlice.reduce((s, p) => s + p.newUsers, 0)
    const usersDelta = calcDelta(currNewUsers, prevNewUsers)

    const approvedRelawan = db.psychologists.filter(
      (p) => (p.role !== 'professional_mitra' && p.practiceType === 'mandiri') && p.verificationStatus === 'approved',
    ).length
    const approvedMitra = db.psychologists.filter(
      (p) => (p.role === 'professional_mitra' || p.practiceType !== 'mandiri') && p.verificationStatus === 'approved',
    ).length
    const verifiedPsyTotal = approvedRelawan + approvedMitra
    const pendingPsyAction = db.psychologists.filter(
      (p) => p.verificationStatus === 'pending' || Boolean(p.upgradeRequest),
    ).length

    const approvedPartners = db.partners.filter((p) => p.status === 'approved').length
    const pendingPartners = db.partners.filter((p) => p.status === 'pending').length

    const currReferrals = currentSlice.reduce((s, p) => s + p.referrals, 0)
    const prevReferrals = prevSlice.reduce((s, p) => s + p.referrals, 0)
    const referralsDelta = calcDelta(currReferrals, prevReferrals)

    // Sparklines (range-based)
    let cumulativeUsers = totalUsers - currNewUsers
    const usersSpark: SparkPoint[] = currentSlice.map((p) => {
      cumulativeUsers += p.newUsers
      return { date: p.date, value: cumulativeUsers }
    })

    const psySpark: SparkPoint[] = currentSlice.map((p, idx) => ({
      date: p.date,
      value: Math.max(1, verifiedPsyTotal - Math.max(0, Math.floor((range - idx) / 8))),
    }))

    const partnersSpark: SparkPoint[] = currentSlice.map((p, idx) => ({
      date: p.date,
      value: Math.max(1, approvedPartners - Math.max(0, Math.floor((range - idx) / 14))),
    }))

    const referralsSpark: SparkPoint[] = currentSlice.map((p) => ({
      date: p.date,
      value: p.referrals,
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
        targetModule: 'users_referrals',
      },
      {
        id: 'psychologists',
        label: 'Psikolog & Relawan',
        value: verifiedPsyTotal,
        formattedValue: String(verifiedPsyTotal),
        deltaPct: approvedRelawan > 0 ? 12.5 : 0,
        sublabel: `${approvedMitra} Mitra · ${approvedRelawan} Relawan`,
        spark: psySpark,
        targetModule: 'psychologists',
      },
      {
        id: 'partners',
        label: 'Mitra Faskes Aktif',
        value: approvedPartners,
        formattedValue: String(approvedPartners),
        deltaPct: null,
        sublabel: `${pendingPartners} pengajuan menunggu`,
        spark: partnersSpark,
        targetModule: 'partners',
      },
      {
        id: 'referrals',
        label: `Rujukan Masuk (${range}H)`,
        value: currReferrals,
        formattedValue: String(currReferrals),
        deltaPct: referralsDelta,
        sublabel: `${db.referrals.filter((r) => r.status === 'unassigned').length} belum ditugaskan`,
        spark: referralsSpark,
        targetModule: 'users_referrals',
      },
    ]

    // 3. DASS-21 Distribution
    const dassCounts = { ...BASELINE_DASS }
    db.generalUsers.forEach((u) => {
      if (u.lastDassSeverity && dassCounts[u.lastDassSeverity] !== undefined) {
        dassCounts[u.lastDassSeverity] += 1
      }
    })
    const totalDass = Object.values(dassCounts).reduce((a, b) => a + b, 0)

    const dassDistribution: DassDistributionItem[] = [
      { key: 'Normal', label: 'Normal', count: dassCounts.Normal, pct: Math.round((dassCounts.Normal / totalDass) * 100), color: '#2e7d32' },
      { key: 'Mild', label: 'Ringan', count: dassCounts.Mild, pct: Math.round((dassCounts.Mild / totalDass) * 100), color: '#fbc02d' },
      { key: 'Moderate', label: 'Sedang', count: dassCounts.Moderate, pct: Math.round((dassCounts.Moderate / totalDass) * 100), color: '#f57c00' },
      { key: 'Severe', label: 'Berat', count: dassCounts.Severe, pct: Math.round((dassCounts.Severe / totalDass) * 100), color: '#e65100' },
      { key: 'Extreme', label: 'Sangat Berat', count: dassCounts.Extreme, pct: Math.round((dassCounts.Extreme / totalDass) * 100), color: '#d32f2f' },
    ]

    // 4. Psychologist Composition (Roles & Action Queue)
    const isPending = (p: (typeof db.psychologists)[number]) =>
      p.verificationStatus === 'pending' || Boolean(p.upgradeRequest)

    const mitraCount = db.psychologists.filter(
      (p) => (p.role === 'professional_mitra' || (!p.role && p.partnerId)) && !isPending(p),
    ).length
    const relawanProfCount = db.psychologists.filter(
      (p) =>
        (p.role === 'relawan_profesional' ||
          (!p.role && !p.partnerId && p.practiceType === 'mandiri')) &&
        !isPending(p),
    ).length
    const relawanUtamaCount = db.psychologists.filter(
      (p) => (p.role === 'relawan_utama' || p.role === 'relawan_pro') && !isPending(p),
    ).length
    const relawanCount = db.psychologists.filter(
      (p) => (p.role === 'relawan_biasa' || (p.role as string) === 'relawan') && !isPending(p),
    ).length

    const psychologistComposition: PsychologistCompositionItem[] = [
      { name: 'Profesional Mitra', value: mitraCount, color: '#10b981' },
      { name: 'Relawan Profesional', value: relawanProfCount, color: '#6366f1' },
      { name: 'Relawan Utama', value: relawanUtamaCount, color: '#f59e0b' },
      { name: 'Relawan', value: relawanCount, color: '#0ea5e9' },
      { name: 'Antrean Tindakan', value: pendingPsyAction, color: '#ef4444' },
    ].filter((item) => item.value > 0)

    // 5. Action Summary
    const crisisUsers = db.generalUsers.filter(
      (u) => u.crisisProtocolTriggered || u.accountStatus === 'flagged_crisis',
    ).length
    const unassignedRefs = db.referrals.filter((r) => r.status === 'unassigned').length

    const actionSummary: ActionSummary = {
      mandiri: pendingPsyAction,
      faskes: pendingPartners,
      crisisAndReferral: crisisUsers + unassignedRefs,
      total: pendingPsyAction + pendingPartners + crisisUsers + unassignedRefs,
    }

    // 6. Recent Action Queue (max 5 items, mixed types)
    const queue: QueueItem[] = []

    db.psychologists
      .filter((p) => p.verificationStatus === 'pending' || Boolean(p.upgradeRequest))
      .forEach((p) => {
        const isUpgrade = Boolean(p.upgradeRequest)
        const targetLabel =
          p.upgradeRequest?.targetRole === 'relawan_utama' ||
          (p.upgradeRequest?.targetRole as string) === 'relawan_pro'
            ? 'Relawan Utama'
            : 'Relawan Profesional'
        queue.push({
          id: `psy-${p.id}`,
          kind: 'mandiri',
          title: p.fullName,
          subtitle: isUpgrade
            ? `Pengajuan Upgrade ke ${targetLabel} (${p.upgradeRequest?.requestedAt ?? 'Baru'})`
            : `${p.city ?? 'Indonesia'} · ${p.documents?.length ?? 0} berkas sertifikat verifikasi`,
          date: isUpgrade ? (p.upgradeRequest?.requestedAt ?? '2026-10-31') : (p.submittedAt ?? '2026-10-29'),
          timeAgo: isUpgrade ? 'Upgrade' : 'Baru',
          badgeLabel: isUpgrade ? `Upgrade: ${targetLabel}` : 'Verifikasi Relawan',
          targetModule: 'psychologists',
        })
      })

    db.partners
      .filter((p) => p.status === 'pending')
      .forEach((p) => {
        queue.push({
          id: `partner-${p.id}`,
          kind: 'faskes',
          title: p.facilityName,
          subtitle: `${p.facilityType} · ${p.city} · Izin: ${p.licenseNumber}`,
          date: p.submittedAt,
          timeAgo: p.isResubmitted ? 'Perbaikan' : 'Menunggu',
          badgeLabel: 'Mitra Faskes',
          targetModule: 'partners',
        })
      })

    db.referrals
      .filter((r) => r.status === 'unassigned')
      .forEach((r) => {
        queue.push({
          id: `ref-${r.id}`,
          kind: 'referral',
          title: `Rujukan Pasien ${r.patientCode} (${r.gender}, ${r.age} th)`,
          subtitle: `DASS-21: ${r.dass21.severity} (D:${r.dass21.depression} / A:${r.dass21.anxiety} / S:${r.dass21.stress})`,
          date: r.submittedAt,
          timeAgo: 'Prioritas',
          badgeLabel: 'Rujukan Baru',
          targetModule: 'users_referrals',
        })
      })

    // Sort by date descending and take top 5
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

