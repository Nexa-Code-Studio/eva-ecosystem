import { motion } from 'motion/react'
import { useEffect, useRef, useState } from 'react'
import { BlurText, type BlurTextSegment } from '@/components/ui/BlurText'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { usePrefersReducedMotion } from '@/hooks/useScroll'
import { useWelcomeAudio } from '@/hooks/useWelcomeAudio'
import { cn } from '@/lib/cn'

const TITLE_SEGMENTS: readonly BlurTextSegment[] = [
  { text: 'Hai,', extraDelayAfter: 1.15 },
  { text: ' Aku ' },
  { text: 'EVA.', className: 'text-primary-light' },
]

const SUBTITLE_HOLD_MS = 700

/**
 * Pure typographic obsidian splash stage featuring React Bits BlurText word-by-word
 * reveal for "Hai, Aku EVA.", followed smoothly by subtitle reveal and calm pause before page slide-up.
 */
export function WelcomeSplash() {
  const { splashPhase, slideDurationMs, requestSlideUp } = useWelcomeAudio()
  const reducedMotion = usePrefersReducedMotion()
  const [titleComplete, setTitleComplete] = useState(false)
  const holdTimerRef = useRef<number | null>(null)

  const isVisible = splashPhase !== 'hidden'
  const isSlidingUp = splashPhase === 'sliding-up'

  useBodyScrollLock(isVisible)

  // Pause Lenis smooth scrolling while the splash stage is active
  useEffect(() => {
    if (!isVisible) return undefined
    window.__evaLenis?.stop()
    return () => {
      window.__evaLenis?.start()
    }
  }, [isVisible])

  useEffect(() => {
    return () => {
      if (holdTimerRef.current !== null) {
        window.clearTimeout(holdTimerRef.current)
        holdTimerRef.current = null
      }
    }
  }, [])

  const handleSubtitleComplete = () => {
    if (!titleComplete || splashPhase !== 'showcase') return
    if (holdTimerRef.current !== null) return
    holdTimerRef.current = window.setTimeout(() => {
      holdTimerRef.current = null
      requestSlideUp()
    }, reducedMotion ? 200 : SUBTITLE_HOLD_MS)
  }

  if (!isVisible) return null

  return (
    <div
      id="welcome-splash"
      role="dialog"
      aria-modal="true"
      aria-hidden={isSlidingUp}
      aria-labelledby="welcome-splash-title"
      aria-describedby="welcome-splash-desc"
      data-cursor-theme="dark"
      data-lenis-prevent
      className={cn(
        'fixed inset-0 z-60 flex flex-col items-center justify-center overflow-hidden bg-obsidian px-6 py-12',
        isSlidingUp && 'pointer-events-none',
      )}
    >
      {/* Subtle brand indigo atmospheric glow */}
      <div aria-hidden className="pointer-events-none fixed inset-0 overflow-hidden">
        <div className="absolute top-1/2 left-1/2 size-[620px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[radial-gradient(circle,rgba(83,88,203,0.24)_0%,transparent_66%)] sm:size-[820px]" />
      </div>

      {/* Pure typographic word-by-word reveal receding gently behind rising page */}
      <motion.div
        animate={
          isSlidingUp
            ? reducedMotion
              ? { opacity: 0.4 }
              : { y: -24, scale: 0.96, opacity: 0.3 }
            : { y: 0, scale: 1, opacity: 1 }
        }
        transition={{
          duration: slideDurationMs / 1000,
          ease: [0.22, 1, 0.36, 1],
        }}
        className="relative z-10 mx-auto flex w-full max-w-5xl flex-col items-center text-center will-change-transform"
      >
        <h2
          id="welcome-splash-title"
          aria-label="Hai, Aku EVA."
          className="text-center text-[clamp(3.25rem,8.6vw,7.25rem)] font-extrabold leading-[1.06] tracking-[-0.04em] text-white"
        >
          <BlurText
            segments={TITLE_SEGMENTS}
            animateBy="words"
            delay={420}
            initialDelay={0.16}
            stepDuration={0.475}
            direction="bottom"
            onAnimationComplete={() => setTitleComplete(true)}
          />
        </h2>

        <motion.p
          id="welcome-splash-desc"
          initial={reducedMotion ? { opacity: 0 } : { opacity: 0, filter: 'blur(8px)', y: 12 }}
          animate={
            titleComplete
              ? reducedMotion
                ? { opacity: 1 }
                : { opacity: 1, filter: 'blur(0px)', y: 0 }
              : reducedMotion
                ? { opacity: 0 }
                : { opacity: 0, filter: 'blur(8px)', y: 12 }
          }
          transition={{
            duration: reducedMotion ? 0.2 : 0.85,
            ease: [0.22, 1, 0.36, 1],
          }}
          onAnimationComplete={handleSubtitleComplete}
          className="mt-4 text-[clamp(1.05rem,2.1vw,1.75rem)] font-medium tracking-[0.06em] text-white/80 sm:mt-5"
        >
          Empathetic Vitality Assistant
        </motion.p>
      </motion.div>
    </div>
  )
}
