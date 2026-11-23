import { X } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { CLINICAL_SPECIALIZATIONS, PROFESSIONAL_ASSOCIATIONS } from '@/constants/portal'
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

export function MobilePsychologistSimulatorModal({
  isOpen,
  onClose,
  onCreated,
}: MobilePsychologistSimulatorModalProps) {
  useBodyScrollLock(isOpen)

  const [simFullName, setSimFullName] = useState('')
  const [simTitleDegree, setSimTitleDegree] = useState('M.Psi., Psikolog')
  const [simStr, setSimStr] = useState('')
  const [simSipp, setSimSipp] = useState('')
  const [simAssociation, setSimAssociation] = useState<string>(PROFESSIONAL_ASSOCIATIONS[0])
  const [simCity, setSimCity] = useState('')
  const [simEducation, setSimEducation] = useState('')
  const [simEmail, setSimEmail] = useState('')
  const [simPhone, setSimPhone] = useState('')
  const [simSchedule, setSimSchedule] = useState('Senin - Jumat (18.00 - 21.00 WIB)')
  const [simSpecs, setSimSpecs] = useState<string[]>([
    CLINICAL_SPECIALIZATIONS[0],
    CLINICAL_SPECIALIZATIONS[3],
  ])
  const [simError, setSimError] = useState<string | null>(null)

  if (!isDevToolsEnabled() || !isOpen) return null

  const toggleSpec = (spec: string) => {
    setSimSpecs((prev) =>
      prev.includes(spec) ? prev.filter((item) => item !== spec) : [...prev, spec],
    )
  }

  const handleRegisterSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!simFullName.trim() || !simCity.trim() || !simStr.trim()) {
      setSimError('Nama lengkap, Kota domisili, dan Nomor STR wajib diisi.')
      return
    }

    const created = simulateMobilePsychologistSubmission({
      fullName: simFullName,
      titleDegree: simTitleDegree,
      strNumber: simStr.toUpperCase(),
      sippNumber: simSipp.toUpperCase() || undefined,
      association: simAssociation,
      city: simCity.toUpperCase(),
      education: simEducation || 'Magister Profesi Psikologi Klinis Universitas Gadjah Mada',
      email: simEmail || `psikolog.${Date.now().toString().slice(-4)}@praktikmandiri.id`,
      phone: simPhone || '081299887766',
      practiceSchedule: simSchedule,
      specializations: simSpecs.length > 0 ? simSpecs : [CLINICAL_SPECIALIZATIONS[0]],
      yearsOfExperience: 4,
    })

    setSimFullName('')
    setSimStr('')
    setSimSipp('')
    setSimCity('')
    setSimEducation('')
    setSimEmail('')
    setSimPhone('')
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
              Simulasikan akun psikolog mandiri baru yang mendaftar melalui aplikasi mobile untuk ditinjau Admin.
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
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] px-3 font-mono text-xs uppercase text-ink focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label htmlFor="sim-sipp" className="mb-1 block font-semibold text-ink">
                Nomor SIP / SIPP
              </label>
              <input
                id="sim-sipp"
                type="text"
                placeholder="20250618-2030-01-1402"
                value={simSipp}
                onChange={(e) => setSimSipp(e.target.value)}
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] px-3 font-mono text-xs uppercase text-ink focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label htmlFor="sim-city" className="mb-1 block font-semibold text-ink">
                Kota Domisili *
              </label>
              <input
                id="sim-city"
                type="text"
                placeholder="BANDUNG"
                value={simCity}
                onChange={(e) => {
                  setSimCity(e.target.value)
                  if (simError) setSimError(null)
                }}
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] px-3 text-xs uppercase text-ink focus:border-primary focus:outline-none"
              />
            </div>

            <div>
              <label htmlFor="sim-assoc" className="mb-1 block font-semibold text-ink">
                Asosiasi Profesi
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

            <div className="sm:col-span-2">
              <label htmlFor="sim-edu" className="mb-1 block font-semibold text-ink">
                Asal Universitas / Profesi
              </label>
              <input
                id="sim-edu"
                type="text"
                placeholder="Magister Profesi Psikologi Klinis Universitas Gadjah Mada"
                value={simEducation}
                onChange={(e) => setSimEducation(e.target.value)}
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
              <label htmlFor="sim-schedule" className="mb-1 block font-semibold text-ink">
                Preferensi Jadwal Online
              </label>
              <input
                id="sim-schedule"
                type="text"
                value={simSchedule}
                onChange={(e) => setSimSchedule(e.target.value)}
                className="h-9 w-full rounded-[8px] border border-[#CBD5E1] px-3 text-xs text-ink focus:border-primary focus:outline-none"
              />
            </div>
          </div>

          <div>
            <span className="mb-1.5 block font-semibold text-ink">Spesialisasi Klinis</span>
            <div className="flex flex-wrap gap-1.5">
              {CLINICAL_SPECIALIZATIONS.map((spec) => (
                <button
                  key={spec}
                  type="button"
                  onClick={() => toggleSpec(spec)}
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
