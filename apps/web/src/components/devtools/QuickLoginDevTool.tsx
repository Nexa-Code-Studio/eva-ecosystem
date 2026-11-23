import { KeyRound, ShieldCheck, X } from 'lucide-react'
import { getAdminAccountConfig, isDevToolsEnabled } from '@/lib/portalStore'

interface QuickLoginDevToolProps {
  isOpen: boolean
  onToggleOpen: () => void
  onClose: () => void
  onSelectCredentials: (email: string, password: string) => void
}

export function QuickLoginDevTool({
  isOpen,
  onToggleOpen,
  onClose,
  onSelectCredentials,
}: QuickLoginDevToolProps) {
  if (!isDevToolsEnabled()) return null

  const adminAccount = getAdminAccountConfig()

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
              <p className="text-[11px] text-ink-muted">Klik untuk mengisi form login admin</p>
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
            {adminAccount.password ? (
              <button
                type="button"
                onClick={() => onSelectCredentials(adminAccount.email, adminAccount.password!)}
                className="flex w-full cursor-pointer flex-col items-start rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] px-3 py-2 text-left transition-colors hover:border-primary/50 hover:bg-primary-container/25"
              >
                <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-ink">
                  <span className="size-2 rounded-full bg-primary" /> Admin Website EVA
                </span>
                <span className="mt-0.5 text-[11px] text-ink-soft">{adminAccount.email}</span>
              </button>
            ) : (
              <p className="rounded-[8px] bg-[#F8FAFC] px-3 py-2 text-[11px] text-ink-muted">
                Akun demo admin belum dikonfigurasi pada environment.
              </p>
            )}
          </div>

          <div className="mt-2.5 flex items-center justify-between border-t border-[#E2E8F0] pt-2 text-[11px] text-ink-muted">
            <span className="inline-flex items-center gap-1">
              <ShieldCheck className="size-3 text-primary" /> Khusus Akses Admin EVA
            </span>
          </div>
        </div>
      )}

      <button
        type="button"
        onClick={onToggleOpen}
        aria-label="Buka daftar akun demo cepat"
        aria-expanded={isOpen}
        className="inline-flex h-10 cursor-pointer items-center gap-2 rounded-full border border-[#E2E8F0] bg-white px-3.5 text-xs font-semibold text-ink shadow-[0_6px_18px_rgba(15,23,42,0.1)] transition-all hover:border-primary/50 hover:text-primary"
      >
        <KeyRound className="size-3.5 text-primary" />
        <span>Akun Demo</span>
      </button>
    </div>
  )
}
