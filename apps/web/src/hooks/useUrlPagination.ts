import { useMemo, useState, type RefObject } from 'react'
import { useSearchParams } from 'react-router'

interface UseUrlPaginationOptions<E extends HTMLElement = HTMLElement> {
  defaultPageSize?: number
  scrollTargetRef?: RefObject<E | null>
}

export function useUrlPagination<T, E extends HTMLElement = HTMLElement>(
  items: readonly T[],
  options?: UseUrlPaginationOptions<E>,
) {
  const defaultPageSize = options?.defaultPageSize ?? 10
  const scrollTargetRef = options?.scrollTargetRef

  const [searchParams, setSearchParams] = useSearchParams()
  const [pageSize, setPageSize] = useState(defaultPageSize)

  const rawPage = Number.parseInt(searchParams.get('page') ?? '1', 10)
  const requestedPage = Number.isFinite(rawPage) && rawPage > 0 ? rawPage : 1

  const totalPages = Math.max(1, Math.ceil(items.length / pageSize))
  const safePage = Math.min(requestedPage, totalPages)

  const paginatedItems = useMemo(() => {
    const startIndex = (safePage - 1) * pageSize
    return items.slice(startIndex, startIndex + pageSize)
  }, [items, safePage, pageSize])

  const updatePageParam = (nextPage: number) => {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      if (nextPage <= 1) {
        next.delete('page')
      } else {
        next.set('page', String(nextPage))
      }
      return next
    })
  }

  const resetPage = () => {
    if (searchParams.has('page')) {
      updatePageParam(1)
    }
  }

  const handlePageChange = (nextPage: number) => {
    const clampedPage = Math.min(Math.max(1, nextPage), totalPages)
    updatePageParam(clampedPage)
    const prefersReducedMotion =
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches
    scrollTargetRef?.current?.scrollIntoView({
      behavior: prefersReducedMotion ? 'auto' : 'smooth',
      block: 'nearest',
    })
  }

  const handlePageSizeChange = (nextSize: number) => {
    setPageSize(nextSize)
    if (searchParams.has('page')) {
      updatePageParam(1)
    }
  }

  return {
    pageSize,
    safePage,
    totalPages,
    paginatedItems,
    resetPage,
    handlePageChange,
    handlePageSizeChange,
  }
}
