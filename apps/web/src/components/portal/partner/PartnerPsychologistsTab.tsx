import { Calendar, Edit3, Plus, Search, Trash2, X } from 'lucide-react'
import { PsychologistSessionFeeBadge } from '@/components/portal/PortalBadges'
import { cn } from '@/lib/cn'
import type { Psychologist, PsychologistStatus } from '@/types/portal'

interface PartnerPsychologistsTabProps {
  psychologists: Psychologist[]
  psySearch: string
  psyStatusFilter: 'all' | PsychologistStatus
  psyCounts?: { all: number; active: number; on_leave: number; inactive: number }
  onSearchChange: (val: string) => void
  onFilterChange: (val: 'all' | PsychologistStatus) => void
  onOpenAddModal: () => void
  onOpenEditModal: (psy: Psychologist) => void
  onDeletePsychologist: (psy: Psychologist) => void
  onStatusChange: (psyId: string, status: PsychologistStatus) => void
}

export function PartnerPsychologistsTab({
  psychologists,
  psySearch,
  psyStatusFilter,
  psyCounts,
  onSearchChange,
  onFilterChange,
  onOpenAddModal,
  onOpenEditModal,
  onDeletePsychologist,
  onStatusChange,
}: PartnerPsychologistsTabProps) {
  return (
    <section className="mt-6" aria-label="Manajemen Psikolog">
      <div className="flex flex-col justify-between gap-3 rounded-[12px] border border-[#E2E8F0] bg-white p-4 sm:flex-row sm:items-center">
        <div className="flex flex-wrap items-center gap-2">
          {(
            [
              { id: 'all', label: 'Semua Status' },
              { id: 'active', label: 'Aktif Praktik' },
              { id: 'on_leave', label: 'Sedang Cuti' },
              { id: 'inactive', label: 'Nonaktif' },
            ] as const
          ).map((item) => (
            <button
              key={item.id}
              type="button"
              onClick={() => onFilterChange(item.id)}
              className={cn(
                'inline-flex h-8 cursor-pointer items-center rounded-[6px] px-3 text-xs font-semibold transition-colors',
                psyStatusFilter === item.id
                  ? 'bg-[#191C1F] text-white shadow-2xs'
                  : 'bg-[#F1F5F9] text-ink-soft hover:text-ink',
              )}
            >
              <span>{item.label}</span>
              {psyCounts && (
                <span
                  className={cn(
                    'ml-1.5 rounded-full px-1.5 py-0.2 text-[10px] font-bold',
                    psyStatusFilter === item.id
                      ? 'bg-white/20 text-white'
                      : 'bg-[#CBD5E1]/60 text-ink',
                  )}
                >
                  {psyCounts[item.id]}
                </span>
              )}
            </button>
          ))}
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <div className="relative flex-1 sm:w-64">
            <Search className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-ink-muted" />
            <input
              type="search"
              placeholder="Cari nama, SIPP, spesialisasi…"
              value={psySearch}
              onChange={(e) => onSearchChange(e.target.value)}
              className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white pr-8 pl-9 text-xs text-ink outline-none transition-colors focus:border-primary"
            />
            {psySearch && (
              <button
                type="button"
                onClick={() => onSearchChange('')}
                aria-label="Hapus kata kunci pencarian"
                className="absolute top-1/2 right-2.5 flex size-5 -translate-y-1/2 cursor-pointer items-center justify-center rounded-[4px] text-ink-muted hover:bg-[#F1F5F9] hover:text-ink"
              >
                <X className="size-3.5" />
              </button>
            )}
          </div>
          <button
            type="button"
            onClick={onOpenAddModal}
            className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white transition-colors hover:bg-[#464BB8] shadow-2xs"
          >
            <Plus className="size-4" />
            <span>Tambah Psikolog</span>
          </button>
        </div>
      </div>

      {psychologists.length === 0 ? (
        <div className="mt-4 rounded-[12px] border border-[#E2E8F0] bg-white p-10 text-center">
          <p className="text-sm font-semibold text-ink">Belum ada data psikolog yang sesuai</p>
          <p className="mt-1 text-xs text-ink-soft">
            {psySearch
              ? 'Tidak ditemukan psikolog dengan kata kunci tersebut. Coba ubah pencarian atau filter status.'
              : 'Tambahkan psikolog klinis yang berpraktik di fasilitas kesehatan Anda.'}
          </p>
          {!psySearch && (
            <button
              type="button"
              onClick={onOpenAddModal}
              className="mt-4 inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white hover:bg-[#464BB8]"
            >
              <Plus className="size-4" /> Tambah Psikolog Pertama
            </button>
          )}
        </div>
      ) : (
        <div className="mt-4 space-y-4">
          {/* Mobile Card List (< md) */}
          <div className="space-y-3 md:hidden">
            {psychologists.map((psy) => (
              <div
                key={psy.id}
                className="rounded-[12px] border border-[#E2E8F0] bg-white p-4 shadow-2xs space-y-3"
              >
                {/* Header: Nama, Pendidikan, Status select */}
                <div className="flex items-start justify-between gap-2 border-b border-[#E2E8F0] pb-2.5">
                  <div className="min-w-0 flex-1">
                    <p className="line-clamp-1 text-sm font-bold text-ink">{psy.fullName}</p>
                    <p className="mt-0.5 text-[11px] text-ink-soft">
                      {psy.education || 'Psikolog Klinis'}
                      {psy.yearsExperience ? ` · ${psy.yearsExperience} thn praktik` : ''}
                    </p>
                  </div>
                  <select
                    aria-label={`Ubah status ${psy.fullName}`}
                    value={psy.status}
                    onChange={(e) =>
                      onStatusChange(psy.id, e.target.value as PsychologistStatus)
                    }
                    className={cn(
                      'h-7 cursor-pointer rounded-[6px] border px-2 text-[11px] font-semibold outline-none shrink-0',
                      psy.status === 'active' &&
                        'border-success/30 bg-success/10 text-success',
                      psy.status === 'on_leave' &&
                        'border-warning/30 bg-warning/10 text-[#B45309]',
                      psy.status === 'inactive' &&
                        'border-[#CBD5E1] bg-[#F1F5F9] text-ink-soft',
                    )}
                  >
                    <option value="active">Aktif Praktik</option>
                    <option value="on_leave">Sedang Cuti</option>
                    <option value="inactive">Nonaktif</option>
                  </select>
                </div>

                {/* SIPP & Tarif */}
                <div className="flex items-center justify-between text-xs">
                  <span className="font-mono text-xs text-ink font-medium">
                    {psy.sippNumber}
                  </span>
                  <PsychologistSessionFeeBadge
                    feeCoins={psy.sessionFeeCoins}
                    durationMinutes={psy.sessionDurationMinutes}
                  />
                </div>

                {/* Spesialisasi */}
                {psy.specializations.length > 0 && (
                  <div className="flex flex-wrap gap-1">
                    {psy.specializations.map((sp) => (
                      <span
                        key={sp}
                        className="rounded-[5px] border border-[#E2E8F0] bg-[#F8FAFC] px-2 py-0.5 text-[10.5px] font-medium text-ink-soft"
                      >
                        {sp}
                      </span>
                    ))}
                  </div>
                )}

                {/* Jadwal & Kuota */}
                <div className="space-y-0.5 text-xs text-ink">
                  <p className="inline-flex items-center gap-1.5 font-medium">
                    <Calendar className="size-3.5 text-ink-muted" />
                    <span>{psy.practiceSchedule}</span>
                  </p>
                  {psy.weeklyQuota && (
                    <p className="text-[11px] text-ink-muted">
                      Kuota rujukan: {psy.weeklyQuota} pasien/minggu
                    </p>
                  )}
                </div>

                {/* Action Buttons */}
                <div className="flex items-center justify-end gap-2 border-t border-[#E2E8F0] pt-2.5">
                  <button
                    type="button"
                    onClick={() => onOpenEditModal(psy)}
                    aria-label={`Edit ${psy.fullName}`}
                    className="inline-flex h-8 cursor-pointer items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink hover:bg-[#F8FAFC]"
                  >
                    <Edit3 className="size-3.5" />
                    <span>Edit</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => onDeletePsychologist(psy)}
                    aria-label={`Hapus ${psy.fullName}`}
                    className="inline-flex size-8 cursor-pointer items-center justify-center rounded-[6px] border border-[#CBD5E1] bg-white text-ink-soft transition-colors hover:border-crisis-border hover:bg-crisis-bg hover:text-crisis-text"
                  >
                    <Trash2 className="size-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* Desktop Data Table (>= md) */}
          <div className="hidden overflow-hidden rounded-[12px] border border-[#E2E8F0] bg-white md:block">
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left text-xs">
                <thead>
                  <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-semibold tracking-wider text-ink-muted uppercase">
                    <th className="px-4 py-3.5">Nama &amp; Pendidikan</th>
                    <th className="px-4 py-3.5">Nomor SIPP / STR</th>
                    <th className="px-4 py-3.5">Spesialisasi Klinis</th>
                    <th className="px-4 py-3.5">Jadwal &amp; Kuota</th>
                    <th className="px-4 py-3.5">Durasi &amp; Tarif Sesi</th>
                    <th className="px-4 py-3.5">Status Praktik</th>
                    <th className="px-4 py-3.5 text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#E2E8F0]">
                  {psychologists.map((psy) => (
                    <tr key={psy.id} className="transition-colors hover:bg-[#F8FAFC]/70">
                      <td className="px-4 py-4 align-top">
                        <p className="text-sm font-semibold text-ink">{psy.fullName}</p>
                        <p className="mt-0.5 text-[11px] text-ink-soft">
                          {psy.education || 'Psikolog Klinis'}
                          {psy.yearsExperience ? ` · ${psy.yearsExperience} thn praktik` : ''}
                        </p>
                      </td>
                      <td className="px-4 py-4 align-top font-mono text-xs text-ink font-medium">
                        {psy.sippNumber}
                      </td>
                      <td className="px-4 py-4 align-top">
                        <div className="flex max-w-xs flex-wrap gap-1">
                          {psy.specializations.map((sp) => (
                            <span
                              key={sp}
                              className="rounded-[5px] border border-[#E2E8F0] bg-[#F8FAFC] px-2 py-0.5 text-[11px] font-medium text-ink-soft"
                            >
                              {sp}
                            </span>
                          ))}
                        </div>
                      </td>
                      <td className="px-4 py-4 align-top">
                        <p className="inline-flex items-center gap-1 font-medium text-ink">
                          <Calendar className="size-3.5 text-ink-muted" />
                          {psy.practiceSchedule}
                        </p>
                        {psy.weeklyQuota && (
                          <p className="mt-0.5 text-[11px] text-ink-muted">
                            Kuota rujukan: {psy.weeklyQuota} pasien/minggu
                          </p>
                        )}
                      </td>
                      <td className="px-4 py-4 align-top">
                        <PsychologistSessionFeeBadge
                          feeCoins={psy.sessionFeeCoins}
                          durationMinutes={psy.sessionDurationMinutes}
                        />
                      </td>
                      <td className="px-4 py-4 align-top">
                        <select
                          aria-label={`Ubah status ${psy.fullName}`}
                          value={psy.status}
                          onChange={(e) =>
                            onStatusChange(psy.id, e.target.value as PsychologistStatus)
                          }
                          className={cn(
                            'h-8 cursor-pointer rounded-[6px] border px-2.5 text-xs font-semibold outline-none transition-colors',
                            psy.status === 'active' &&
                              'border-success/30 bg-success/10 text-success',
                            psy.status === 'on_leave' &&
                              'border-warning/30 bg-warning/10 text-[#B45309]',
                            psy.status === 'inactive' &&
                              'border-[#CBD5E1] bg-[#F1F5F9] text-ink-soft',
                          )}
                        >
                          <option value="active">Aktif Praktik</option>
                          <option value="on_leave">Sedang Cuti</option>
                          <option value="inactive">Nonaktif</option>
                        </select>
                      </td>
                      <td className="px-4 py-4 align-top text-right">
                        <div className="inline-flex items-center gap-1.5">
                          <button
                            type="button"
                            onClick={() => onOpenEditModal(psy)}
                            aria-label={`Edit ${psy.fullName}`}
                            className="inline-flex h-8 cursor-pointer items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-xs font-semibold text-ink hover:bg-[#F8FAFC]"
                          >
                            <Edit3 className="size-3.5" />
                            <span>Edit</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => onDeletePsychologist(psy)}
                            aria-label={`Hapus ${psy.fullName}`}
                            className="inline-flex size-8 cursor-pointer items-center justify-center rounded-[6px] border border-[#CBD5E1] bg-white text-ink-soft transition-colors hover:border-crisis-border hover:bg-crisis-bg hover:text-crisis-text"
                          >
                            <Trash2 className="size-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}

