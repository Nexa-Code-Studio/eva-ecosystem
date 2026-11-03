import { useEffect, useRef, useState } from 'react'
import { useFinePointer, usePrefersReducedMotion } from '@/hooks/useScroll'

/**
 * Custom cursor inspired by ekyamuhammad.com:
 * - 12x12px dot following mouse with smooth interpolation
 * - Morphs into a 28px rounded pill displaying uppercase contextual label on `[data-cursor="..."]`
 * - Automatically adapts to light pill on `[data-cursor-theme="dark"]` (e.g. Early Access section)
 * - Scales down over `<input>` / `<textarea>` so the native text caret remains unobstructed
 */
export function CustomCursor() {
  const cursorRef = useRef<HTMLDivElement>(null)
  const targetPos = useRef({ x: -100, y: -100 })
  const currentPos = useRef({ x: -100, y: -100 })
  const initialized = useRef(false)

  const [active, setActive] = useState(false)
  const [label, setLabel] = useState('')
  const [onDark, setOnDark] = useState(false)
  const [isTextInput, setIsTextInput] = useState(false)
  const [pressed, setPressed] = useState(false)

  const { isFinePointer, isTouch } = useFinePointer()
  const reducedMotion = usePrefersReducedMotion()
  const enabled = isFinePointer && !isTouch && !reducedMotion

  useEffect(() => {
    const root = document.documentElement
    if (enabled) {
      root.classList.add('has-custom-cursor')
    } else {
      root.classList.remove('has-custom-cursor')
    }
    return () => root.classList.remove('has-custom-cursor')
  }, [enabled])

  useEffect(() => {
    if (!enabled) return
    const el = cursorRef.current
    if (!el) return

    let rafId = 0
    const tick = () => {
      // Smooth exponential follow matching GSAP quickTo(0.18, power3.out)
      const lerpFactor = 0.24
      currentPos.current.x += (targetPos.current.x - currentPos.current.x) * lerpFactor
      currentPos.current.y += (targetPos.current.y - currentPos.current.y) * lerpFactor

      el.style.transform = `translate3d(${currentPos.current.x.toFixed(2)}px, ${currentPos.current.y.toFixed(2)}px, 0) translate(-50%, -50%)`
      rafId = requestAnimationFrame(tick)
    }

    const onMouseMove = (e: MouseEvent) => {
      targetPos.current.x = e.clientX
      targetPos.current.y = e.clientY
      if (!initialized.current) {
        currentPos.current.x = e.clientX
        currentPos.current.y = e.clientY
        initialized.current = true
      }
      setActive((prev) => (prev ? prev : true))

      const target = e.target as Element | null
      if (!target) return

      const darkRegion = target.closest('[data-cursor-theme="dark"]')
      setOnDark(Boolean(darkRegion))

      const textField = target.closest('input, textarea, select, [contenteditable="true"]')
      setIsTextInput(Boolean(textField))
    }

    const onMouseOver = (e: MouseEvent) => {
      const target = e.target as Element | null
      if (!target) return

      const textField = target.closest('input, textarea, select, [contenteditable="true"]')
      if (textField) {
        setIsTextInput(true)
        setLabel('')
        return
      }
      setIsTextInput(false)

      const cursorEl = target.closest('[data-cursor]')
      if (cursorEl) {
        setLabel(cursorEl.getAttribute('data-cursor') || '')
      } else {
        setLabel('')
      }
    }

    const onMouseDown = () => setPressed(true)
    const onMouseUp = () => setPressed(false)
    const onMouseLeave = () => {
      setActive(false)
      setPressed(false)
    }

    rafId = requestAnimationFrame(tick)
    window.addEventListener('mousemove', onMouseMove, { passive: true })
    document.addEventListener('mouseover', onMouseOver, { passive: true })
    window.addEventListener('mousedown', onMouseDown, { passive: true })
    window.addEventListener('mouseup', onMouseUp, { passive: true })
    document.addEventListener('mouseleave', onMouseLeave)

    return () => {
      cancelAnimationFrame(rafId)
      window.removeEventListener('mousemove', onMouseMove)
      document.removeEventListener('mouseover', onMouseOver)
      window.removeEventListener('mousedown', onMouseDown)
      window.removeEventListener('mouseup', onMouseUp)
      document.removeEventListener('mouseleave', onMouseLeave)
    }
  }, [enabled])

  if (!enabled) return null

  const classes = [
    'custom-cursor',
    active && 'is-active',
    label && 'has-label',
    onDark && 'is-on-dark',
    isTextInput && 'is-text-input',
    pressed && 'is-pressed',
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <div ref={cursorRef} className={classes} aria-hidden="true">
      <div className="cursor-pill">
        <span className="cursor-label">{label}</span>
      </div>
    </div>
  )
}

