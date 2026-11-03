import { Building2, KeyRound, X } from 'lucide-react'
import { Link } from 'react-router'
import { ADMIN_ACCOUNT } from '@/constants/portal'
import type { PartnerAccount } from '@/types/portal'

interface DemoAccountsMenuProps {
  isOpen: boolean
  partners: PartnerAccount[]
  onToggleOpen: () => void
  onClose: () => void
  onSelectCredentials: (email: string, password: string) => void
}

export function DemoAccountsMenu({
  isOpen,
  partners,
  onToggleOpen,
  onClose,
  onSelectCredentials,
}: DemoAccountsMenuProps) {
  const approvedDemo = partners.find((p) => p.status === 'approved') ?? partners[0]
  const pendingDemo = partners.find((p) => p.status === 'pending')
  const rejectedDemo = partners.find((p) => p.status === 'rejected')

  return (
    <div className="fixed right-5 bottom-5 z-40 flex flex-col items-end">
      {isOpen && (
        <div
          role="dialog"
          aria-label="Menu Akun Demo Cepat"
          className="mb-2.5 w-72 rounded-[12px] border border-[#E2E8F0] bg-white p-3.5 shadow-[0_10px_25px_rgba(15,23,42,0.1)]"
        >
          <div className="flex items-center justify-between border-b border-[#E2E8F0] pb-2.5">
            <div>
              <p className="text-xs font-semibold text-ink">Akun Demo (Isi Otomatis)</p>
              <p className="text-[11px] text-ink-muted">Klik untuk mengisi form login</p>
            </div>
            <button
              type="button"
              onClick={onClose}
              aria-label="Tutup menu akun demo"
              className="flex size-6 cursor-pointer items-center justify-center rounded-[6px] text-ink-soft hover:bg-[#F1F5F9] hover:text-ink"
            >
              <X className="size-3.5" />
            </button>
          </div>

          <div className="mt-2.5 flex flex-col gap-1.5">
            <button
              type="button"
              onClick={() => onSelectCredentials(ADMIN_ACCOUNT.email, ADMIN_ACCOUNT.password)}
              className="flex w-full cursor-pointer flex-col items-start rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] px-3 py-2 text-left transition-colors hover:border-primary/50 hover:bg-primary-container/25"
            >
              <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-ink">
                <span className="size-2 rounded-full bg-primary" /> Admin Website EVA
              </span>
              <span className="mt-0.5 text-[11px] text-ink-soft">{ADMIN_ACCOUNT.email}</span>
            </button>

            {approvedDemo && (
              <button
                type="button"
                onClick={() => onSelectCredentials(approvedDemo.email, approvedDemo.password)}
                className="flex w-full cursor-pointer flex-col items-start rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] px-3 py-2 text-left transition-colors hover:border-primary/50 hover:bg-primary-container/25"
              >
                <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-ink">
                  <span className="size-2 rounded-full bg-success" /> Mitra Faskes (Terverifikasi)
                </span>
                <span className="mt-0.5 w-full truncate text-[11px] text-ink-soft">
                  {approvedDemo.email}
                </span>
              </button>
            )}

            {pendingDemo && (
              <button
                type="button"
                onClick={() => onSelectCredentials(pendingDemo.email, pendingDemo.password)}
                className="flex w-full cursor-pointer flex-col items-start rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] px-3 py-2 text-left transition-colors hover:border-primary/50 hover:bg-primary-container/25"
              >
                <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-ink">
                  <span className="size-2 rounded-full bg-warning" /> Mitra Faskes (Pending)
                </span>
                <span className="mt-0.5 w-full truncate text-[11px] text-ink-soft">
                  {pendingDemo.email}
                </span>
              </button>
            )}

            {rejectedDemo && (
              <button
                type="button"
                onClick={() => onSelectCredentials(rejectedDemo.email, rejectedDemo.password)}
                className="flex w-full cursor-pointer flex-col items-start rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] px-3 py-2 text-left transition-colors hover:border-primary/50 hover:bg-primary-container/25"
              >
                <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-ink">
                  <span className="size-2 rounded-full bg-error" /> Mitra Faskes (Ditolak / Revisi)
                </span>
                <span className="mt-0.5 w-full truncate text-[11px] text-ink-soft">
                  {rejectedDemo.email}
                </span>
              </button>
            )}
          </div>

          <div className="mt-2.5 flex items-center justify-between border-t border-[#E2E8F0] pt-2 text-[11px] text-ink-muted">
            <span className="inline-flex items-center gap-1">
              <Building2 className="size-3" /> {partners.length} Faskes
            </span>
            <Link
              to="/pengajuan-mitra"
              onClick={onClose}
              className="font-semibold text-primary hover:underline"
            >
              + Pengajuan Baru
            </Link>
          </div>
        </div>
      )}

      <button
        type="button"
        onClick={onToggleOpen}
        aria-expanded={isOpen}
        aria-label="Buka daftar akun demo"
        className="inline-flex h-10 cursor-pointer items-center gap-2 rounded-full border border-[#CBD5E1] bg-white px-4 text-xs font-semibold text-ink shadow-[0_4px_12px_rgba(15,23,42,0.08)] transition-colors hover:border-primary/50 hover:text-primary"
      >
        <KeyRound className="size-3.5 text-primary" />
        <span>Akun Demo</span>
      </button>
    </div>
  )
}

