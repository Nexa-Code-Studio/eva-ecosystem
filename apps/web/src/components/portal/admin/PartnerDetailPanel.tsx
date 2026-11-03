import { useState } from 'react'
import {
  AlertTriangle,
  CheckCircle2,
  ExternalLink,
  RefreshCw,
  XCircle,
} from 'lucide-react'
import type { PartnerAccount, Psychologist } from '@/types/portal'
import { PartnerStatusBadge, PracticeStatusBadge } from '../PortalBadges'

interface PartnerDetailPanelProps {
  selectedPartner: PartnerAccount | null
  partnerPsychologists: Psychologist[]
  onApprovePartner: (partnerId: string, facilityName: string) => void
  onSuspendPartner: (partnerId: string, facilityName: string) => void
  onRejectPartner: (partnerId: string, facilityName: string, reason: string) => void
}

export function PartnerDetailPanel({
  selectedPartner,
  partnerPsychologists,
  onApprovePartner,
  onSuspendPartner,
  onRejectPartner,
}: PartnerDetailPanelProps) {
  const [showRejectBox, setShowRejectBox] = useState(false)
  const [rejectReason, setRejectReason] = useState('')
  const [rejectError, setRejectError] = useState<string | null>(null)

  if (!selectedPartner) return null

  const handleConfirmReject = () => {
    if (!rejectReason.trim() || rejectReason.trim().length < 10) {
      setRejectError('Harap tuliskan alasan penolakan minimal 10 karakter agar mitra dapat memperbaiki dokumen.')
      return
    }
    onRejectPartner(selectedPartner.id, selectedPartner.facilityName, rejectReason.trim())
    setShowRejectBox(false)
    setRejectReason('')
    setRejectError(null)
  }

  return (
    <div className="rounded-[12px] border border-[#E2E8F0] bg-white p-6">
      <div className="flex flex-wrap items-start justify-between gap-4 border-b border-[#E2E8F0] pb-5">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <span className="rounded-[6px] border border-[#E2E8F0] bg-[#F8FAFC] px-2 py-0.5 text-[11px] font-semibold text-ink-soft">
              {selectedPartner.facilityType}
            </span>
            <span className="text-xs text-ink-muted">· {selectedPartner.city}</span>
          </div>
          <h2 className="mt-2 text-lg font-bold text-ink">{selectedPartner.facilityName}</h2>
          <p className="mt-0.5 font-mono text-xs text-ink-soft">
            No. Izin Operasional: {selectedPartner.licenseNumber}
          </p>
        </div>

        <PartnerStatusBadge
          status={selectedPartner.status}
          isResubmitted={selectedPartner.isResubmitted}
        />
      </div>

      {selectedPartner.isResubmitted && selectedPartner.status === 'pending' && (
        <div className="mt-4 flex items-start gap-2.5 rounded-[8px] border border-[#BFDBFE] bg-[#EFF6FF] p-3.5 text-xs text-[#1E3A8A]">
          <RefreshCw className="mt-0.5 size-4 shrink-0 text-[#2563EB]" />
          <div>
            <p className="font-semibold">Pengajuan Ulang (Telah Diperbaiki Mitra)</p>
            <p className="mt-0.5 text-[#1E40AF]">
              Mitra telah memperbarui dokumen pada {selectedPartner.resubmittedAt}.
            </p>
          </div>
        </div>
      )}

      {selectedPartner.status === 'rejected' && selectedPartner.rejectionReason && (
        <div className="mt-4 flex items-start gap-2.5 rounded-[8px] border border-[#FECACA] bg-[#FEF2F2] p-3.5 text-xs text-[#991B1B]">
          <AlertTriangle className="mt-0.5 size-4 shrink-0 text-[#DC2626]" />
          <div>
            <p className="font-semibold">Alasan Penolakan Sebelumnya:</p>
            <p className="mt-0.5 leading-relaxed">{selectedPartner.rejectionReason}</p>
          </div>
        </div>
      )}

      <div className="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5">
          <p className="text-[11px] font-bold tracking-wider text-ink-muted uppercase">
            Detail Instansi & Operasional
          </p>
          <dl className="mt-2.5 space-y-2 text-xs">
            <div>
              <dt className="text-ink-muted">Alamat Lengkap</dt>
              <dd className="font-medium text-ink">{selectedPartner.address}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-muted">Jam Operasional</dt>
              <dd className="font-medium text-ink">
                {selectedPartner.operatingHours || 'Belum diisi'}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-muted">Dukungan BPJS</dt>
              <dd className="font-semibold text-ink">
                {selectedPartner.bpjsSupported ? 'Menerima BPJS' : 'Reguler / Non-BPJS'}
              </dd>
            </div>
            {selectedPartner.website && (
              <div className="flex justify-between">
                <dt className="text-ink-muted">Situs Web</dt>
                <dd>
                  <a
                    href={selectedPartner.website}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center gap-1 font-semibold text-primary hover:underline"
                  >
                    Kunjungi <ExternalLink className="size-3" />
                  </a>
                </dd>
              </div>
            )}
          </dl>
        </div>

        <div className="rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] p-3.5">
          <p className="text-[11px] font-bold tracking-wider text-ink-muted uppercase">
            Penanggung Jawab (PIC) & Akun
          </p>
          <dl className="mt-2.5 space-y-2 text-xs">
            <div>
              <dt className="text-ink-muted">Nama PIC</dt>
              <dd className="font-semibold text-ink">{selectedPartner.picName}</dd>
            </div>
            <div>
              <dt className="text-ink-muted">Jabatan</dt>
              <dd className="font-medium text-ink">{selectedPartner.picRole}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-muted">Email Login</dt>
              <dd className="font-medium text-ink">{selectedPartner.email}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-ink-muted">WhatsApp / Telepon</dt>
              <dd className="font-medium text-ink">{selectedPartner.phone}</dd>
            </div>
          </dl>
        </div>
      </div>

      {/* Verification Decision Actions */}
      <div className="mt-6 border-t border-[#E2E8F0] pt-5">
        <p className="text-xs font-bold tracking-wider text-ink-muted uppercase">
          Tindakan Verifikasi Admin
        </p>

        {!showRejectBox ? (
          <div className="mt-3 flex flex-wrap items-center gap-2.5">
            {selectedPartner.status !== 'approved' && (
              <button
                type="button"
                onClick={() => onApprovePartner(selectedPartner.id, selectedPartner.facilityName)}
                className="inline-flex h-10 cursor-pointer items-center gap-1.5 rounded-[8px] bg-[#16A34A] px-4 text-xs font-semibold text-white transition-colors hover:bg-[#15803D]"
              >
                <CheckCircle2 className="size-4" />
                Setujui & Aktifkan Akun Mitra
              </button>
            )}

            {selectedPartner.status !== 'rejected' && (
              <button
                type="button"
                onClick={() => {
                  setShowRejectBox(true)
                  setRejectReason(selectedPartner.rejectionReason ?? '')
                  setRejectError(null)
                }}
                className="inline-flex h-10 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#FECACA] bg-[#FEF2F2] px-4 text-xs font-semibold text-[#B91C1C] transition-colors hover:bg-[#FEE2E2]"
              >
                <XCircle className="size-4" />
                Tolak dengan Catatan
              </button>
            )}

            {selectedPartner.status === 'approved' && (
              <button
                type="button"
                onClick={() => onSuspendPartner(selectedPartner.id, selectedPartner.facilityName)}
                className="inline-flex h-10 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-4 text-xs font-semibold text-ink-soft transition-colors hover:bg-[#F8FAFC]"
              >
                Nonaktifkan Sementara
              </button>
            )}
          </div>
        ) : (
          <div className="mt-3 rounded-[8px] border border-[#FECACA] bg-[#FEF2F2]/60 p-4">
            <label htmlFor="reject-reason" className="block text-xs font-semibold text-[#991B1B]">
              Alasan Penolakan / Catatan Perbaikan (Wajib diisi)
            </label>
            <textarea
              id="reject-reason"
              rows={3}
              value={rejectReason}
              onChange={(e) => {
                setRejectReason(e.target.value)
                if (rejectError) setRejectError(null)
              }}
              placeholder="Contoh: Nomor Izin Operasional Faskes belum sesuai format Kemenkes/Dinkes..."
              className="mt-2 w-full rounded-[8px] border border-[#FCA5A5] bg-white p-2.5 text-xs text-ink focus:border-[#DC2626] focus:outline-none"
            />
            {rejectError && (
              <p className="mt-1.5 text-xs font-medium text-[#DC2626]">{rejectError}</p>
            )}
            <div className="mt-3 flex items-center gap-2">
              <button
                type="button"
                onClick={handleConfirmReject}
                className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] bg-[#DC2626] px-3.5 text-xs font-semibold text-white hover:bg-[#B91C1C]"
              >
                Konfirmasi Tolak Pengajuan
              </button>
              <button
                type="button"
                onClick={() => {
                  setShowRejectBox(false)
                  setRejectError(null)
                }}
                className="inline-flex h-9 cursor-pointer items-center rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink"
              >
                Batal
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Facility Psychologists List */}
      <div className="mt-6 border-t border-[#E2E8F0] pt-5">
        <h3 className="text-xs font-bold tracking-wider text-ink-muted uppercase">
          Psikolog Naungan Faskes Ini ({partnerPsychologists.length})
        </h3>

        {partnerPsychologists.length === 0 ? (
          <p className="mt-2 text-xs text-ink-muted">
            Mitra ini belum menambahkan daftar psikolog aktif.
          </p>
        ) : (
          <div className="mt-3 divide-y divide-[#E2E8F0] rounded-[8px] border border-[#E2E8F0]">
            {partnerPsychologists.map((psy) => (
              <div
                key={psy.id}
                className="flex flex-wrap items-center justify-between gap-2 p-3 text-xs"
              >
                <div>
                  <p className="font-semibold text-ink">{psy.fullName}</p>
                  <p className="font-mono text-[11px] text-ink-muted">
                    SIPP: {psy.sippNumber} · {psy.practiceSchedule}
                  </p>
                </div>
                <PracticeStatusBadge status={psy.status} />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
