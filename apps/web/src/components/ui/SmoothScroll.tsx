import Lenis from 'lenis'
import { useEffect } from 'react'
import { scrollToCenteredSection, usePrefersReducedMotion } from '@/hooks/useScroll'

/**
 * Smooth inertial wheel & anchor scrolling powered by Lenis (same curve & duration as ekyamuhammad.com).
 * Intercepts all in-page anchor links to guarantee identical universal-centered scrolling across all buttons.
 */
export function SmoothScroll() {
  const reducedMotion = usePrefersReducedMotion()

  // Initialize Lenis for smooth wheel scrolling
  useEffect(() => {
    if (reducedMotion) return

    const lenis = new Lenis({
      duration: 1.2,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      smoothWheel: true,
    })
    window.__evaLenis = lenis

    let rafId = 0
    const raf = (time: number) => {
      lenis.raf(time)
      rafId = requestAnimationFrame(raf)
    }
    rafId = requestAnimationFrame(raf)

    return () => {
      cancelAnimationFrame(rafId)
      lenis.destroy()
      delete window.__evaLenis
    }
  }, [reducedMotion])

  // Universal click interceptor for all in-page anchor links (#section)
  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) {
        return
      }
      const target = e.target as Element | null
      const anchor = target?.closest('a[href^="#"]') as HTMLAnchorElement | null
      if (!anchor) return

      const href = anchor.getAttribute('href')
      if (!href || href === '#' || href.length < 2) return

      const id = href.slice(1)
      if (id === 'top' || document.getElementById(id)) {
        e.preventDefault()
        scrollToCenteredSection(id)
      }
    }

    document.addEventListener('click', onClick)
    return () => document.removeEventListener('click', onClick)
  }, [])

  return null
}
