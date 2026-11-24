import { ChevronLeft, ChevronRight } from 'lucide-react'
import { useId } from 'react'
import { cn } from '@/lib/cn'

type PaginationToken = number | 'ellipsis-start' | 'ellipsis-end'

function buildPaginationRange(
  currentPage: number,
  totalPages: number,
): PaginationToken[] {
  if (totalPages <= 7) {
    return Array.from({ length: totalPages }, (_, index) => index + 1)
  }

  const tokens: PaginationToken[] = [1]
  const leftSibling = Math.max(2, currentPage - 1)
  const rightSibling = Math.min(totalPages - 1, currentPage + 1)

  if (leftSibling > 2) {
    tokens.push('ellipsis-start')
  } else {
    for (let p = 2; p < leftSibling; p += 1) {
      tokens.push(p)
    }
  }

  for (let p = leftSibling; p <= rightSibling; p += 1) {
    tokens.push(p)
  }

  if (rightSibling < totalPages - 1) {
    tokens.push('ellipsis-end')
  } else {
    for (let p = rightSibling + 1; p < totalPages; p += 1) {
      tokens.push(p)
    }
  }

  tokens.push(totalPages)
  return tokens
}

interface TablePaginationProps {
  currentPage: number
  totalItems: number
  pageSize: number
  pageSizeOptions?: number[]
  itemLabel?: string
  ariaLabel?: string
  onPageChange: (page: number) => void
  onPageSizeChange: (size: number) => void
}

export function TablePagination({
  currentPage,
  totalItems,
  pageSize,
  pageSizeOptions = [5, 10, 25, 50],
  itemLabel = 'data',
  ariaLabel,
  onPageChange,
  onPageSizeChange,
}: TablePaginationProps) {
  const selectId = useId()

  if (totalItems === 0) return null

  const totalPages = Math.max(1, Math.ceil(totalItems / pageSize))
  const safePage = Math.min(Math.max(1, currentPage), totalPages)
  const startItem = (safePage - 1) * pageSize + 1
  const endItem = Math.min(totalItems, safePage * pageSize)
  const rangeTokens = buildPaginationRange(safePage, totalPages)

  return (
    <nav
      aria-label={ariaLabel ?? `Paginasi ${itemLabel}`}
      className="flex flex-col gap-3 rounded-[12px] border border-[#E2E8F0] bg-white px-4 py-3 sm:flex-row sm:items-center sm:justify-between"
    >
      <div className="flex flex-wrap items-center justify-between gap-3 sm:justify-start">
        <p className="text-xs text-ink-soft tabular-nums">
          Menampilkan <span className="font-semibold text-ink">{startItem}-{endItem}</span> dari{' '}
          <span className="font-semibold text-ink">{totalItems}</span> {itemLabel}
        </p>

        <div className="flex items-center gap-2">
          <label htmlFor={selectId} className="text-xs text-ink-muted">
            Per halaman
          </label>
          <select
            id={selectId}
            value={pageSize}
            onChange={(e) => onPageSizeChange(Number(e.target.value))}
            className="min-h-11 cursor-pointer rounded-[8px] border border-[#CBD5E1] bg-[#F8FAFC] px-2.5 text-xs font-semibold text-ink tabular-nums transition-colors hover:border-primary/60 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary sm:min-h-9"
          >
            {pageSizeOptions.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="flex items-center justify-between gap-2 sm:justify-end">
        <button
          type="button"
          onClick={() => onPageChange(safePage - 1)}
          disabled={safePage <= 1}
          aria-label="Halaman sebelumnya"
          className="inline-flex min-h-11 min-w-11 cursor-pointer items-center justify-center gap-1 rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink transition-colors hover:bg-[#F8FAFC] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50 sm:min-h-9 sm:min-w-9 sm:px-2.5"
        >
          <ChevronLeft className="size-4 shrink-0" aria-hidden="true" />
          <span className="sm:hidden">Sebelumnya</span>
        </button>

        <span className="px-2 text-xs font-semibold text-ink tabular-nums sm:hidden">
          Hal. {safePage} / {totalPages}
        </span>

        <div className="hidden items-center gap-1 sm:flex">
          {rangeTokens.map((token) => {
            if (token === 'ellipsis-start' || token === 'ellipsis-end') {
              return (
                <span
                  key={token}
                  aria-hidden="true"
                  className="inline-flex min-h-9 min-w-7 items-center justify-center text-xs font-semibold text-ink-muted"
                >
                  ...
                </span>
              )
            }

            const isActive = token === safePage
            return (
              <button
                key={token}
                type="button"
                onClick={() => onPageChange(token)}
                aria-current={isActive ? 'page' : undefined}
                aria-label={`Halaman ${token}`}
                className={cn(
                  'inline-flex min-h-9 min-w-9 cursor-pointer items-center justify-center rounded-[8px] border px-2.5 text-xs font-semibold tabular-nums transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary',
                  isActive
                    ? 'border-primary bg-primary text-white'
                    : 'border-[#CBD5E1] bg-white text-ink hover:bg-[#F8FAFC]',
                )}
              >
                {token}
              </button>
            )
          })}
        </div>

        <button
          type="button"
          onClick={() => onPageChange(safePage + 1)}
          disabled={safePage >= totalPages}
          aria-label="Halaman berikutnya"
          className="inline-flex min-h-11 min-w-11 cursor-pointer items-center justify-center gap-1 rounded-[8px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink transition-colors hover:bg-[#F8FAFC] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50 sm:min-h-9 sm:min-w-9 sm:px-2.5"
        >
          <span className="sm:hidden">Berikutnya</span>
          <ChevronRight className="size-4 shrink-0" aria-hidden="true" />
        </button>
      </div>
    </nav>
  )
}
