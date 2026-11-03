import { ArrowUpCircle, GraduationCap, HeartHandshake, Sparkles, Users, X } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import {
  simulateMobilePsychologistSubmission,
  simulateVolunteerUpgradeSubmission,
} from './simulateSubmission'
import { CLINICAL_SPECIALIZATIONS } from '@/constants/portal'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { cn } from '@/lib/cn'
import { loadPortalDb } from '@/services/portal/storage'
import type { Psychologist } from '@/types/portal'

interface SimulateMobilePsyModalProps {
  isOpen: boolean
  onClose: () => void
  onCreated: (created: Psychologist, isUpgrade?: boolean) => void
  psychologists?: Psychologist[]
}

export function SimulateMobilePsyModal({
  isOpen,
  onClose,
  onCreated,
  psychologists,
}: SimulateMobilePsyModalProps) {
  useBodyScrollLock(isOpen)

  // Simulation Mode: 'register' | 'upgrade'
  const [simMode, setSimMode] = useState<'register' | 'upgrade'>('register')

  // Registration Fields
  const [selectedRole, setSelectedRole] = useState<'relawan_biasa' | 'relawan_profesional'>(
    'relawan_biasa',
  )
  const [simFullName, setSimFullName] = useState('')
  const [simSipp, setSimSipp] = useState('')
  const [simStr, setSimStr] = useState('')
  const [simCity, setSimCity] = useState('')
  const [simEducation, setSimEducation] = useState('')
  const [simEmail, setSimEmail] = useState('')
  const [simPhone, setSimPhone] = useState('')
  const [simSchedule, setSimSchedule] = useState('Senin – Jumat (17.00 – 21.00 WIB)')
  const [simValidUntil, setSimValidUntil] = useState('2029-12-31')
  const [simSpecs, setSimSpecs] = useState<string[]>(['Kecemasan & Panik', 'Remaja & Mahasiswa'])

  // Upgrade Fields
  const availableVolunteers = (psychologists ?? loadPortalDb().psychologists).filter(
    (p) =>
      (p.role === 'relawan_biasa' ||
        (p.role as string) === 'relawan' ||
        p.role === 'relawan_utama' ||
        p.role === 'relawan_pro') &&
      !p.upgradeRequest,
  )
  const [selectedVolunteerId, setSelectedVolunteerId] = useState<string>('')
  const activeVolunteerId = availableVolunteers.some((v) => v.id === selectedVolunteerId)
    ? selectedVolunteerId
    : (availableVolunteers[0]?.id ?? '')
  const selectedVolunteer = availableVolunteers.find((v) => v.id === activeVolunteerId)

  const [targetUpgradeRole, setTargetUpgradeRole] = useState<'relawan_utama' | 'relawan_profesional'>(
    'relawan_utama',
  )
  const [upgradeNotes, setUpgradeNotes] = useState(
    'Telah menyelesaikan 50+ sesi pendampingan konseling sebaya dengan evaluasi kepuasan 4.9/5.0.',
  )

  const [simError, setSimError] = useState<string | null>(null)

  if (!isOpen) return null

  const handleRegisterSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!simFullName.trim() || !simCity.trim()) {
      setSimError('Nama lengkap dan Kota domisili wajib diisi.')
      return
    }

    if (selectedRole === 'relawan_profesional' && (!simSipp.trim() || !simStr.trim())) {
      setSimError('Nomor SIPP dan STR wajib diisi untuk Relawan Profesional.')
      return
    }

    const created = simulateMobilePsychologistSubmission({
      role: selectedRole,
      fullName: simFullName,
      sippNumber: simSipp.toUpperCase(),
      strNumber: simStr.toUpperCase(),
      city: simCity.toUpperCase(),
      education:
        simEducation ||
        (selectedRole === 'relawan_profesional'
          ? 'Magister Profesi Psikologi Klinis Universitas Gadjah Mada'
          : 'S1 Psikologi Universitas Padjadjaran (Semester 6)'),
      email:
        simEmail ||
        (selectedRole === 'relawan_profesional'
          ? 'psikolog.prof@praktikmandiri.id'
          : 'relawan.sebaya@kampus.id'),
      phone: simPhone || '081299887766',
      practiceSchedule: simSchedule,
      specializations: simSpecs.length > 0 ? simSpecs : ['Kecemasan & Panik'],
      sippValidUntil: simValidUntil,
    })

    setSimFullName('')
    setSimSipp('')
    setSimStr('')
    setSimCity('')
    setSimEducation('')
    setSimEmail('')
    setSimPhone('')
    setSimError(null)
    onCreated(created, false)
  }

  const handleUpgradeSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const volId = activeVolunteerId
    if (!volId) {
      setSimError('Pilih akun relawan yang akan disimulasikan pengajuan upgradenya.')
      return
    }
    if (!upgradeNotes.trim() || upgradeNotes.trim().length < 15) {
      setSimError('Isi catatan/alasan upgrade minimal 15 karakter.')
      return
    }

    const isAlreadyUtama =
      selectedVolunteer?.role === 'relawan_utama' || selectedVolunteer?.role === 'relawan_pro'
    const effectiveTargetRole = isAlreadyUtama ? 'relawan_profesional' : targetUpgradeRole

    const updated = simulateVolunteerUpgradeSubmission(
      volId,
      effectiveTargetRole,
      upgradeNotes.trim(),
    )
    if (updated) {
      onCreated(updated, true)
    }
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
              Simulasi Layanan Psikolog &amp; Relawan
            </span>
            <h2 id="sim-modal-title" className="mt-1 text-base font-bold text-ink">
              Simulasi Pendaftaran &amp; Upgrade Relawan
            </h2>
            <p className="text-xs text-ink-muted">
              Uji coba alur pendaftaran relawan baru dan simulasi pengajuan upgrade.
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup modal simulasi"
            className="inline-flex size-8 cursor-pointer items-center justify-center rounded-[8px] border border-[#CBD5E1] text-ink-muted hover:bg-slate-100"
          >
            <X className="size-4" />
          </button>
        </div>

        {/* Mode Switcher Tabs */}
        <div className="mt-4 flex rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-1">
          <button
            type="button"
            onClick={() => {
              setSimMode('register')
              setSimError(null)
            }}
            className={cn(
              'flex-1 cursor-pointer rounded-[6px] py-1.5 text-xs font-semibold transition-colors',
              simMode === 'register'
                ? 'bg-white text-primary shadow-2xs'
                : 'text-ink-muted hover:text-ink',
            )}
          >
            1. Pendaftaran Relawan Baru
          </button>
          <button
            type="button"
            onClick={() => {
              setSimMode('upgrade')
              setSimError(null)
            }}
            className={cn(
              'flex-1 cursor-pointer rounded-[6px] py-1.5 text-xs font-semibold transition-colors',
              simMode === 'upgrade'
                ? 'bg-white text-primary shadow-2xs'
                : 'text-ink-muted hover:text-ink',
            )}
          >
            2. Pengajuan Upgrade Relawan
          </button>
        </div>

        {simError && (
          <div className="mt-3 rounded-[8px] border border-[#FECACA] bg-[#FEF2F2] p-3 text-xs font-medium text-[#B91C1C]">
            {simError}
          </div>
        )}

        {/* Tab 1: Pendaftaran Baru */}
        {simMode === 'register' && (
          <form onSubmit={handleRegisterSubmit} className="mt-4 space-y-3.5 text-xs">
            {/* Role Choice */}
            <div>
              <label className="block font-semibold text-ink">Pilih Kategori Relawan *</label>
              <div className="mt-1.5 grid grid-cols-1 gap-2 sm:grid-cols-2">
                <button
                  type="button"
                  onClick={() => {
                    setSelectedRole('relawan_biasa')
                    setSimSipp('')
                    setSimStr('')
                  }}
                  className={cn(
                    'flex cursor-pointer flex-col rounded-[10px] border p-3 text-left transition-all',
                    selectedRole === 'relawan_biasa'
                      ? 'border-sky-500 bg-sky-50 ring-1 ring-sky-300'
                      : 'border-[#CBD5E1] bg-white hover:bg-[#F8FAFC]',
                  )}
                >
                  <div className="flex items-center gap-1.5 font-bold text-sky-800">
                    <HeartHandshake className="size-4 text-sky-600" />
                    <span>Relawan</span>
                  </div>
                  <p className="mt-1 text-[11px] text-ink-muted">
                    Mahasiswa psikologi / perorangan tanpa gelar Psi. Mengunggah sertifikat pelatihan sebaya.
                  </p>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setSelectedRole('relawan_profesional')
                    if (!simSipp) setSimSipp('20240812-2029-01-0992')
                    if (!simStr) setSimStr('STR-PK-2024-991023')
                  }}
                  className={cn(
                    'flex cursor-pointer flex-col rounded-[10px] border p-3 text-left transition-all',
                    selectedRole === 'relawan_profesional'
                      ? 'border-indigo-500 bg-indigo-50 ring-1 ring-indigo-300'
                      : 'border-[#CBD5E1] bg-white hover:bg-[#F8FAFC]',
                  )}
                >
                  <div className="flex items-center gap-1.5 font-bold text-indigo-800">
                    <GraduationCap className="size-4 text-indigo-600" />
                    <span>Relawan Profesional</span>
                  </div>
                  <p className="mt-1 text-[11px] text-ink-muted">
                    Memiliki gelar profesi Psikolog (S2 Magister Profesi / Psi) dan izin praktik SIPP &amp; STR.
                  </p>
                </button>
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="sm:col-span-2">
                <label className="block font-semibold text-ink">
                  {selectedRole === 'relawan_profesional'
                    ? 'Nama Lengkap & Gelar Profesi (Psi) *'
                    : 'Nama Lengkap (Tanpa Gelar Psi) *'}
                </label>
                <input
                  type="text"
                  value={simFullName}
                  onChange={(e) => setSimFullName(e.target.value)}
                  placeholder={
                    selectedRole === 'relawan_profesional'
                      ? 'Contoh: Rania Putri Maharani, M.Psi., Psikolog'
                      : 'Contoh: Dika Ardiansyah (Mahasiswa Psikologi)'
                  }
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                />
              </div>

              {selectedRole === 'relawan_profesional' ? (
                <>
                  <div>
                    <label className="block font-semibold text-ink">Nomor SIPP *</label>
                    <input
                      type="text"
                      value={simSipp}
                      onChange={(e) => setSimSipp(e.target.value.toUpperCase())}
                      placeholder="20240812-2029-01-0992"
                      className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 font-mono uppercase text-ink focus:border-primary focus:outline-none"
                    />
                  </div>

                  <div>
                    <label className="block font-semibold text-ink">Nomor STR HIMPSI / IPK *</label>
                    <input
                      type="text"
                      value={simStr}
                      onChange={(e) => setSimStr(e.target.value.toUpperCase())}
                      placeholder="STR-PK-2024-991023"
                      className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 font-mono uppercase text-ink focus:border-primary focus:outline-none"
                    />
                  </div>
                </>
              ) : (
                <div className="sm:col-span-2 rounded-[8px] border border-sky-200 bg-sky-50/70 p-2.5 text-[11px] text-sky-800">
                  <span className="font-semibold">Info Relawan:</span> Tidak memerlukan nomor SIPP/STR. Berkas pendaftaran otomatis menyertakan Sertifikat Pelatihan Konseling Sebaya.
                </div>
              )}

              <div>
                <label className="block font-semibold text-ink">Kota Domisili *</label>
                <input
                  type="text"
                  value={simCity}
                  onChange={(e) => setSimCity(e.target.value.toUpperCase())}
                  placeholder="SEMARANG"
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 uppercase text-ink focus:border-primary focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-ink">
                  {selectedRole === 'relawan_profesional' ? 'Masa Berlaku SIPP' : 'Masa Aktif Relawan'}
                </label>
                <input
                  type="date"
                  value={simValidUntil}
                  onChange={(e) => setSimValidUntil(e.target.value)}
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                />
              </div>

              <div className="sm:col-span-2">
                <label className="block font-semibold text-ink">Asal Universitas / Instansi</label>
                <input
                  type="text"
                  value={simEducation}
                  onChange={(e) => setSimEducation(e.target.value)}
                  placeholder={
                    selectedRole === 'relawan_profesional'
                      ? 'Magister Profesi Psikologi Klinis Universitas Diponegoro'
                      : 'S1 Psikologi Universitas Diponegoro (Semester 6)'
                  }
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-ink">Email Akun Mobile</label>
                <input
                  type="email"
                  value={simEmail}
                  onChange={(e) => setSimEmail(e.target.value)}
                  placeholder="relawan.baru@eva.id"
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-ink">Nomor WhatsApp</label>
                <input
                  type="tel"
                  value={simPhone}
                  onChange={(e) => setSimPhone(e.target.value)}
                  placeholder="081234567890"
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                />
              </div>

              <div className="sm:col-span-2">
                <label className="block font-semibold text-ink">Jadwal Praktik / Pendampingan</label>
                <input
                  type="text"
                  value={simSchedule}
                  onChange={(e) => setSimSchedule(e.target.value)}
                  placeholder="Senin – Jumat (17.00 – 21.00 WIB)"
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-ink focus:border-primary focus:outline-none"
                />
              </div>
            </div>

            <div>
              <label className="block font-semibold text-ink">Spesialisasi Pendampingan</label>
              <div className="mt-1.5 flex flex-wrap gap-1.5">
                {CLINICAL_SPECIALIZATIONS.map((spec) => {
                  const active = simSpecs.includes(spec)
                  return (
                    <button
                      key={spec}
                      type="button"
                      onClick={() =>
                        setSimSpecs((prev) =>
                          prev.includes(spec) ? prev.filter((s) => s !== spec) : [...prev, spec],
                        )
                      }
                      className={cn(
                        'cursor-pointer rounded-[6px] border px-2.5 py-1 text-[11px] font-semibold transition-colors',
                        active
                          ? 'border-primary bg-[#EEF0FF] text-primary'
                          : 'border-[#CBD5E1] bg-white text-ink-soft',
                      )}
                    >
                      {spec}
                    </button>
                  )
                })}
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 border-t border-[#E2E8F0] pt-4">
              <button
                type="button"
                onClick={onClose}
                className="inline-flex h-9 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-white px-3.5 font-semibold text-ink"
              >
                Batal
              </button>
              <button
                type="submit"
                className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 font-semibold text-white hover:bg-primary-hover"
              >
                <Users className="size-3.5" /> Kirim Pendaftaran Relawan
              </button>
            </div>
          </form>
        )}

        {/* Tab 2: Pengajuan Upgrade */}
        {simMode === 'upgrade' && (
          <form onSubmit={handleUpgradeSubmit} className="mt-4 space-y-4 text-xs">
            <div>
              <label className="block font-semibold text-ink">
                Pilih Akun Relawan yang Mengajukan Upgrade *
              </label>
              {availableVolunteers.length === 0 ? (
                <div className="mt-1.5 rounded-[8px] border border-amber-200 bg-amber-50 p-3 text-amber-800">
                  Tidak ada relawan biasa/pro yang belum memiliki pengajuan upgrade aktif. Daftarkan relawan baru terlebih dahulu.
                </div>
              ) : (
                <select
                  value={activeVolunteerId}
                  onChange={(e) => setSelectedVolunteerId(e.target.value)}
                  className="mt-1 h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white px-3 font-semibold text-ink focus:border-primary focus:outline-none"
                >
                  {availableVolunteers.map((vol) => (
                    <option key={vol.id} value={vol.id}>
                      {vol.role === 'relawan_utama' || vol.role === 'relawan_pro'
                        ? '[Relawan Utama ★] '
                        : '[Relawan] '}
                      {vol.fullName} · {vol.city ?? 'Indonesia'} ({vol.education ?? 'Relawan'})
                    </option>
                  ))}
                </select>
              )}
            </div>

            <div>
              <label className="block font-semibold text-ink">Target Role Upgrade *</label>
              <div className="mt-1.5 grid grid-cols-1 gap-2 sm:grid-cols-2">
                <button
                  type="button"
                  disabled={
                    selectedVolunteer?.role === 'relawan_utama' ||
                    selectedVolunteer?.role === 'relawan_pro'
                  }
                  onClick={() => {
                    setTargetUpgradeRole('relawan_utama')
                    setUpgradeNotes(
                      'Telah mendampingi 60+ sesi peer-counseling dengan rating 4.9/5.0 dan kehadiran 100% pada evaluasi bulanan relawan.',
                    )
                  }}
                  className={cn(
                    'flex flex-col rounded-[10px] border p-3 text-left transition-all',
                    selectedVolunteer?.role === 'relawan_utama' ||
                      selectedVolunteer?.role === 'relawan_pro'
                      ? 'cursor-not-allowed border-[#E2E8F0] bg-slate-50 opacity-60'
                      : 'cursor-pointer',
                    targetUpgradeRole === 'relawan_utama' &&
                      selectedVolunteer?.role !== 'relawan_utama' &&
                      selectedVolunteer?.role !== 'relawan_pro'
                      ? 'border-amber-400 bg-amber-50 ring-1 ring-amber-300'
                      : 'border-[#CBD5E1] bg-white hover:bg-[#F8FAFC]',
                  )}
                >
                  <div className="flex items-center gap-1.5 font-bold text-amber-900">
                    <Sparkles className="size-4 text-amber-600" />
                    <span>Naik ke Relawan Utama</span>
                  </div>
                  <p className="mt-1 text-[11px] text-ink-muted">
                    {selectedVolunteer?.role === 'relawan_utama' ||
                    selectedVolunteer?.role === 'relawan_pro'
                      ? 'Akun ini sudah berstatus Relawan Utama.'
                      : 'Berdasarkan keaktifan dan rekam jejak kinerja. Keuntungan: tampil paling atas di daftar mobile.'}
                  </p>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setTargetUpgradeRole('relawan_profesional')
                    setUpgradeNotes(
                      'Telah lulus S2 Magister Profesi Psikologi Klinis dan memiliki SIPP serta STR-PK resmi.',
                    )
                  }}
                  className={cn(
                    'flex cursor-pointer flex-col rounded-[10px] border p-3 text-left transition-all',
                    targetUpgradeRole === 'relawan_profesional' ||
                      selectedVolunteer?.role === 'relawan_utama' ||
                      selectedVolunteer?.role === 'relawan_pro'
                      ? 'border-indigo-400 bg-indigo-50 ring-1 ring-indigo-300'
                      : 'border-[#CBD5E1] bg-white hover:bg-[#F8FAFC]',
                  )}
                >
                  <div className="flex items-center gap-1.5 font-bold text-indigo-900">
                    <GraduationCap className="size-4 text-indigo-600" />
                    <span>Upgrade ke Relawan Profesional</span>
                  </div>
                  <p className="mt-1 text-[11px] text-ink-muted">
                    Menyertakan bukti Ijazah Magister Profesi Psikolog, SIPP, dan STR Kemenkes.
                  </p>
                </button>
              </div>
            </div>

            <div>
              <label className="block font-semibold text-ink">
                Catatan Pengajuan / Bukti Portofolio *
              </label>
              <textarea
                rows={3}
                value={upgradeNotes}
                onChange={(e) => setUpgradeNotes(e.target.value)}
                placeholder="Tuliskan alasan pengajuan upgrade dan ringkasan prestasi / kelulusan..."
                className="mt-1 w-full rounded-[8px] border border-[#CBD5E1] bg-white p-3 text-ink focus:border-primary focus:outline-none"
              />
              <p className="mt-1 text-[11px] text-ink-muted">
                Simulasi ini otomatis melampirkan berkas sertifikat pendukung (Laporan Kinerja untuk Relawan Utama, atau Ijazah &amp; SIPP untuk Relawan Profesional).
              </p>
            </div>

            <div className="flex items-center justify-end gap-2 border-t border-[#E2E8F0] pt-4">
              <button
                type="button"
                onClick={onClose}
                className="inline-flex h-9 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-white px-3.5 font-semibold text-ink"
              >
                Batal
              </button>
              <button
                type="submit"
                disabled={availableVolunteers.length === 0}
                className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 font-semibold text-white hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-50"
              >
                <ArrowUpCircle className="size-3.5" /> Kirim Pengajuan Upgrade
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}
