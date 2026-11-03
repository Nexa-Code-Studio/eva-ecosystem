import { useEffect, useRef, useState } from 'react'
import { FeatureScreen } from '@/components/mockups/AppScreens'
import { PhoneFrame } from '@/components/mockups/PhoneFrame'
import { Container, IconTile, SectionHeading } from '@/components/ui'
import { features, type FeatureId } from '@/content/landing'
import { usePrefersReducedMotion } from '@/hooks/useScroll'
import { cn } from '@/lib/cn'

const AUTO_CYCLE_MS = 4000

export function Features() {
  const [activeId, setActiveId] = useState<FeatureId>('voice')
  const [progress, setProgress] = useState(0)
  const [paused, setPaused] = useState(false)
  const reducedMotion = usePrefersReducedMotion()
  const active = features.find((f) => f.id === activeId)!

  const lastTimeRef = useRef<number | null>(null)

  // State-driven progress engine with delta time for 100% synchronized auto-cycling
  useEffect(() => {
    if (paused || reducedMotion) {
      lastTimeRef.current = null
      return
    }

    let animationFrameId: number

    const step = (now: number) => {
      if (lastTimeRef.current === null) {
        lastTimeRef.current = now
      }

      // Delta time capped to 100ms to avoid skipping on background tab restore
      const delta = Math.min(now - lastTimeRef.current, 100)
      lastTimeRef.current = now

      setProgress((prev) => {
        const next = prev + delta / AUTO_CYCLE_MS
        if (next >= 1) {
          setActiveId((curr) => {
            const idx = features.findIndex((f) => f.id === curr)
            return features[(idx + 1) % features.length].id
          })
          return 0
        }
        return next
      })

      animationFrameId = requestAnimationFrame(step)
    }

    animationFrameId = requestAnimationFrame(step)

    return () => {
      cancelAnimationFrame(animationFrameId)
      lastTimeRef.current = null
    }
  }, [paused, reducedMotion])

  const handleSelectFeature = (id: FeatureId) => {
    setActiveId(id)
    setProgress(0)
    lastTimeRef.current = null
  }

  const handleMouseEnter = () => {
    if (typeof window !== 'undefined' && window.matchMedia('(hover: hover)').matches) {
      setPaused(true)
    }
  }

  const handleMouseLeave = () => {
    if (typeof window !== 'undefined' && window.matchMedia('(hover: hover)').matches) {
      setPaused(false)
    }
  }

  const displayProgress = reducedMotion ? 1 : progress

  return (
    <section
      id="fitur"
      aria-labelledby="fitur-title"
      className="relative isolate flex min-h-[100dvh] w-full flex-col justify-center overflow-hidden bg-canvas py-16 sm:py-20 lg:py-24 border-t border-border-subtle/50"
    >
      <Container className="flex flex-col justify-center my-auto">
        <SectionHeading
          id="fitur-title"
          title={
            <>
              Dirancang untuk hari-hari yang <span className="text-primary">terasa berat</span>
            </>
          }
          description="Enam pendamping kecil yang bekerja bersama — dari curhat suara hingga jembatan ke psikolog profesional."
        />

        <div className="mt-14 grid items-start gap-10 lg:mt-20 lg:grid-cols-[1fr_420px] lg:gap-14 xl:grid-cols-[1fr_450px] xl:gap-20 2xl:grid-cols-[1fr_470px]">
          {/* Feature cards */}
          <div
            className="order-2 grid gap-6 sm:grid-cols-2 lg:order-1"
            role="group"
            aria-label="Pilih fitur untuk pratinjau"
            onMouseEnter={handleMouseEnter}
            onMouseLeave={handleMouseLeave}
            onFocusCapture={() => setPaused(true)}
            onBlurCapture={() => setPaused(false)}
          >
            {features.map((f) => {
              const Icon = f.icon
              const isActive = f.id === activeId
              return (
                <button
                  key={f.id}
                  id={`feature-${f.id}`}
                  type="button"
                  data-cursor="PRATINJAU"
                  aria-pressed={isActive}
                  aria-controls="feature-preview"
                  onClick={() => handleSelectFeature(f.id)}
                  className={cn(
                    'reveal group relative flex flex-col items-start rounded-card p-6 sm:p-8 text-left',
                    'border-[1.2px] transition-[transform,box-shadow,background-color,border-color] duration-300 ease-luna',
                    isActive
                      ? 'border-primary/25 bg-white shadow-nav lg:-translate-y-1'
                      : 'border-border-subtle/80 bg-white/80 shadow-subtle hover:-translate-y-1 hover:border-primary/20 hover:bg-white hover:shadow-nav',
                  )}
                >
                  {/* Floating progress bar inside card, safely clear of outer borders and 24px rounded corners */}
                  <span
                    aria-hidden
                    className={cn(
                      'absolute inset-x-6 sm:inset-x-8 top-3 sm:top-3.5 h-[3px] overflow-hidden rounded-full transition-opacity duration-300',
                      isActive ? 'bg-primary/12 opacity-100' : 'opacity-0 pointer-events-none',
                    )}
                  >
                    {isActive && (
                      <span
                        className="block h-full w-full origin-left rounded-full bg-primary will-change-transform"
                        style={{
                          transform: `scaleX(${displayProgress})`,
                        }}
                      />
                    )}
                  </span>

                  <div className="flex w-full items-center justify-between gap-3">
                    <IconTile
                      tone={f.tone}
                      className="transition-transform duration-300 ease-luna group-hover:scale-105"
                    >
                      <Icon />
                    </IconTile>
                    <span className="text-right text-[10px] font-extrabold tracking-[0.1em] text-ink-muted uppercase">
                      {f.tag}
                    </span>
                  </div>
                  <h3 className="mt-5 text-title-md sm:text-[19px]">{f.title}</h3>
                  <p className="mt-2 text-body-md text-ink-soft leading-relaxed">{f.body}</p>
                </button>
              )
            })}
          </div>

          {/* Sticky preview */}
          <div className="order-1 lg:sticky lg:top-28 lg:order-2">
            <div className="relative mx-auto flex w-fit flex-col items-center">
              <PhoneFrame className="w-[300px] sm:w-[330px] lg:w-[350px] xl:w-[370px]">
                <div
                  id="feature-preview"
                  key={activeId}
                  role="img"
                  aria-label={`Pratinjau layar: ${active.title}`}
                  className="h-full animate-enter"
                >
                  <FeatureScreen id={activeId} />
                </div>
              </PhoneFrame>

              {/* Mobile & Tablet Quick-Switcher Pills so users don't have to scroll down/up */}
              <div
                role="tablist"
                aria-label="Ganti layar pratinjau fitur cepat"
                className="mt-5 flex max-w-[350px] flex-wrap items-center justify-center gap-1.5 lg:hidden"
              >
                {features.map((f) => {
                  const Icon = f.icon
                  const isActive = f.id === activeId
                  return (
                    <button
                      key={`pill-${f.id}`}
                      type="button"
                      role="tab"
                      aria-selected={isActive}
                      onClick={() => handleSelectFeature(f.id)}
                      className={cn(
                        'inline-flex items-center gap-1.5 rounded-pill border px-3 py-1.5 text-caption !tracking-normal font-semibold transition-all duration-200',
                        isActive
                          ? 'border-primary bg-primary text-white shadow-btn'
                          : 'border-border-subtle bg-white text-ink-soft hover:border-primary/30 hover:text-ink',
                      )}
                    >
                      <Icon className="size-3.5" />
                      <span>{f.title.split(' ')[0]}</span>
                    </button>
                  )
                })}
              </div>

              <div
                className="mt-5 flex max-w-[360px] items-start gap-3 rounded-[18px] border border-border-subtle/80 bg-white p-4 shadow-subtle lg:mt-6"
                aria-live="polite"
              >
                <IconTile tone={active.tone} size="sm">
                  <active.icon />
                </IconTile>
                <div>
                  <p className="text-overline text-primary uppercase">Masalah yang diselesaikan</p>
                  <p className="mt-1 text-body-md text-ink">{active.problem}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </Container>
    </section>
  )
}
