import { Volume2 } from 'lucide-react'
import { AnimatePresence, motion } from 'motion/react'
import { useEffect, useRef, useState } from 'react'
import { BlurText, type BlurTextSegment } from '@/components/ui/BlurText'
import { LogoMark } from '@/components/ui/LunaOrb'
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

function AudioPermissionStage({
  reducedMotion,
  onAllow,
  onDecline,
}: {
  reducedMotion: boolean
  onAllow: () => void
  onDecline: () => void
}) {
  const allowBtnRef = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    allowBtnRef.current?.focus({ preventScroll: true })

    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault()
        onDecline()
        return
      }
      if (e.key === 'Tab') {
        e.preventDefault()
        allowBtnRef.current?.focus()
      }
    }

    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [onDecline])

  return (
    <motion.div
      key="audio-permission"
      initial={reducedMotion ? { opacity: 1 } : { opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={reducedMotion ? { opacity: 0 } : { opacity: 0, y: -10 }}
      transition={{ duration: reducedMotion ? 0 : 0.22, ease: [0.22, 1, 0.36, 1] }}
      className="relative z-10 mx-auto flex w-full max-w-lg flex-col items-center text-center"
    >
      <LogoMark className="size-16 sm:size-20" />

      <h2
        id="welcome-splash-title"
        className="mt-6 text-[clamp(1.55rem,3.4vw,2.15rem)] font-bold leading-[1.2] tracking-[-0.025em] text-white"
      >
        Izinkan pemutaran audio dan video
      </h2>

      <p
        id="welcome-splash-desc"
        className="mt-2.5 max-w-md text-body-md leading-[1.6] text-white/80 sm:text-[16px]"
      >
        Aktifkan izin putar di browser sebelum sapaan EVA dimulai.
      </p>

      <div className="mt-7 flex w-full justify-center sm:w-auto">
        <button
          id="welcome-audio-allow-btn"
          ref={allowBtnRef}
          type="button"
          onClick={onAllow}
          data-cursor="IZINKAN"
          className="inline-flex min-h-12 w-full cursor-pointer items-center justify-center gap-2.5 rounded-pill bg-primary px-7 py-3 text-sm font-bold text-white shadow-btn transition-[transform,filter,box-shadow] duration-[250ms] ease-luna hover:brightness-110 hover:shadow-fab active:scale-[0.98] focus-visible:outline-2 focus-visible:outline-primary-light focus-visible:outline-offset-[3px] sm:w-auto"
        >
          <Volume2 className="size-4 shrink-0" aria-hidden="true" />
          <span>Izinkan Audio &amp; Video</span>
        </button>
      </div>
    </motion.div>
  )
}

function ShowcaseStage({
  isSlidingUp,
  slideDurationMs,
  reducedMotion,
  onRequestSlideUp,
}: {
  isSlidingUp: boolean
  slideDurationMs: number
  reducedMotion: boolean
  onRequestSlideUp: () => void
}) {
  const [titleComplete, setTitleComplete] = useState(false)
  const holdTimerRef = useRef<number | null>(null)

  useEffect(() => {
    return () => {
      if (holdTimerRef.current !== null) {
        window.clearTimeout(holdTimerRef.current)
        holdTimerRef.current = null
      }
    }
  }, [])

  const handleSubtitleComplete = () => {
    if (!titleComplete || isSlidingUp) return
    if (holdTimerRef.current !== null) return
    holdTimerRef.current = window.setTimeout(() => {
      holdTimerRef.current = null
      onRequestSlideUp()
    }, reducedMotion ? 200 : SUBTITLE_HOLD_MS)
  }

  return (
    <motion.div
      key="showcase"
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
  )
}

/**
 * Obsidian pre-splash audio permission gate and typographic showcase curtain:
 * resolves browser audio autoplay permission via user gesture, then reveals "Hai, Aku EVA."
 * before sliding the landing page up.
 */
export function WelcomeSplash() {
  const {
    splashPhase,
    slideDurationMs,
    grantAudioPermission,
    declineAudioPermission,
    requestSlideUp,
  } = useWelcomeAudio()
  const reducedMotion = usePrefersReducedMotion()

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

      <AnimatePresence mode="wait">
        {splashPhase === 'awaiting-permission' ? (
          <AudioPermissionStage
            key="audio-permission"
            reducedMotion={reducedMotion}
            onAllow={grantAudioPermission}
            onDecline={declineAudioPermission}
          />
        ) : (
          <ShowcaseStage
            key="showcase"
            isSlidingUp={isSlidingUp}
            slideDurationMs={slideDurationMs}
            reducedMotion={reducedMotion}
            onRequestSlideUp={requestSlideUp}
          />
        )}
      </AnimatePresence>
    </div>
  )
}
