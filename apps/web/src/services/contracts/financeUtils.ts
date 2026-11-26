const WIB_OFFSET_HOURS = 7
const WIB_OFFSET_MS = WIB_OFFSET_HOURS * 60 * 60 * 1000
const DAY_MS = 24 * 60 * 60 * 1000
const YMD_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/

export class PortalApiError extends Error {
  readonly status: number
  readonly code: string | null

  constructor(message: string, status: number, code: string | null = null) {
    super(message)
    this.name = 'PortalApiError'
    this.status = status
    this.code = code
  }
}

export function isAuthUnauthorizedError(error: unknown): boolean {
  return error instanceof PortalApiError && error.status === 401
}

export function formatYmdInWib(date: Date): string {
  const shifted = new Date(date.getTime() + WIB_OFFSET_MS)
  const year = shifted.getUTCFullYear()
  const month = String(shifted.getUTCMonth() + 1).padStart(2, '0')
  const day = String(shifted.getUTCDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

/**
 * Default inclusive WIB range covering the last 30 calendar days ending today in Asia/Jakarta.
 */
export function getDefaultWibDateRange(now: Date = new Date()): {
  fromDate: string
  toDate: string
} {
  const toDate = formatYmdInWib(now)
  const fromDate = formatYmdInWib(new Date(now.getTime() - 29 * DAY_MS))
  return { fromDate, toDate }
}

/**
 * Converts inclusive WIB calendar dates (YYYY-MM-DD) into a half-open UTC [from, to) ISO 8601 interval.
 * Example: 2026-11-01 .. 2026-11-30 WIB -> 2026-10-31T17:00:00.000Z .. 2026-11-30T17:00:00.000Z
 */
export function wibDateRangeToUtc(
  fromDateYmd: string,
  toDateYmd: string,
): { from: string; to: string } {
  const parseWibMidnightUtcMs = (ymd: string): number => {
    const match = YMD_PATTERN.exec(ymd.trim())
    if (!match) {
      throw new Error(`Format tanggal WIB tidak valid: ${ymd}`)
    }
    const year = Number(match[1])
    const month = Number(match[2])
    const day = Number(match[3])
    return Date.UTC(year, month - 1, day, 0, 0, 0, 0) - WIB_OFFSET_MS
  }

  const startMs = parseWibMidnightUtcMs(fromDateYmd)
  const endInclusiveStartMs = parseWibMidnightUtcMs(toDateYmd)
  const safeEndMs = Math.max(startMs, endInclusiveStartMs) + DAY_MS

  return {
    from: new Date(startMs).toISOString(),
    to: new Date(safeEndMs).toISOString(),
  }
}

/**
 * Formats integer IDR currency while distinguishing real 0 ("Rp0") from missing/null ("Tidak tersedia").
 */
export function formatIdrOrUnavailable(
  amount: number | null | undefined,
  unavailableLabel = 'Tidak tersedia',
): string {
  if (amount === null || amount === undefined || !Number.isFinite(amount)) {
    return unavailableLabel
  }
  const sign = amount < 0 ? '-' : ''
  const absFormatted = Math.round(Math.abs(amount)).toLocaleString('id-ID')
  return `${sign}Rp${absFormatted}`
}

const wibDateTimeFormatter = new Intl.DateTimeFormat('id-ID', {
  timeZone: 'Asia/Jakarta',
  day: '2-digit',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})

export function formatTimestampWib(
  isoUtc: string | null | undefined,
  fallbackLabel = 'Tidak tersedia',
): string {
  if (!isoUtc) return fallbackLabel
  const parsed = new Date(isoUtc)
  if (Number.isNaN(parsed.getTime())) return fallbackLabel
  return `${wibDateTimeFormatter.format(parsed).replace(/\./g, ':')} WIB`
}

export function parseBackendErrorDetail(
  status: number,
  body: unknown,
): { code: string | null; message: string } {
  if (body && typeof body === 'object') {
    const record = body as Record<string, unknown>
    const detail = record.detail
    if (typeof detail === 'string' && detail.trim().length > 0) {
      return { code: null, message: detail.trim() }
    }
    if (detail && typeof detail === 'object') {
      const detailObj = detail as Record<string, unknown>
      const code = typeof detailObj.code === 'string' ? detailObj.code : null
      const msg = typeof detailObj.message === 'string' ? detailObj.message.trim() : ''
      if (msg.length > 0) {
        return { code, message: msg }
      }
    }
  }

  if (status === 401) {
    return {
      code: 'UNAUTHORIZED',
      message: 'Sesi admin berakhir atau token tidak valid. Silakan login ulang.',
    }
  }
  if (status === 403) {
    return {
      code: 'FORBIDDEN',
      message: 'Akses ditolak. Akun Anda tidak memiliki izin melihat modul keuangan.',
    }
  }
  if (status === 404) {
    return {
      code: 'NOT_FOUND',
      message: 'Endpoint keuangan admin belum tersedia di server backend (Issue #136).',
    }
  }

  return { code: null, message: `Permintaan API gagal (${status})` }
}
