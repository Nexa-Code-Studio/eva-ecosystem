import { useMemo, useState, type FormEvent } from 'react'
import { EMAIL_RE, PHONE_RE } from '@/constants/portal'
import {
  resubmitPartnerApplication,
  submitPartnerApplication,
  usePortalDb,
  type FacilityType,
  type PartnerAccount,
} from '@/lib/portalStore'

export type WizardStep = 1 | 2 | 3

export function usePartnerApplyForm(revisionPartnerId: string | null) {
  const { db } = usePortalDb()

  const revisionTarget = useMemo(
    () => (revisionPartnerId ? db.partners.find((p) => p.id === revisionPartnerId) ?? null : null),
    [db.partners, revisionPartnerId],
  )
  const isRevisionMode = Boolean(revisionTarget)

  const [step, setStep] = useState<WizardStep>(1)
  const [highestReachedStep, setHighestReachedStep] = useState<WizardStep>(isRevisionMode ? 3 : 1)

  const [facilityName, setFacilityName] = useState(revisionTarget?.facilityName ?? '')
  const [facilityType, setFacilityType] = useState<FacilityType>(
    revisionTarget?.facilityType ?? 'Rumah Sakit',
  )
  const [licenseNumber, setLicenseNumber] = useState(revisionTarget?.licenseNumber ?? '')
  const [city, setCity] = useState(revisionTarget?.city ?? '')
  const [address, setAddress] = useState(revisionTarget?.address ?? '')

  const [picName, setPicName] = useState(revisionTarget?.picName ?? '')
  const [picRole, setPicRole] = useState(revisionTarget?.picRole ?? '')
  const [phone, setPhone] = useState(revisionTarget?.phone ?? '')
  const [operatingHours, setOperatingHours] = useState(revisionTarget?.operatingHours ?? '')
  const [estimatedPsychologists, setEstimatedPsychologists] = useState(
    revisionTarget?.estimatedPsychologists !== undefined
      ? String(revisionTarget.estimatedPsychologists)
      : '',
  )
  const [website, setWebsite] = useState(revisionTarget?.website ?? '')
  const [bpjsSupported, setBpjsSupported] = useState(Boolean(revisionTarget?.bpjsSupported))

  const [email, setEmail] = useState(revisionTarget?.email ?? '')
  const [password, setPassword] = useState(revisionTarget?.password ?? '')
  const [showPassword, setShowPassword] = useState(false)
  const [notes, setNotes] = useState(revisionTarget?.notes ?? '')

  const [errors, setErrors] = useState<Record<string, string>>({})
  const [submitting, setSubmitting] = useState(false)
  const [submittedPartner, setSubmittedPartner] = useState<PartnerAccount | null>(null)

  const clearError = (key: string) => {
    if (errors[key]) {
      setErrors((prev) => {
        const next = { ...prev }
        delete next[key]
        return next
      })
    }
  }

  const validateStep = (targetStep: WizardStep): boolean => {
    const nextErrors: Record<string, string> = {}

    if (targetStep === 1) {
      if (!facilityName.trim()) nextErrors.facilityName = 'Nama fasilitas kesehatan wajib diisi.'
      if (!licenseNumber.trim())
        nextErrors.licenseNumber = 'Nomor izin operasional / kode faskes wajib diisi.'
      if (!city.trim()) nextErrors.city = 'Kota / Kabupaten wajib diisi.'
      if (!address.trim()) nextErrors.address = 'Alamat lengkap instansi wajib diisi.'
    }

    if (targetStep === 2) {
      if (!picName.trim()) nextErrors.picName = 'Nama penanggung jawab (PIC) wajib diisi.'
      if (!picRole.trim()) nextErrors.picRole = 'Jabatan penanggung jawab wajib diisi.'
      const cleanPhone = phone.trim().replace(/[\s-]/g, '')
      if (!PHONE_RE.test(cleanPhone))
        nextErrors.phone = 'Masukkan nomor telepon / WhatsApp instansi yang valid.'
    }

    if (targetStep === 3) {
      if (!EMAIL_RE.test(email.trim()))
        nextErrors.email = 'Masukkan alamat email resmi yang valid.'
      if (!password || password.length < 6)
        nextErrors.password = 'Kata sandi akun minimal 6 karakter.'
    }

    setErrors(nextErrors)
    return Object.keys(nextErrors).length === 0
  }

  const handleNextStep = (e?: React.MouseEvent<HTMLButtonElement>) => {
    e?.preventDefault()
    if (!validateStep(step)) return
    const next = (step + 1) as WizardStep
    setErrors({})
    setStep(next)
    if (next > highestReachedStep) setHighestReachedStep(next)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  const handlePrevStep = () => {
    if (step > 1) {
      setErrors({})
      setStep((step - 1) as WizardStep)
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  const handleJumpToStep = (target: WizardStep) => {
    if (target === step) return
    if (target < step || isRevisionMode || target <= highestReachedStep) {
      if (!isRevisionMode && target > step && !validateStep(step)) return
      setErrors({})
      setStep(target)
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  const handleSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (submitting) return
    if (step < 3) {
      handleNextStep()
      return
    }
    if (!validateStep(1)) return setStep(1)
    if (!validateStep(2)) return setStep(2)
    if (!validateStep(3)) return

    const cleanPhone = phone.trim().replace(/[\s-]/g, '')
    const payload = {
      facilityName: facilityName.trim(),
      facilityType,
      licenseNumber: licenseNumber.trim(),
      city: city.trim(),
      address: address.trim(),
      picName: picName.trim(),
      picRole: picRole.trim(),
      phone: cleanPhone,
      email: email.trim(),
      password,
      website: website.trim() || undefined,
      operatingHours: operatingHours.trim() || undefined,
      estimatedPsychologists: estimatedPsychologists
        ? Number.parseInt(estimatedPsychologists, 10)
        : undefined,
      bpjsSupported,
      notes: notes.trim() || undefined,
    }

    setSubmitting(true)
    window.setTimeout(() => {
      if (isRevisionMode && revisionTarget) {
        const updated = resubmitPartnerApplication(revisionTarget.id, payload)
        setSubmitting(false)
        if (updated) {
          setSubmittedPartner(updated)
          window.scrollTo({ top: 0, behavior: 'smooth' })
        }
        return
      }

      const result = submitPartnerApplication(payload)
      setSubmitting(false)
      if (!result.ok) {
        setErrors({ email: result.error })
        return
      }
      setSubmittedPartner(result.partner)
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }, 550)
  }

  return {
    revisionTarget,
    isRevisionMode,
    step,
    setStep,
    highestReachedStep,
    facilityName,
    setFacilityName,
    facilityType,
    setFacilityType,
    licenseNumber,
    setLicenseNumber,
    city,
    setCity,
    address,
    setAddress,
    picName,
    setPicName,
    picRole,
    setPicRole,
    phone,
    setPhone,
    operatingHours,
    setOperatingHours,
    estimatedPsychologists,
    setEstimatedPsychologists,
    website,
    setWebsite,
    bpjsSupported,
    setBpjsSupported,
    email,
    setEmail,
    password,
    setPassword,
    showPassword,
    setShowPassword,
    notes,
    setNotes,
    errors,
    submitting,
    submittedPartner,
    clearError,
    handleNextStep,
    handlePrevStep,
    handleJumpToStep,
    handleSubmit,
  }
}

