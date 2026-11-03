import { Pause, Play, RotateCcw, Wind, X } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'
import { LunaOrb } from './LunaOrb'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { scrollToCenteredSection } from '@/hooks/useScroll'
import { cn } from '@/lib/cn'

type Phase = 'inhale' | 'hold' | 'exhale'
type SessionState = 'ready' | 'running' | 'paused' | 'completed'

interface PhaseMeta {
  label: string
  hint: string
  scale: string
}

const PHASE_DURATION = 4 // 4-4-4 box/calming breath (seconds)
const TOTAL_CYCLES = 3

const PHASE_CONFIG: Record<Phase, PhaseMeta> = {
  inhale: { label: 'Tarik Napas Perlahan…', hint: 'Rasakan udara segar memenuhi dada melalui hidung', scale: 'scale-125' },
  hold: { label: 'Tahan Sejenak…', hint: 'Biarkan bahu dan rahangmu rileks sepenuhnya', scale: 'scale-125' },
  exhale: { label: 'Hembuskan Perlahan…', hint: 'Lepaskan ketegangan hari ini lewat mulut secara lembut', scale: 'scale-90' },
}

const NEXT_PHASE: Record<Phase, Phase> = {
  inhale: 'hold',
  hold: 'exhale',
  exhale: 'inhale',
}

/**
 * Floating micro-relief widget ("Jeda Tenang Bersama EVA")
 * Clean mindful breathing modal offering a 30-second guided 4-4-4 breathing session.
 */
