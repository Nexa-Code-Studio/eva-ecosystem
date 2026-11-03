import type Lenis from 'lenis'
import { useEffect, useState } from 'react'

declare global {
  interface Window {
    __evaLenis?: Lenis
  }
}

/** True once the page is scrolled beyond `threshold` px. */
export function useScrolled(threshold = 12) {
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > threshold)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [threshold])

  return scrolled
}

/** Returns normalized scroll progress from 0 to 1. */
export function useScrollProgress() {
  const [progress, setProgress] = useState(0)

  useEffect(() => {
    const update = () => {
      const docHeight = document.documentElement.scrollHeight - window.innerHeight
      if (docHeight <= 0) {
        setProgress(0)
        return
      }
      const next = Math.min(1, Math.max(0, window.scrollY / docHeight))
      setProgress(next)
    }
    update()
    window.addEventListener('scroll', update, { passive: true })
    window.addEventListener('resize', update, { passive: true })
    return () => {
      window.removeEventListener('scroll', update)
      window.removeEventListener('resize', update)
    }
  }, [])

  return progress
}

/** Reactive prefers-reduced-motion media query hook. */
export function usePrefersReducedMotion() {
  const [reduced, setReduced] = useState(() =>
    typeof window === 'undefined'
      ? false
      : window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  )

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)')
    const onChange = (e: MediaQueryListEvent) => setReduced(e.matches)
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [])

  return reduced
}

/** Detects desktop fine pointer without touch primary input. */
export function useFinePointer() {
  const [pointer, setPointer] = useState({ isTouch: false, isFinePointer: false })

  useEffect(() => {
    const mq = window.matchMedia('(pointer: fine) and (hover: hover)')
    const update = () => {
      const isTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0
      setPointer({
        isTouch,
        isFinePointer: mq.matches,
      })
    }
    update()
    mq.addEventListener('change', update)
    return () => mq.removeEventListener('change', update)
  }, [])

  return pointer
}

/** Returns the id of the section currently in the middle band of the viewport. */
export function useActiveSection(ids: readonly string[]) {
  const [active, setActive] = useState<string | null>(null)

  useEffect(() => {
    const elements = ids
      .map((id) => document.getElementById(id))
      .filter((el): el is HTMLElement => el !== null)
    if (!elements.length) return

    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries.filter((e) => e.isIntersecting)
        if (visible.length) setActive(visible[0].target.id)
        else if (window.scrollY < 200) setActive(null)
      },
      { rootMargin: '-45% 0px -50% 0px' },
    )
    elements.forEach((el) => observer.observe(el))
    return () => observer.disconnect()
  }, [ids])

  return active
}

/**
 * Calculates the scroll position that vertically centers the main content of a section
 * in the viewport (on desktop/fits), or anchors it safely below the floating navbar (on mobile/long content).
 */
export function getCenteredSectionScrollTop(id: string): number | null {
  if (id === 'top') return 0

  const targetEl = document.getElementById(id)
  if (!targetEl) return null

  const isDesktop = typeof window !== 'undefined' && window.innerWidth >= 768
  const navOffset = isDesktop ? 78 : 74

  const isSection = targetEl.tagName.toLowerCase() === 'section'
  const cardEl = isSection
    ? (targetEl.querySelector('#early-access-card, [id$="-card"]') as HTMLElement | null)
    : null
  const contentEl =
    cardEl ||
    (isSection ? ((targetEl.querySelector(':scope > div') || targetEl) as HTMLElement) : targetEl)

  const rect = contentEl.getBoundingClientRect()
  const elementTop = rect.top + window.scrollY
  const elementHeight = rect.height
  const viewportHeight = window.innerHeight

  // Center content block in viewport if it fits (desktop); otherwise anchor safely below navbar
  const idealOffset = (viewportHeight - elementHeight) / 2
  const safeOffset = Math.max(navOffset + 16, idealOffset)
  return Math.max(0, elementTop - safeOffset)
}

/**
 * Universal centered smooth scroll handler for all in-page links and CTA buttons.
 * Uses Lenis if available for buttery-smooth inertial motion, or falls back to window.scrollTo.
 */
export function scrollToCenteredSection(id: string, updateHistory = true) {
  const scrollTop = getCenteredSectionScrollTop(id)
  if (scrollTop === null) return

  if (typeof window !== 'undefined' && window.__evaLenis) {
    window.__evaLenis.scrollTo(scrollTop, { duration: 1.2 })
  } else if (typeof window !== 'undefined') {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    window.scrollTo({
      top: scrollTop,
      behavior: prefersReducedMotion ? 'auto' : 'smooth',
    })
  }

  if (updateHistory && typeof window !== 'undefined') {
    history.pushState(null, '', id === 'top' ? '#top' : `#${id}`)
  }
}
