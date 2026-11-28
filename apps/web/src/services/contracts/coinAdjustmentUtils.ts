export type CoinAdjustmentMode = 'add' | 'deduct' | 'set'

export interface CoinAdjustmentPreview {
  valid: boolean
  delta: number
  nextBalance: number
  modeLabel: string
  error: string | null
}

/** Compute signed coin delta and resulting balance for an admin coin adjustment. */
export function computeCoinAdjustmentPreview(
  mode: CoinAdjustmentMode,
  rawAmount: number,
  currentBalance: number,
): CoinAdjustmentPreview {
  const safeCurrent = Math.max(0, Math.trunc(currentBalance || 0))
  const parsedAmount = Number.isFinite(rawAmount) ? Math.trunc(rawAmount) : NaN

  if (mode === 'add') {
    if (!Number.isFinite(parsedAmount) || parsedAmount < 1) {
      return {
        valid: false,
        delta: 0,
        nextBalance: safeCurrent,
        modeLabel: 'Penambahan Koin Admin',
        error: 'Nominal penambahan koin minimal 1.',
      }
    }
    return {
      valid: true,
      delta: parsedAmount,
      nextBalance: safeCurrent + parsedAmount,
      modeLabel: 'Penambahan Koin Admin',
      error: null,
    }
  }

  if (mode === 'deduct') {
    if (!Number.isFinite(parsedAmount) || parsedAmount < 1) {
      return {
        valid: false,
        delta: 0,
        nextBalance: safeCurrent,
        modeLabel: 'Pengurangan Koin Admin',
        error: 'Nominal pengurangan koin minimal 1.',
      }
    }
    if (parsedAmount > safeCurrent) {
      return {
        valid: false,
        delta: -parsedAmount,
        nextBalance: safeCurrent - parsedAmount,
        modeLabel: 'Pengurangan Koin Admin',
        error: `Pengurangan (${parsedAmount} Koin) melebihi saldo saat ini (${safeCurrent} Koin).`,
      }
    }
    return {
      valid: true,
      delta: -parsedAmount,
      nextBalance: safeCurrent - parsedAmount,
      modeLabel: 'Pengurangan Koin Admin',
      error: null,
    }
  }

  if (!Number.isFinite(parsedAmount) || parsedAmount < 0) {
    return {
      valid: false,
      delta: 0,
      nextBalance: safeCurrent,
      modeLabel: 'Set Saldo Koin Admin',
      error: 'Target saldo koin minimal 0.',
    }
  }
  const delta = parsedAmount - safeCurrent
  if (delta === 0) {
    return {
      valid: false,
      delta: 0,
      nextBalance: safeCurrent,
      modeLabel: 'Set Saldo Koin Admin',
      error: 'Target saldo sama dengan saldo koin saat ini.',
    }
  }
  return {
    valid: true,
    delta,
    nextBalance: parsedAmount,
    modeLabel: 'Set Saldo Koin Admin',
    error: null,
  }
}
