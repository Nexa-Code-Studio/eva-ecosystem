import { Calendar, Edit3, Plus, Search, Trash2 } from 'lucide-react'
import { cn } from '@/lib/cn'
import type { Psychologist, PsychologistStatus } from '@/types/portal'

interface PartnerPsychologistsTabProps {
  psychologists: Psychologist[]
  psySearch: string
  psyStatusFilter: 'all' | PsychologistStatus
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
                'h-8 cursor-pointer rounded-[6px] px-3 text-xs font-semibold transition-colors',
                psyStatusFilter === item.id
                  ? 'bg-[#191C1F] text-white'
                  : 'bg-[#F1F5F9] text-ink-soft hover:text-ink',
              )}
            >
              {item.label}
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
              className="h-9 w-full rounded-[8px] border border-[#CBD5E1] bg-white pr-3 pl-9 text-xs text-ink outline-none focus:border-primary"
            />
          </div>
          <button
            type="button"
            onClick={onOpenAddModal}
            className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white transition-colors hover:bg-[#464BB8]"
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
            Tambahkan psikolog klinis yang berpraktik di fasilitas kesehatan Anda.
          </p>
          <button
            type="button"
            onClick={onOpenAddModal}
            className="mt-4 inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-4 text-xs font-semibold text-white hover:bg-[#464BB8]"
          >
            <Plus className="size-4" /> Tambah Psikolog Pertama
          </button>
        </div>
      ) : (
        <div className="mt-4 overflow-hidden rounded-[12px] border border-[#E2E8F0] bg-white">
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-left text-xs">
              <thead>
                <tr className="border-b border-[#E2E8F0] bg-[#F8FAFC] text-[11px] font-semibold tracking-wider text-ink-muted uppercase">
                  <th className="px-4 py-3.5">Nama &amp; Pendidikan</th>
                  <th className="px-4 py-3.5">Nomor SIPP / STR</th>
                  <th className="px-4 py-3.5">Spesialisasi Klinis</th>
                  <th className="px-4 py-3.5">Jadwal &amp; Kuota</th>
                  <th className="px-4 py-3.5">Status Praktik</th>
                  <th className="px-4 py-3.5 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#E2E8F0]">
                {psychologists.map((psy) => (
                  <tr key={psy.id} className="hover:bg-[#F8FAFC]/70">
                    <td className="px-4 py-4 align-top">
                      <p className="text-sm font-semibold text-ink">{psy.fullName}</p>
                      <p className="mt-0.5 text-[11px] text-ink-soft">
                        {psy.education || 'Psikolog Klinis'}
                        {psy.yearsExperience ? ` · ${psy.yearsExperience} thn praktik` : ''}
                      </p>
                    </td>
                    <td className="px-4 py-4 align-top font-mono text-xs text-ink">
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
                      <select
                        aria-label={`Ubah status ${psy.fullName}`}
                        value={psy.status}
                        onChange={(e) =>
                          onStatusChange(psy.id, e.target.value as PsychologistStatus)
                        }
                        className={cn(
                          'h-8 cursor-pointer rounded-[6px] border px-2.5 text-xs font-semibold outline-none',
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
      )}
    </section>
  )
}

