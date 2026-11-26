import { useEffect } from 'react'

let activeLocks = 0
let savedHtmlOverflow = ''
let savedBodyOverflow = ''
let savedHtmlOverscroll = ''
let savedBodyOverscroll = ''
let savedBodyPaddingRight = ''

export function isBodyScrollLocked(): boolean {
  return activeLocks > 0
}

function applyScrollLock(): void {
  const html = document.documentElement
  const body = document.body

  savedHtmlOverflow = html.style.overflow
  savedBodyOverflow = body.style.overflow
  savedHtmlOverscroll = html.style.overscrollBehavior
  savedBodyOverscroll = body.style.overscrollBehavior
  savedBodyPaddingRight = body.style.paddingRight

  const scrollbarWidth = window.innerWidth - html.clientWidth
  if (scrollbarWidth > 0) {
    const currentPadding = Number.parseFloat(window.getComputedStyle(body).paddingRight) || 0
    body.style.paddingRight = `${currentPadding + scrollbarWidth}px`
  }

  html.style.overflow = 'hidden'
  body.style.overflow = 'hidden'
  html.style.overscrollBehavior = 'none'
  body.style.overscrollBehavior = 'none'

  window.__evaLenis?.stop()
}

function releaseScrollLock(): void {
  const html = document.documentElement
  const body = document.body

  html.style.overflow = savedHtmlOverflow
  body.style.overflow = savedBodyOverflow
  html.style.overscrollBehavior = savedHtmlOverscroll
  body.style.overscrollBehavior = savedBodyOverscroll
  body.style.paddingRight = savedBodyPaddingRight

  window.__evaLenis?.start()
}

/**
 * Reference-counted scroll lock for modals and overlays.
 * Locks both html/body overflow (with scrollbar compensation) and pauses Lenis smooth scroll.
 */
export function useBodyScrollLock(isLocked: boolean) {
  useEffect(() => {
    if (typeof document === 'undefined' || !isLocked) return

    if (activeLocks === 0) {
      applyScrollLock()
    }
    activeLocks += 1

    return () => {
      activeLocks = Math.max(0, activeLocks - 1)
      if (activeLocks === 0) {
        releaseScrollLock()
      }
    }
  }, [isLocked])
}