export function BreathingWidget() {
  const [open, setOpen] = useState(false)
  const [state, setState] = useState<SessionState>('ready')
  const [phase, setPhase] = useState<Phase>('inhale')
  const [secondsLeft, setSecondsLeft] = useState(PHASE_DURATION)
  const [cycle, setCycle] = useState(1)

  useBodyScrollLock(open)

  const resetExercise = useCallback((autoStart = true) => {
    setPhase('inhale')
    setSecondsLeft(PHASE_DURATION)
    setCycle(1)
    setState(autoStart ? 'running' : 'ready')
  }, [])

  const openModal = useCallback(() => {
    setOpen(true)
    resetExercise(false)
  }, [resetExercise])

  const closeModal = useCallback(() => {
    setOpen(false)
    setState('ready')
  }, [])

  const startExercise = () => setState('running')
  const togglePause = () => setState((curr) => (curr === 'running' ? 'paused' : 'running'))

  // Listen for custom trigger from anywhere on the page
  useEffect(() => {
    window.addEventListener('eva:open-breathing', openModal)
    return () => window.removeEventListener('eva:open-breathing', openModal)
  }, [openModal])

  // Close on Escape
  useEffect(() => {
    if (!open) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') closeModal()
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [open, closeModal])

  // Breathing timer tick
  useEffect(() => {
    if (!open || state !== 'running') return

    const timer = window.setInterval(() => {
      setSecondsLeft((prev) => {
        if (prev > 1) return prev - 1

        setPhase((currentPhase) => {
          const next = NEXT_PHASE[currentPhase]
          if (currentPhase === 'exhale') {
            setCycle((currentCycle) => {
              if (currentCycle >= TOTAL_CYCLES) {
                setState('completed')
                return currentCycle
              }
              return currentCycle + 1
            })
          }
          return next
        })
        return PHASE_DURATION
      })
    }, 1000)

    return () => window.clearInterval(timer)
  }, [open, state])

  const meta = PHASE_CONFIG[phase]

  return (
    <>
      {/* Floating trigger pill at bottom-left */}
      <button
        type="button"
        onClick={openModal}
        data-cursor="TENANG"
        aria-label="Buka latihan tarik napas 30 detik bersama EVA"
        className="group fixed bottom-5 left-5 z-40 flex items-center gap-2.5 rounded-pill border border-primary/20 bg-white/95 py-2 pr-4 pl-2.5 text-left shadow-nav backdrop-blur-md transition-[transform,box-shadow,border-color] duration-300 ease-luna hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-fab"
      >
        <span className="relative flex size-8 items-center justify-center rounded-full bg-primary-container text-primary">
          <Wind className="size-4 transition-transform duration-300 group-hover:rotate-12" />
          <span className="absolute -top-0.5 -right-0.5 size-2.5 animate-ping rounded-full bg-primary/60" />
          <span className="absolute -top-0.5 -right-0.5 size-2.5 rounded-full bg-primary" />
        </span>
        <span className="flex flex-col">
          <span className="text-[10px] font-extrabold tracking-wider text-primary uppercase">Jeda Tenang</span>
          <span className="text-caption !tracking-normal font-bold text-ink">Tarik Napas 30 Detik</span>
        </span>
      </button>

      {/* Calming Breathing Modal */}
      {open && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="breathing-modal-title"
          className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6"
        >
          {/* Backdrop */}
          <div
            aria-hidden="true"
            onClick={closeModal}
            data-cursor="TUTUP"
            className="fixed inset-0 bg-obsidian/45 backdrop-blur-sm transition-opacity animate-enter"
          />

          {/* Dialog Card - Clean Mindful Therapy Style */}
          <div className="relative z-10 w-full max-w-md overflow-hidden rounded-[28px] border border-border-subtle/80 bg-white p-6 text-center text-ink shadow-2xl sm:p-8 animate-enter">
            {/* Close Button */}
            <div className="flex justify-end">
              <button
                type="button"
                onClick={closeModal}
                data-cursor="TUTUP"
                aria-label="Tutup latihan napas"
                className="flex size-9 items-center justify-center rounded-full text-ink-muted transition-colors hover:bg-slate-100 hover:text-ink"
              >
                <X className="size-4" />
              </button>
            </div>

            {/* Title & Hint */}
            <h3 id="breathing-modal-title" className="mt-2 text-headline font-bold text-ink">
              {state === 'ready'
                ? 'Ambil Napas Sejenak'
                : state === 'completed'
                  ? 'Pikiranmu Lebih Ringan 💜'
                  : meta.label}
            </h3>
            <p className="mt-1.5 min-h-[42px] text-body-md text-ink-soft">
              {state === 'ready'
                ? 'Cari posisi duduk yang nyaman, rilekskan bahu, dan ikuti ritme saat kamu sudah siap.'
                : state === 'completed'
                  ? 'Tiga siklus pernapasan 4-4-4 selesai. Terima kasih sudah memberi jeda untuk dirimu hari ini.'
                  : meta.hint}
            </p>

            {/* Animated LunaOrb centerpiece */}
            <div className="my-8 flex flex-col items-center justify-center">
              <div className="relative flex size-36 items-center justify-center">
                <div
                  className={cn(
                    'transition-transform duration-[4000ms] ease-in-out',
                    state === 'running' ? meta.scale : 'scale-100',
                  )}
                >
                  <LunaOrb className="size-28" />
                </div>
                {state !== 'ready' && state !== 'completed' && (
                  <span className="pointer-events-none absolute inset-0 flex items-center justify-center text-display font-extrabold text-ink drop-shadow-sm">
                    {secondsLeft}
                  </span>
                )}
              </div>
              <p className="mt-4 text-caption font-semibold tracking-wider text-primary uppercase">
                {state === 'ready'
                  ? 'Teknik Pernapasan 4-4-4 · 3 Siklus'
                  : state === 'completed'
                    ? 'Selesai · 3 / 3 Siklus'
                    : `Siklus ${cycle} dari ${TOTAL_CYCLES}`}
              </p>
            </div>

            {/* Controls */}
            <div className="flex items-center justify-center gap-3">
              {state === 'ready' && (
                <button
                  type="button"
                  onClick={startExercise}
                  data-cursor="MULAI"
                  className="inline-flex h-12 items-center gap-2 rounded-pill bg-primary px-8 text-body-md font-bold text-white shadow-btn transition-transform hover:scale-[1.02] hover:shadow-fab"
                >
                  <Play className="size-4 fill-white" /> Mulai Latihan
                </button>
              )}

              {(state === 'running' || state === 'paused') && (
                <>
                  <button
                    type="button"
                    onClick={togglePause}
                    data-cursor={state === 'running' ? 'JEDA' : 'LANJUT'}
                    className="inline-flex h-11 items-center gap-2 rounded-pill bg-primary px-6 text-body-md font-bold text-white shadow-btn transition-transform hover:scale-[1.02]"
                  >
                    {state === 'running' ? (
                      <><Pause className="size-4" /> Jeda</>
                    ) : (
                      <><Play className="size-4 fill-white" /> Lanjutkan</>
                    )}
                  </button>
                  <button
                    type="button"
                    onClick={() => resetExercise(true)}
                    data-cursor="ULANGI"
                    aria-label="Mulai ulang latihan"
                    className="inline-flex size-11 items-center justify-center rounded-full border border-border-subtle bg-slate-50 text-ink-soft transition-colors hover:bg-slate-150 hover:text-ink"
                  >
                    <RotateCcw className="size-4" />
                  </button>
                </>
              )}

              {state === 'completed' && (
                <>
                  <button
                    type="button"
                    onClick={() => resetExercise(true)}
                    data-cursor="ULANGI"
                    className="inline-flex h-11 items-center gap-2 rounded-pill border border-border-subtle bg-white px-5 text-body-md font-semibold text-ink transition-colors hover:bg-slate-50"
                  >
                    <RotateCcw className="size-4" /> Ulangi
                  </button>
                  <a
                    href="#early-access"
                    onClick={(e) => {
                      e.preventDefault()
                      closeModal()
                      requestAnimationFrame(() => {
                        scrollToCenteredSection('early-access')
                      })
                    }}
                    data-cursor="GABUNG"
                    className="inline-flex h-11 items-center gap-2 rounded-pill bg-primary px-6 text-body-md font-bold text-white shadow-btn transition-transform hover:scale-[1.02]"
                  >
                    Akses Fitur Penuh
                  </a>
                </>
              )}
            </div>
          </div>
        </div>
      )}
    </>
  )
}
