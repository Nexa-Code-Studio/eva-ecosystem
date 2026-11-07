import { useMemo, useState, type FormEvent } from 'react'
import {
  CLINICAL_SPECIALIZATIONS,
  updatePartnerFacilityProfile,
  upsertPsychologist,
  usePortalDb,
  type FacilityType,
  type Psychologist,
  type PsychologistStatus,
} from '@/lib/portalStore'

export type PartnerTab = 'psychologists' | 'referrals' | 'profile'

export function usePartnerDashboard() {
  const { db, session } = usePortalDb()

  const partner = useMemo(() => {
    if (session?.partnerId) {
      const found = db.partners.find((p) => p.id === session.partnerId)
      if (found) return found
    }
    return db.partners.find((p) => p.status === 'approved') ?? db.partners[0]
  }, [db.partners, session])

  const [activeTab, setActiveTab] = useState<PartnerTab>('psychologists')
  const [banner, setBanner] = useState<string | null>(null)

  const [psySearch, setPsySearch] = useState('')
  const [psyStatusFilter, setPsyStatusFilter] = useState<'all' | PsychologistStatus>('all')

  const [modalOpen, setModalOpen] = useState(false)
  const [editingPsy, setEditingPsy] = useState<Psychologist | null>(null)
  const [fullName, setFullName] = useState('')
  const [sippNumber, setSippNumber] = useState('')
  const [selectedSpecs, setSelectedSpecs] = useState<string[]>([])
  const [practiceSchedule, setPracticeSchedule] = useState('')
  const [psyStatus, setPsyStatus] = useState<PsychologistStatus>('active')
  const [weeklyQuota, setWeeklyQuota] = useState('')
  const [yearsExperience, setYearsExperience] = useState('')
  const [education, setEducation] = useState('')
  const [psyErrors, setPsyErrors] = useState<Record<string, string>>({})

  const [profFacilityName, setProfFacilityName] = useState(partner?.facilityName ?? '')
  const [profFacilityType, setProfFacilityType] = useState<FacilityType>(
    partner?.facilityType ?? 'Rumah Sakit',
  )
  const [profLicense, setProfLicense] = useState(partner?.licenseNumber ?? '')
  const [profCity, setProfCity] = useState(partner?.city ?? '')
  const [profAddress, setProfAddress] = useState(partner?.address ?? '')
  const [profPicName, setProfPicName] = useState(partner?.picName ?? '')
  const [profPicRole, setProfPicRole] = useState(partner?.picRole ?? '')
  const [profPhone, setProfPhone] = useState(partner?.phone ?? '')
  const [profOperatingHours, setProfOperatingHours] = useState(partner?.operatingHours ?? '')
  const [profWebsite, setProfWebsite] = useState(partner?.website ?? '')
  const [profBpjs, setProfBpjs] = useState(Boolean(partner?.bpjsSupported))
  const [profAccepting, setProfAccepting] = useState(Boolean(partner?.acceptingReferrals))
  const [profNotes, setProfNotes] = useState(partner?.notes ?? '')

  const psychologists = useMemo(
    () => (partner ? db.psychologists.filter((p) => p.partnerId === partner.id) : []),
    [db.psychologists, partner],
  )

  const filteredPsychologists = useMemo(() => {
    const q = psySearch.trim().toLowerCase()
    return psychologists.filter((p) => {
      if (psyStatusFilter !== 'all' && p.status !== psyStatusFilter) return false
      if (!q) return true
      return (
        p.fullName.toLowerCase().includes(q) ||
        p.sippNumber.toLowerCase().includes(q) ||
        p.specializations.some((s) => s.toLowerCase().includes(q))
      )
    })
  }, [psychologists, psySearch, psyStatusFilter])

  const referrals = useMemo(
    () => (partner ? db.referrals.filter((r) => r.partnerId === partner.id) : []),
    [db.referrals, partner],
  )

  const openAddModal = () => {
    setEditingPsy(null)
    setFullName('')
    setSippNumber('')
    setSelectedSpecs([CLINICAL_SPECIALIZATIONS[0]])
    setPracticeSchedule('')
    setPsyStatus('active')
    setWeeklyQuota('')
    setYearsExperience('')
    setEducation('')
    setPsyErrors({})
    setModalOpen(true)
  }

  const openEditModal = (psy: Psychologist) => {
    setEditingPsy(psy)
    setFullName(psy.fullName)
    setSippNumber(psy.sippNumber)
    setSelectedSpecs(psy.specializations)
    setPracticeSchedule(psy.practiceSchedule)
    setPsyStatus(psy.status)
    setWeeklyQuota(psy.weeklyQuota !== undefined ? String(psy.weeklyQuota) : '')
    setYearsExperience(psy.yearsExperience !== undefined ? String(psy.yearsExperience) : '')
    setEducation(psy.education ?? '')
    setPsyErrors({})
    setModalOpen(true)
  }

  const toggleSpecialization = (spec: string) => {
    setSelectedSpecs((prev) =>
      prev.includes(spec) ? prev.filter((item) => item !== spec) : [...prev, spec],
    )
    if (psyErrors.specializations) setPsyErrors((p) => ({ ...p, specializations: '' }))
  }

  const handleSavePsychologist = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!partner) return

    const errs: Record<string, string> = {}
    if (!fullName.trim()) errs.fullName = 'Nama lengkap dan gelar psikolog wajib diisi.'
    if (!sippNumber.trim()) errs.sippNumber = 'Nomor SIPP / STR wajib diisi.'
    if (selectedSpecs.length === 0) errs.specializations = 'Pilih minimal 1 spesialisasi klinis.'
    if (!practiceSchedule.trim()) errs.practiceSchedule = 'Hari & jam praktik wajib diisi.'

    setPsyErrors(errs)
    if (Object.keys(errs).length > 0) return

    upsertPsychologist({
      id: editingPsy?.id,
      partnerId: partner.id,
      fullName: fullName.trim(),
      sippNumber: sippNumber.trim(),
      specializations: selectedSpecs,
      practiceSchedule: practiceSchedule.trim(),
      status: psyStatus,
      weeklyQuota: weeklyQuota ? Number.parseInt(weeklyQuota, 10) : undefined,
      yearsExperience: yearsExperience ? Number.parseInt(yearsExperience, 10) : undefined,
      education: education.trim() || undefined,
    })

    setModalOpen(false)
    setBanner(
      editingPsy
        ? `Data psikolog "${fullName.trim()}" berhasil diperbarui.`
        : `Psikolog "${fullName.trim()}" berhasil ditambahkan ke daftar praktik faskes.`,
    )
  }

  const handleSaveProfile = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!partner) return

    updatePartnerFacilityProfile(partner.id, {
      facilityName: profFacilityName.trim() || partner.facilityName,
      facilityType: profFacilityType,
      licenseNumber: profLicense.trim() || partner.licenseNumber,
      city: profCity.trim() || partner.city,
      address: profAddress.trim() || partner.address,
      picName: profPicName.trim() || partner.picName,
      picRole: profPicRole.trim() || partner.picRole,
      phone: profPhone.trim() || partner.phone,
      operatingHours: profOperatingHours.trim() || undefined,
      website: profWebsite.trim() || undefined,
      bpjsSupported: profBpjs,
      acceptingReferrals: profAccepting,
      notes: profNotes.trim() || undefined,
    })
    setBanner('Profil dan status operasional fasilitas kesehatan berhasil disimpan.')
  }

  return {
    partner,
    activeTab,
    setActiveTab,
    banner,
    setBanner,
    psySearch,
    setPsySearch,
    psyStatusFilter,
    setPsyStatusFilter,
    modalOpen,
    setModalOpen,
    editingPsy,
    fullName,
    setFullName,
    sippNumber,
    setSippNumber,
    selectedSpecs,
    practiceSchedule,
    setPracticeSchedule,
    psyStatus,
    setPsyStatus,
    weeklyQuota,
    setWeeklyQuota,
    yearsExperience,
    setYearsExperience,
    education,
    setEducation,
    psyErrors,
    setPsyErrors,
    profFacilityName,
    setProfFacilityName,
    profFacilityType,
    setProfFacilityType,
    profLicense,
    setProfLicense,
    profCity,
    setProfCity,
    profAddress,
    setProfAddress,
    profPicName,
    setProfPicName,
    profPicRole,
    setProfPicRole,
    profPhone,
    setProfPhone,
    profOperatingHours,
    setProfOperatingHours,
    profWebsite,
    setProfWebsite,
    profBpjs,
    setProfBpjs,
    profAccepting,
    setProfAccepting,
    profNotes,
    setProfNotes,
    psychologists,
    filteredPsychologists,
    referrals,
    openAddModal,
    openEditModal,
    toggleSpecialization,
    handleSavePsychologist,
    handleSaveProfile,
  }
}

