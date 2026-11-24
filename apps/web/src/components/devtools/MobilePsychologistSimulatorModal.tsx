import { X } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import {
  CLINICAL_SPECIALIZATIONS,
  EDUCATION_LEVELS,
  PROFESSIONAL_ASSOCIATIONS,
} from '@/constants/portal'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { cn } from '@/lib/cn'
import {
  isDevToolsEnabled,
  simulateMobilePsychologistSubmission,
  type Psychologist,
} from '@/lib/portalStore'

interface MobilePsychologistSimulatorModalProps {
  isOpen: boolean
  onClose: () => void
  onCreated: (created: Psychologist) => void
}

const EXPERIENCE_OPTIONS = [
  { label: '1 - 2 Thn', value: 2 },
  { label: '3 - 5 Thn', value: 3 },
  { label: '6 - 10 Thn', value: 7 },
  { label: '> 10 Thn', value: 10 },
] as const

export function MobilePsychologistSimulatorModal({
  isOpen,
  onClose,
  onCreated,
}: MobilePsychologistSimulatorModalProps) {
  useBodyScrollLock(isOpen)

  const [simFullName, setSimFullName] = useState('')
  const [simTitleDegree, setSimTitleDegree] = useState('M.Psi., Psikolog')
  const [simEmail, setSimEmail] = useState('')
  const [simEducation, setSimEducation] = useState<string>(EDUCATION_LEVELS[0])
  const [simAssociation, setSimAssociation] = useState<string>(PROFESSIONAL_ASSOCIATIONS[0])
  const [simExperienceYears, setSimExperienceYears] = useState<number>(3)
  const [simDocType, setSimDocType] = useState<'both' | 'str' | 'sip'>('both')
  const [simStr, setSimStr] = useState('')
  const [simStrIssuedBy, setSimStrIssuedBy] = useState(
    'Kemenkes RI / KTKI (Konsil Tenaga Kesehatan Indonesia)',
  )
  const [simStrValidUntil, setSimStrValidUntil] = useState('Seumur Hidup (UU Kesehatan No. 17/2023)')
  const [simSipp, setSimSipp] = useState('')
  const [simSipIssuedBy, setSimSipIssuedBy] = useState('Dinas Kesehatan Kabupaten / Kota')
  const [simSipValidUntil, setSimSipValidUntil] = useState('2030-12-31')
  const [simSpecs, setSimSpecs] = useState<string[]>([
    CLINICAL_SPECIALIZATIONS[0],
    CLINICAL_SPECIALIZATIONS[3],
  ])
  const [simError, setSimError] = useState<string | null>(null)

  if (!isDevToolsEnabled() || !isOpen) return null

  const includeStr = simDocType === 'both' || simDocType === 'str'
  const includeSip = simDocType === 'both' || simDocType === 'sip'

  const toggleSpec = (spec: string) => {
    setSimSpecs((prev) =>
      prev.includes(spec) ? prev.filter((item) => item !== spec) : [...prev, spec],
    )
  }

  const handleRegisterSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!simFullName.trim()) {
      setSimError('Nama lengkap wajib diisi.')
      return
    }
    if (includeStr && !simStr.trim()) {
      setSimError('Nomor STR wajib diisi jika memilih dokumen STR.')
      return
    }
    if (includeSip && !simSipp.trim()) {
      setSimError('Nomor SIP / SIPP wajib diisi jika memilih dokumen SIP.')
      return
    }
    if (simSpecs.length === 0) {
      setSimError('Pilih minimal 1 fokus layanan klinis.')
      return
    }

    const created = simulateMobilePsychologistSubmission({
      fullName: simFullName,
      titleDegree: simTitleDegree,
      documentType: simDocType,
      strNumber: includeStr ? simStr.toUpperCase() : undefined,
      strIssuedBy: includeStr ? simStrIssuedBy : undefined,
      strValidUntil: includeStr ? simStrValidUntil : undefined,
      sippNumber: includeSip ? simSipp.toUpperCase() : undefined,
      sipIssuedBy: includeSip ? simSipIssuedBy : undefined,
      sipValidUntil: includeSip ? simSipValidUntil : undefined,
      association: simAssociation,
      education: simEducation,
      email: simEmail || `psikolog.${Date.now().toString().slice(-4)}@praktikmandiri.id`,
      specializations: simSpecs,
      yearsOfExperience: simExperienceYears,
    })

    setSimFullName('')
    setSimEmail('')
    setSimStr('')
    setSimSipp('')
    setSimError(null)
    onCreated(created)
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="sim-modal-title"
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink/50 p-4"
    >
      <div className="max-h-[92dvh] w-full max-w-xl overflow-y-auto rounded-[14px] border border-[#E2E8F0] bg-white p-6 shadow-2xl">
        <div className="flex items-start justify-between border-b border-[#E2E8F0] pb-4">
          <div>
            <span className="inline-flex items-center gap-1 rounded-[5px] bg-[#EEF0FF] px-2 py-0.5 text-[10px] font-bold text-primary uppercase">
              Simulasi Registrasi Eva Counselor Mobile
            </span>
            <h2 id="sim-modal-title" className="mt-1 text-base font-bold text-ink">
              Pendaftaran Psikolog Profesional Mandiri
            </h2>
            <p className="text-xs text-ink-muted">
              Field identik dengan form pendaftaran pada aplikasi Eva Counselor Mobile untuk ditinjau Admin.
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup modal simulasi"
            className="inline-flex size-8 cursor-pointer items-center justify-center rounded-[8px] border border-[#E2E8F0] text-ink-muted hover:bg-slate-50"
          >
            <X className="size-4" />
          </button>
        </div>

        <form onSubmit={handleRegisterSubmit} className="mt-4 space-y-3.5 text-xs">
          {simError && (
            <div className="rounded-[8px] border border-crisis-border bg-crisis-bg px-3 py-2 text-crisis-text">
              {simError}
            </div>
          )}

          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <label htmlFor="sim-name" className="mb-1 block font-semibold text-ink">
                Nama Lengkap *
              </label>
              <input
                id="sim-name"
                type="text"
                placeholder="Rania Putri Maharani"
                value={simFullName}
                onChange={(e) => {
                  setSimFullName(e.target.value)
                  if (simError) setSimError(null)
                }}
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] px-3 text-xs text-ink focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label htmlFor="sim-degree" className="mb-1 block font-semibold text-ink">
                Gelar Profesi
              </label>
              <input
                id="sim-degree"
                type="text"
                value={simTitleDegree}
                onChange={(e) => setSimTitleDegree(e.target.value)}
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] px-3 text-xs text-ink focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label htmlFor="sim-email" className="mb-1 block font-semibold text-ink">
                Email Akun
              </label>
              <input
                id="sim-email"
                type="email"
                placeholder="rania.psi@praktikmandiri.id"
                value={simEmail}
                onChange={(e) => setSimEmail(e.target.value)}
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] px-3 text-xs text-ink focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label htmlFor="sim-assoc" className="mb-1 block font-semibold text-ink">
                Organisasi Profesi
              </label>
              <select
                id="sim-assoc"
                value={simAssociation}
                onChange={(e) => setSimAssociation(e.target.value)}
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs text-ink focus:border-primary focus:outline-none"
              >
                {PROFESSIONAL_ASSOCIATIONS.map((a) => (
                  <option key={a} value={a}>
                    {a}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label htmlFor="sim-edu" className="mb-1 block font-semibold text-ink">
                Pendidikan Terakhir
              </label>
              <select
                id="sim-edu"
                value={simEducation}
                onChange={(e) => setSimEducation(e.target.value)}
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs text-ink focus:border-primary focus:outline-none"
              >
                {EDUCATION_LEVELS.map((lvl) => (
                  <option key={lvl} value={lvl}>
                    {lvl}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label htmlFor="sim-exp" className="mb-1 block font-semibold text-ink">
                Pengalaman Klinis
              </label>
              <select
                id="sim-exp"
                value={simExperienceYears}
                onChange={(e) => setSimExperienceYears(Number(e.target.value))}
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs text-ink focus:border-primary focus:outline-none"
              >
                {EXPERIENCE_OPTIONS.map((opt) => (
                  <option key={opt.label} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <span className="mb-1.5 block font-semibold text-ink">Dokumen Legalitas yang Dilampirkan</span>
            <div className="grid grid-cols-3 gap-2">
              {[
                { id: 'both' as const, label: 'STR & SIP' },
                { id: 'str' as const, label: 'Hanya STR' },
                { id: 'sip' as const, label: 'Hanya SIP / SIPP' },
              ].map((opt) => (
                <button
                  key={opt.id}
                  type="button"
                  onClick={() => {
                    setSimDocType(opt.id)
                    if (simError) setSimError(null)
                  }}
                  className={cn(
                    'h-8 cursor-pointer rounded-[8px] border text-[11px] font-semibold transition-colors',
                    simDocType === opt.id
                      ? 'border-primary bg-primary text-white'
                      : 'border-[#CBD5E1] bg-white text-ink-soft hover:border-primary/40',
                  )}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          </div>

          {includeStr && (
            <div className="grid gap-3 rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-3 sm:grid-cols-3">
              <div>
                <label htmlFor="sim-str" className="mb-1 block font-semibold text-ink">
                  Nomor STR *
                </label>
                <input
                  id="sim-str"
                  type="text"
                  placeholder="STR-PK-2025-991023"
                  value={simStr}
                  onChange={(e) => {
                    setSimStr(e.target.value)
                    if (simError) setSimError(null)
                  }}
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 font-mono text-xs uppercase text-ink focus:border-primary focus:outline-none"
                />
              </div>
              <div>
                <label htmlFor="sim-str-issuer" className="mb-1 block font-semibold text-ink">
                  Instansi Penerbit STR
                </label>
                <input
                  id="sim-str-issuer"
                  type="text"
                  value={simStrIssuedBy}
                  onChange={(e) => setSimStrIssuedBy(e.target.value)}
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs text-ink focus:border-primary focus:outline-none"
                />
              </div>
              <div>
                <label htmlFor="sim-str-exp" className="mb-1 block font-semibold text-ink">
                  Masa Berlaku STR
                </label>
                <input
                  id="sim-str-exp"
                  type="text"
                  value={simStrValidUntil}
                  onChange={(e) => setSimStrValidUntil(e.target.value)}
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs text-ink focus:border-primary focus:outline-none"
                />
              </div>
            </div>
          )}

          {includeSip && (
            <div className="grid gap-3 rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-3 sm:grid-cols-3">
              <div>
                <label htmlFor="sim-sipp" className="mb-1 block font-semibold text-ink">
                  Nomor SIP / SIPP *
                </label>
                <input
                  id="sim-sipp"
                  type="text"
                  placeholder="20250618-2030-01-1402"
                  value={simSipp}
                  onChange={(e) => {
                    setSimSipp(e.target.value)
                    if (simError) setSimError(null)
                  }}
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 font-mono text-xs uppercase text-ink focus:border-primary focus:outline-none"
                />
              </div>
              <div>
                <label htmlFor="sim-sip-issuer" className="mb-1 block font-semibold text-ink">
                  Instansi Penerbit SIP
                </label>
                <input
                  id="sim-sip-issuer"
                  type="text"
                  value={simSipIssuedBy}
                  onChange={(e) => setSimSipIssuedBy(e.target.value)}
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs text-ink focus:border-primary focus:outline-none"
                />
              </div>
              <div>
                <label htmlFor="sim-sip-exp" className="mb-1 block font-semibold text-ink">
                  Masa Berlaku SIP
                </label>
                <input
                  id="sim-sip-exp"
                  type="text"
                  value={simSipValidUntil}
                  onChange={(e) => setSimSipValidUntil(e.target.value)}
                  className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs text-ink focus:border-primary focus:outline-none"
                />
              </div>
            </div>
          )}

          <div>
            <span className="mb-1.5 block font-semibold text-ink">Fokus Layanan Klinis</span>
            <div className="flex flex-wrap gap-1.5">
              {CLINICAL_SPECIALIZATIONS.map((spec) => (
                <button
                  key={spec}
                  type="button"
                  onClick={() => {
                    toggleSpec(spec)
                    if (simError) setSimError(null)
                  }}
                  className={cn(
                    'cursor-pointer rounded-[6px] border px-2.5 py-1 text-[11px] font-medium transition-colors',
                    simSpecs.includes(spec)
                      ? 'border-primary bg-primary text-white'
                      : 'border-[#CBD5E1] bg-white text-ink-soft hover:border-primary/40',
                  )}
                >
                  {spec}
                </button>
              ))}
            </div>
          </div>

          <div className="flex items-center justify-end gap-2 border-t border-[#E2E8F0] pt-4">
            <button
              type="button"
              onClick={onClose}
              className="inline-flex h-9 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-white px-4 text-xs font-semibold text-ink hover:bg-slate-50"
            >
              Batal
            </button>
            <button
              type="submit"
              className="inline-flex h-9 cursor-pointer items-center rounded-[8px] bg-primary px-4 text-xs font-semibold text-white hover:bg-[#464BB8]"
            >
              Kirim Pendaftaran Simulasi
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
