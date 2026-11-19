import { useMemo, useState, type FormEvent } from 'react'
import {
  EMAIL_RE,
  PHONE_RE,
  PROFESSIONAL_ASSOCIATIONS,
} from '@/constants/portal'
import {
  registerPsychologistApplication,
  resubmitPsychologistApplication,
  usePortalDb,
  type Psychologist,
} from '@/lib/portalStore'

export type WizardStep = 1 | 2 | 3

export function usePsychologistApplyForm(revisionPsyId: string | null) {
  const { db } = usePortalDb()

  const revisionTarget = useMemo(
    () => (revisionPsyId ? db.psychologists.find((p) => p.id === revisionPsyId) ?? null : null),
    [db.psychologists, revisionPsyId],
  )
  const isRevisionMode = Boolean(revisionTarget)

  const [step, setStep] = useState<WizardStep>(1)
  const [highestReachedStep, setHighestReachedStep] = useState<WizardStep>(isRevisionMode ? 3 : 1)

  const [fullName, setFullName] = useState(revisionTarget?.fullName ?? '')
  const [titleDegree, setTitleDegree] = useState(
    revisionTarget?.titleDegree ?? 'M.Psi., Psikolog',
  )
  const [city, setCity] = useState(revisionTarget?.city ?? '')
  const [education, setEducation] = useState(revisionTarget?.education ?? '')
  const [yearsOfExperience, setYearsOfExperience] = useState(
    revisionTarget ? String(revisionTarget.yearsOfExperience) : '3',
  )
  const [specializations, setSpecializations] = useState<string[]>(
    revisionTarget?.specializations ?? ['Kecemasan & Panik'],
  )
  const [bio, setBio] = useState(revisionTarget?.bio ?? '')

  const [strNumber, setStrNumber] = useState(revisionTarget?.strNumber ?? '')
  const [sipNumber, setSipNumber] = useState(revisionTarget?.sipNumber ?? '')
  const [association, setAssociation] = useState(
    revisionTarget?.association ?? PROFESSIONAL_ASSOCIATIONS[0],
  )
  const [certificateDocUrl, setCertificateDocUrl] = useState(
    revisionTarget?.certificateDocUrl ?? '',
  )
  const [practiceSchedule, setPracticeSchedule] = useState(
    revisionTarget?.practiceSchedule ?? 'Senin - Jumat (18.00 - 21.00 WIB)',
  )

  const [email, setEmail] = useState(revisionTarget?.email ?? '')
  const [phone, setPhone] = useState(revisionTarget?.phone ?? '')
  const [password, setPassword] = useState(revisionTarget?.password ?? '')
  const [showPassword, setShowPassword] = useState(false)

  const [errors, setErrors] = useState<Record<string, string>>({})
  const [submitting, setSubmitting] = useState(false)
  const [submittedPsychologist, setSubmittedPsychologist] = useState<Psychologist | null>(null)

  const clearError = (key: string) => {
    if (errors[key]) {
      setErrors((prev) => {
        const next = { ...prev }
        delete next[key]
        return next
      })
    }
  }

  const toggleSpecialization = (spec: string) => {
    setSpecializations((prev) =>
      prev.includes(spec) ? prev.filter((item) => item !== spec) : [...prev, spec],
    )
    clearError('specializations')
  }

  const validateStep = (targetStep: WizardStep): boolean => {
    const nextErrors: Record<string, string> = {}

    if (targetStep === 1) {
      if (fullName.trim().length < 2) {
        nextErrors.fullName = 'Nama lengkap psikolog wajib diisi (minimal 2 karakter).'
      }
      if (!titleDegree.trim()) {
        nextErrors.titleDegree = 'Gelar profesi wajib diisi (contoh: M.Psi., Psikolog).'
      }
      if (!city.trim()) {
        nextErrors.city = 'Domisili kota/kabupaten wajib diisi.'
      }
      const parsedExp = Number.parseInt(yearsOfExperience, 10)
      if (Number.isNaN(parsedExp) || parsedExp < 0) {
        nextErrors.yearsOfExperience = 'Pengalaman praktik harus berupa angka >= 0.'
      }
      if (specializations.length === 0) {
        nextErrors.specializations = 'Pilih minimal 1 spesialisasi klinis.'
      }
    }

    if (targetStep === 2) {
      if (strNumber.trim().length < 3) {
        nextErrors.strNumber = 'Nomor STR wajib diisi (minimal 3 karakter).'
      }
      if (!association.trim()) {
        nextErrors.association = 'Asosiasi profesi wajib dipilih.'
      }
      if (!practiceSchedule.trim()) {
        nextErrors.practiceSchedule = 'Preferensi jadwal praktik online wajib diisi.'
      }
    }

    if (targetStep === 3) {
      if (!EMAIL_RE.test(email.trim())) {
        nextErrors.email = 'Masukkan alamat email profesional yang valid.'
      }
      if (phone.trim()) {
        const cleanPhone = phone.trim().replace(/[\s-]/g, '')
        if (!PHONE_RE.test(cleanPhone)) {
          nextErrors.phone = 'Format nomor WhatsApp/telepon Indonesia tidak valid.'
        }
      }
      if (!isRevisionMode && (!password || password.length < 8)) {
        nextErrors.password = 'Kata sandi akun minimal 8 karakter.'
      }
      if (isRevisionMode && password && password.length < 8) {
        nextErrors.password = 'Kata sandi akun minimal 8 karakter.'
      }
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

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (submitting) return
    if (step < 3) {
      handleNextStep()
      return
    }
    if (!validateStep(1)) return setStep(1)
    if (!validateStep(2)) return setStep(2)
    if (!validateStep(3)) return

    setSubmitting(true)
    const cleanPhone = phone.trim().replace(/[\s-]/g, '')
    const payload = {
      full_name: fullName.trim(),
      title_degree: titleDegree.trim(),
      email: email.trim(),
      password,
      str_number: strNumber.trim().toUpperCase(),
      sip_number: sipNumber.trim() ? sipNumber.trim().toUpperCase() : null,
      association: association.trim(),
      specializations,
      years_of_experience: Math.max(0, Number.parseInt(yearsOfExperience, 10) || 0),
      bio: bio.trim() || null,
      certificate_doc_url: certificateDocUrl.trim() || null,
      phone: cleanPhone || undefined,
      city: city.trim().toUpperCase(),
      education: education.trim() || undefined,
      practice_schedule: practiceSchedule.trim(),
    }

    if (isRevisionMode && revisionTarget) {
      const updated = resubmitPsychologistApplication(revisionTarget.id, payload)
      setSubmitting(false)
      if (!updated) {
        setErrors({ email: 'Data pengajuan revisi tidak ditemukan.' })
        return
      }
      setSubmittedPsychologist(updated)
      window.scrollTo({ top: 0, behavior: 'smooth' })
      return
    }

    const result = await registerPsychologistApplication(payload)
    setSubmitting(false)

    if (!result.ok) {
      setErrors({ email: result.error })
      return
    }

    setSubmittedPsychologist(result.psychologist)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  return {
    isRevisionMode,
    revisionTarget,
    step,
    setStep,
    highestReachedStep,
    fullName,
    setFullName,
    titleDegree,
    setTitleDegree,
    city,
    setCity,
    education,
    setEducation,
    yearsOfExperience,
    setYearsOfExperience,
    specializations,
    toggleSpecialization,
    bio,
    setBio,
    strNumber,
    setStrNumber,
    sipNumber,
    setSipNumber,
    association,
    setAssociation,
    certificateDocUrl,
    setCertificateDocUrl,
    practiceSchedule,
    setPracticeSchedule,
    email,
    setEmail,
    phone,
    setPhone,
    password,
    setPassword,
    showPassword,
    setShowPassword,
    errors,
    submitting,
    submittedPsychologist,
    clearError,
    handleNextStep,
    handlePrevStep,
    handleJumpToStep,
    handleSubmit,
  }
}
