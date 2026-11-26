import { motion } from 'motion/react'
import { Outlet, useLocation } from 'react-router'
import { Footer, Navbar } from '@/components/sections'
import { BreathingWidget, CustomCursor, ScrollToTop, SmoothScroll, WelcomeSplash } from '@/components/ui'
import { WelcomeAudioProvider } from '@/contexts/WelcomeAudioProvider'
import { usePrefersReducedMotion } from '@/hooks/useScroll'
import { useWelcomeAudio } from '@/hooks/useWelcomeAudio'
import { cn } from '@/lib/cn'

const SLIDE_UP_EASE = [0.22, 1, 0.36, 1] as const

function RootShell() {
  const { splashPhase, slideDurationMs, completeSlideUp } = useWelcomeAudio()
  const reducedMotion = usePrefersReducedMotion()
  const isSheetMode = splashPhase !== 'hidden'
  const isSlidingUp = splashPhase === 'sliding-up'

  return (
    <div
      className={cn(
        'relative flex min-h-screen flex-col bg-canvas',
        isSheetMode ? 'h-dvh overflow-clip' : 'overflow-x-clip',
      )}
    >
      <SmoothScroll />
      <CustomCursor />

      {/* Keyboard Accessibility Skip Link */}
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-[100] focus:rounded-pill focus:bg-primary focus:px-5 focus:py-2.5 focus:text-body-md focus:font-bold focus:text-white focus:shadow-fab"
      >
        Lewati ke konten utama
      </a>

      <WelcomeSplash />

      {/* Landing sheet keeps natural width and glides smoothly from 100dvh -> 0 over obsidian */}
      <motion.div
        id="eva-page-sheet"
        aria-hidden={isSheetMode}
        inert={isSheetMode}
        initial={false}
        animate={
          isSheetMode
            ? isSlidingUp
              ? { y: 0, opacity: 1 }
              : reducedMotion
                ? { y: 0, opacity: 0 }
                : { y: '110dvh', opacity: 1 }
            : { y: 0, opacity: 1 }
        }
        transformTemplate={(_, generated) => (isSheetMode ? generated : 'none')}
        transition={
          isSlidingUp
            ? { duration: slideDurationMs / 1000, ease: SLIDE_UP_EASE }
            : { duration: 0 }
        }
        onAnimationComplete={() => {
          if (isSlidingUp) completeSlideUp()
        }}
        className={cn(
          'relative flex min-h-screen flex-1 flex-col bg-canvas',
          isSlidingUp && 'z-70 pointer-events-none select-none',
          isSheetMode && !isSlidingUp && 'z-40 invisible pointer-events-none select-none',
        )}
        style={isSheetMode ? { willChange: 'transform, opacity' } : undefined}
      >
        <Navbar />
        <main id="main-content" className="flex-1">
          <Outlet />
        </main>
        <Footer />
      </motion.div>

      {/* Keep viewport-bottom controls outside transformed sheet to prevent re-parenting jitter */}
      {!isSheetMode && (
        <>
          <BreathingWidget />
          <ScrollToTop />
        </>
      )}
    </div>
  )
}

export function RootLayout() {
  const { pathname } = useLocation()
  return (
    <WelcomeAudioProvider enabled={pathname === '/'}>
      <RootShell />
    </WelcomeAudioProvider>
  )
}
