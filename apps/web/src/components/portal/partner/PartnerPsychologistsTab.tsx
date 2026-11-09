import { Calendar, Eye, Plus, Search, Trash2, X } from 'lucide-react'
import { useState } from 'react'
import { PsychologistSessionFeeBadge } from '@/components/portal/PortalBadges'
import { cn } from '@/lib/cn'
import type { Psychologist, PsychologistStatus } from '@/types/portal'
import { PartnerPsychologistDetailModal } from './PartnerPsychologistDetailModal'

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
  const [selectedDetailPsy, setSelectedDetailPsy] = useState<Psychologist | null>(null)

  return (
    <section className="mt-6" aria-label="Manajemen Psikolog">
      {/* 1. Filter Status & Search Bar */}
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
                {/* Header: Nama, SIPP, Status Select */}
                <div className="flex items-start justify-between gap-2 border-b border-[#E2E8F0] pb-2.5">
                  <div className="min-w-0 flex-1">
                    <button
                      type="button"
                      onClick={() => setSelectedDetailPsy(psy)}
                      className="text-left font-bold text-sm text-ink hover:text-primary transition-colors cursor-pointer"
                    >
                      {psy.fullName}
                    </button>
                    <p className="mt-0.5 font-mono text-xs text-ink-muted">
                      {psy.sippNumber}
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
                        'border-emerald-300 bg-emerald-50 text-emerald-800',
                      psy.status === 'on_leave' &&
                        'border-amber-300 bg-amber-50 text-amber-800',
                      psy.status === 'inactive' &&
                        'border-[#CBD5E1] bg-[#F1F5F9] text-ink-soft',
                    )}
                  >
                    <option value="active">Aktif Praktik</option>
                    <option value="on_leave">Sedang Cuti</option>
                    <option value="inactive">Nonaktif</option>
                  </select>
                </div>

                {/* Spesialisasi Ringkas & Tarif */}
                <div className="flex items-center justify-between gap-2 text-xs">
                  <p className="truncate text-ink-soft">
                    {psy.specializations.length > 0
                      ? psy.specializations.slice(0, 2).join(' · ')
                      : 'Psikologi Umum'}
                  </p>
                  <PsychologistSessionFeeBadge
                    feeCoins={psy.sessionFeeCoins}
                    durationMinutes={psy.sessionDurationMinutes}
                  />
                </div>

                {/* Jadwal Praktik */}
                <div className="text-xs text-ink">
                  <p className="inline-flex items-center gap-1.5 font-medium">
                    <Calendar className="size-3.5 text-primary shrink-0" />
                    <span>{psy.practiceSchedule}</span>
                  </p>
                </div>

                {/* Action Buttons */}
                <div className="flex items-center justify-end gap-2 border-t border-[#E2E8F0] pt-2.5">
                  <button
                    type="button"
                    onClick={() => setSelectedDetailPsy(psy)}
                    className="inline-flex h-8 cursor-pointer items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-white px-2.5 text-xs font-semibold text-ink hover:bg-slate-50"
                  >
                    <Eye className="size-3.5" />
                    <span>Detail</span>
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

          {/* Desktop Data Table (>= md) - 4 Kolom Proporsional */}
          <div className="hidden overflow-hidden rounded-[12px] border border-[#E2E8F0] bg-white md:block">
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left text-xs">
                <thead>
                  <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-semibold tracking-wider text-ink-muted uppercase">
                    <th className="px-5 py-3.5">Psikolog &amp; SIPP</th>
                    <th className="px-5 py-3.5">Spesialisasi &amp; Tarif</th>
                    <th className="px-5 py-3.5">Jadwal &amp; Status</th>
                    <th className="px-5 py-3.5 text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#E2E8F0]">
                  {psychologists.map((psy) => (
                    <tr key={psy.id} className="transition-colors hover:bg-[#F8FAFC]/70">
                      {/* Kolom 1: Psikolog & SIPP */}
                      <td className="px-5 py-4 align-top">
                        <button
                          type="button"
                          onClick={() => setSelectedDetailPsy(psy)}
                          className="text-left font-bold text-sm text-ink hover:text-primary transition-colors cursor-pointer"
                        >
                          {psy.fullName}
                        </button>
                        <div className="mt-1 flex flex-wrap items-center gap-1.5 text-xs text-ink-muted">
                          <span className="font-mono font-medium text-ink">
                            {psy.sippNumber}
                          </span>
                          {psy.yearsExperience && (
                            <span>· {psy.yearsExperience} thn praktik</span>
                          )}
                        </div>
                      </td>

                      {/* Kolom 2: Spesialisasi & Tarif */}
                      <td className="px-5 py-4 align-top">
                        <p className="text-xs font-medium text-ink">
                          {psy.specializations.length > 0
                            ? psy.specializations.slice(0, 2).join(' · ') +
                              (psy.specializations.length > 2
                                ? ` (+${psy.specializations.length - 2})`
                                : '')
                            : 'Psikologi Umum'}
                        </p>
                        <div className="mt-1.5">
                          <PsychologistSessionFeeBadge
                            feeCoins={psy.sessionFeeCoins}
                            durationMinutes={psy.sessionDurationMinutes}
                          />
                        </div>
                      </td>

                      {/* Kolom 3: Jadwal & Status Praktik */}
                      <td className="px-5 py-4 align-top">
                        <p className="inline-flex items-center gap-1.5 text-xs font-semibold text-ink">
                          <Calendar className="size-3.5 text-primary shrink-0" />
                          <span>{psy.practiceSchedule}</span>
                        </p>
                        <div className="mt-1.5">
                          <select
                            aria-label={`Ubah status ${psy.fullName}`}
                            value={psy.status}
                            onChange={(e) =>
                              onStatusChange(psy.id, e.target.value as PsychologistStatus)
                            }
                            className={cn(
                              'h-7 cursor-pointer rounded-[6px] border px-2 text-[11px] font-semibold outline-none transition-colors',
                              psy.status === 'active' &&
                                'border-emerald-300 bg-emerald-50 text-emerald-800',
                              psy.status === 'on_leave' &&
                                'border-amber-300 bg-amber-50 text-amber-800',
                              psy.status === 'inactive' &&
                                'border-[#CBD5E1] bg-slate-100 text-slate-700',
                            )}
                          >
                            <option value="active">Aktif Praktik</option>
                            <option value="on_leave">Sedang Cuti</option>
                            <option value="inactive">Nonaktif</option>
                          </select>
                        </div>
                      </td>

                      {/* Kolom 4: Aksi */}
                      <td className="px-5 py-4 align-top text-right">
                        <div className="inline-flex items-center gap-1.5">
                          <button
                            type="button"
                            onClick={() => setSelectedDetailPsy(psy)}
                            className="inline-flex h-8 cursor-pointer items-center gap-1 rounded-[6px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink transition-colors hover:border-primary hover:text-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
                          >
                            <Eye className="size-3.5" />
                            <span>Lihat Detail</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => onDeletePsychologist(psy)}
                            aria-label={`Hapus ${psy.fullName}`}
                            className="inline-flex size-8 cursor-pointer items-center justify-center rounded-[6px] border border-[#CBD5E1] bg-white text-ink-soft transition-colors hover:border-rose-300 hover:bg-rose-50 hover:text-rose-700 focus:outline-none focus:ring-2 focus:ring-rose-300"
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

      {/* 2. Modal Detail Profil Psikolog Faskes */}
      <PartnerPsychologistDetailModal
        psy={selectedDetailPsy}
        onClose={() => setSelectedDetailPsy(null)}
        onEdit={(targetPsy) => {
          setSelectedDetailPsy(null)
          onOpenEditModal(targetPsy)
        }}
        onStatusChange={(psyId, status) => {
          onStatusChange(psyId, status)
          if (selectedDetailPsy && selectedDetailPsy.id === psyId) {
            setSelectedDetailPsy({ ...selectedDetailPsy, status })
          }
        }}
      />
    </section>
  )
}
