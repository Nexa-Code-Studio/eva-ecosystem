import {
  AlertTriangle,
  ArrowDownLeft,
  ArrowUpRight,
  Ban,
  CheckCircle2,
  Clock,
  HelpCircle,
  Loader2,
  RotateCcw,
  ShieldAlert,
  XCircle,
  type LucideIcon,
} from 'lucide-react'
import { cn } from '@/lib/cn'
import type { FinanceReconciliationStatus, FinanceSource } from '@/types/domain/finance'

interface StatusVisualConfig {
  label: string
  className: string
  icon: LucideIcon
}

const RECONCILIATION_STYLES: Record<FinanceReconciliationStatus, StatusVisualConfig> = {
  matched: {
    label: 'Cocok',
    className: 'border-emerald-200 bg-emerald-50 text-emerald-800',
    icon: CheckCircle2,
  },
  pending: {
    label: 'Menunggu',
    className: 'border-amber-200 bg-amber-50 text-amber-800',
    icon: Clock,
  },
  mismatch: {
    label: 'Selisih',
    className: 'border-rose-200 bg-rose-50 text-rose-800',
    icon: AlertTriangle,
  },
  review_required: {
    label: 'Perlu Tinjauan',
    className: 'border-orange-200 bg-orange-50 text-orange-800',
    icon: ShieldAlert,
  },
  unknown: {
    label: 'Tidak Diketahui',
    className: 'border-slate-200 bg-slate-100 text-ink-soft',
    icon: HelpCircle,
  },
}

const PAYMENT_STATUS_STYLES: Record<string, StatusVisualConfig> = {
  paid: {
    label: 'Lunas',
    className: 'border-emerald-200 bg-emerald-50 text-emerald-800',
    icon: CheckCircle2,
  },
  completed: {
    label: 'Selesai',
    className: 'border-emerald-200 bg-emerald-50 text-emerald-800',
    icon: CheckCircle2,
  },
  pending: {
    label: 'Menunggu Bayar',
    className: 'border-amber-200 bg-amber-50 text-amber-800',
    icon: Clock,
  },
  requested: {
    label: 'Diajukan',
    className: 'border-slate-200 bg-slate-100 text-ink',
    icon: Clock,
  },
  waiting_approval: {
    label: 'Menunggu Approval',
    className: 'border-amber-200 bg-amber-50 text-amber-800',
    icon: Clock,
  },
  processing: {
    label: 'Diproses',
    className: 'border-sky-200 bg-sky-50 text-sky-800',
    icon: Loader2,
  },
  reversed: {
    label: 'Dibalikkan (Reversal)',
    className: 'border-orange-200 bg-orange-50 text-orange-800',
    icon: RotateCcw,
  },
  review_required: {
    label: 'Perlu Tinjauan',
    className: 'border-orange-200 bg-orange-50 text-orange-800',
    icon: ShieldAlert,
  },
  expired: {
    label: 'Kedaluwarsa',
    className: 'border-slate-200 bg-slate-100 text-ink-soft',
    icon: Clock,
  },
  failed: {
    label: 'Gagal',
    className: 'border-rose-200 bg-rose-50 text-rose-800',
    icon: XCircle,
  },
  rejected: {
    label: 'Ditolak',
    className: 'border-rose-200 bg-rose-50 text-rose-800',
    icon: XCircle,
  },
  cancelled: {
    label: 'Dibatalkan',
    className: 'border-slate-200 bg-slate-100 text-ink-soft',
    icon: Ban,
  },
}

const SOURCE_LABELS: Record<FinanceSource, { label: string; isIn: boolean }> = {
  qris_topup: { label: 'QRIS Top-Up', isIn: true },
  counselor_payout: { label: 'Pencairan Psikolog', isIn: false },
  payment_refund: { label: 'Refund Pembayaran', isIn: false },
  payout_reversal: { label: 'Reversal Payout', isIn: false },
}

export function FinanceReconciliationBadge({ status }: { status: FinanceReconciliationStatus }) {
  const cfg = RECONCILIATION_STYLES[status] ?? RECONCILIATION_STYLES.unknown
  const Icon = cfg.icon
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-[6px] border px-2 py-0.5 text-[11px] font-semibold whitespace-nowrap',
        cfg.className,
      )}
    >
      <Icon className="size-3 shrink-0" aria-hidden="true" />
      <span>{cfg.label}</span>
    </span>
  )
}

export function FinancePaymentStatusBadge({ status }: { status: string }) {
  const normalized = status.trim().toLowerCase()
  const cfg =
    PAYMENT_STATUS_STYLES[normalized] ??
    (normalized in RECONCILIATION_STYLES
      ? RECONCILIATION_STYLES[normalized as FinanceReconciliationStatus]
      : undefined) ?? {
      label: status || 'Tidak diketahui',
      className: 'border-slate-200 bg-slate-100 text-ink-soft',
      icon: HelpCircle,
    }
  const Icon = cfg.icon
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-[6px] border px-2 py-0.5 text-[11px] font-semibold whitespace-nowrap',
        cfg.className,
      )}
    >
      <Icon className="size-3 shrink-0" aria-hidden="true" />
      <span>{cfg.label}</span>
    </span>
  )
}

export function FinanceSourceBadge({ source }: { source: FinanceSource }) {
  const cfg = SOURCE_LABELS[source] ?? SOURCE_LABELS.qris_topup
  const Icon = cfg.isIn ? ArrowDownLeft : ArrowUpRight
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-[6px] px-2 py-0.5 text-[11px] font-semibold whitespace-nowrap',
        cfg.isIn ? 'bg-[#EEF0FF] text-primary' : 'bg-[#F1F5F9] text-ink',
      )}
    >
      <Icon className="size-3 shrink-0" aria-hidden="true" />
      <span>{cfg.label}</span>
    </span>
  )
}
