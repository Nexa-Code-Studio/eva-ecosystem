import { RotateCcw, Smartphone } from 'lucide-react'
import { isDevToolsEnabled } from '@/lib/portalStore'

export { QuickLoginDevTool } from './QuickLoginDevTool'
export { MobilePsychologistSimulatorModal } from './MobilePsychologistSimulatorModal'

export function ResetPortalDataAction({ onReset }: { onReset: () => void }) {
  if (!isDevToolsEnabled()) return null

  return (
    <button
      type="button"
      onClick={onReset}
      title="Kembalikan database demo ke kondisi awal"
      className="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-[8px] border border-[#CBD5E1] bg-white px-2.5 text-xs font-semibold text-ink-muted transition-colors hover:border-amber-400 hover:text-ink"
    >
      <RotateCcw className="size-3.5" />
      <span className="hidden md:inline">Reset Demo</span>
    </button>
  )
}

export function MobilePsychologistSimulatorTrigger({ onOpen }: { onOpen: () => void }) {
  if (!isDevToolsEnabled()) return null

  return (
    <button
      type="button"
      onClick={onOpen}
      className="inline-flex h-9 shrink-0 cursor-pointer items-center gap-2 rounded-[8px] bg-primary px-3.5 text-xs font-semibold text-white shadow-btn transition-colors hover:bg-primary-hover"
    >
      <Smartphone className="size-4" />
      <span>Simulasi Pendaftaran &amp; Upgrade</span>
    </button>
  )
}

