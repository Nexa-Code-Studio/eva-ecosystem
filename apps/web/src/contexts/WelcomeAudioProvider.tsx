import { type ReactNode, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { usePrefersReducedMotion } from '@/hooks/useScroll'
import {
  type AudioPermissionState,
  type SplashPhase,
  WelcomeAudioContext,
  type WelcomeAudioContextValue,
} from '@/hooks/useWelcomeAudio'

const STORAGE_KEY = 'eva_welcome_seen'
const WELCOME_AUDIO_SRC = '/audio/eva-welcome.mp3'
const SHOWCASE_FALLBACK_MS = 6600
const REDUCED_SHOWCASE_MS = 900
const SLIDE_UP_MS = 1200
const REDUCED_SLIDE_MS = 220
const SLIDE_FALLBACK_BUFFER_MS = 450
const PRE_PLAY_SLEEP_MS = 500
const GESTURE_EVENTS = ['pointerdown', 'click', 'touchend', 'keydown'] as const
const UNLOCK_TRIGGER_KEYS = new Set(['Enter', ' ', 'ArrowDown', 'PageDown'])

function addCaptureGestureListeners(handler: (e: Event) => void): () => void {
  for (const eventName of GESTURE_EVENTS) {
    window.addEventListener(eventName, handler, { capture: true })
  }
  return () => {
    for (const eventName of GESTURE_EVENTS) {
      window.removeEventListener(eventName, handler, { capture: true })
    }
  }
}

type NavigationWithDelivery = PerformanceNavigationTiming & { deliveryType?: string }

let consumedHardReload = false

function readWelcomeSeen(): boolean {
  if (typeof window === 'undefined') return false
  try {
    return window.sessionStorage.getItem(STORAGE_KEY) === '1'
  } catch {
    return false
  }
}

function writeWelcomeSeen(): void {
  if (typeof window === 'undefined') return
  try {
    window.sessionStorage.setItem(STORAGE_KEY, '1')
  } catch {
    // Session storage unavailable — degrade without breaking splash lifecycle
  }
}

/**
 * Distinguishes cache-bypassing hard reloads (Ctrl+Shift+R / DevTools Empty Cache & Hard Reload)
 * from normal cached/304 reloads (Ctrl+R / F5) using Navigation Timing metadata.
 */
function isHardReloadNavigation(): boolean {
  if (typeof window === 'undefined' || typeof performance === 'undefined') return false
  const nav = performance.getEntriesByType('navigation')[0] as NavigationWithDelivery | undefined
  if (!nav || nav.type !== 'reload') return false
  if (nav.deliveryType === 'cache') return false
  if (nav.transferSize === 0) return false
  return nav.encodedBodySize > 0 && nav.transferSize > nav.encodedBodySize
}

function shouldShowSplashOnEntry(enabled: boolean): boolean {
  if (!enabled || typeof window === 'undefined') return false
  if (isHardReloadNavigation() && !consumedHardReload) return true
  return !readWelcomeSeen()
}

/**
 * Coordinates per-session + hard-reload kinetic entrance splash timing (~4.2s letter-by-letter
 * reveal -> 1.2s landing sheet slide-up -> voice greeting playback) and Hero replay controls.
 */
export function WelcomeAudioProvider({
  enabled = true,
  children,
}: {
  enabled?: boolean
  children: ReactNode
}) {
  const reducedMotion = usePrefersReducedMotion()
  const slideDurationMs = reducedMotion ? REDUCED_SLIDE_MS : SLIDE_UP_MS

  const [splashPhase, setSplashPhase] = useState<SplashPhase>(() =>
    shouldShowSplashOnEntry(enabled) ? 'awaiting-permission' : 'hidden',
  )
  const [audioPermission, setAudioPermission] = useState<AudioPermissionState>('prompt')
  const [isPlaying, setIsPlaying] = useState(false)
  const [isWaitingBeforePlay, setIsWaitingBeforePlay] = useState(false)
  const [isAutoplayBlocked, setIsAutoplayBlocked] = useState(false)
  const [hasAudioError, setHasAudioError] = useState(false)
  const [analyserNode, setAnalyserNode] = useState<AnalyserNode | null>(null)

  const splashPhaseRef = useRef<SplashPhase>(splashPhase)
  const audioPermissionRef = useRef<AudioPermissionState>(audioPermission)
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const audioCtxRef = useRef<AudioContext | null>(null)
  const mediaSourceRef = useRef<MediaElementAudioSourceNode | null>(null)
  const analyserRef = useRef<AnalyserNode | null>(null)
  const showcaseTimerRef = useRef<number | null>(null)
  const slideTimerRef = useRef<number | null>(null)
  const playDelayTimerRef = useRef<number | null>(null)
  const userDismissedPromptRef = useRef(false)
  const unlockInFlightRef = useRef(false)
  const isPrimingRef = useRef(false)
  const isPendingPlayRef = useRef(false)
  const playSequenceRef = useRef(0)
  const primeInFlightRef = useRef(false)
  const hasPrimedRef = useRef(false)

  const updateSplashPhase = useCallback((next: SplashPhase) => {
    splashPhaseRef.current = next
    setSplashPhase(next)
  }, [])

  const updateAudioPermission = useCallback((next: AudioPermissionState) => {
    audioPermissionRef.current = next
    setAudioPermission(next)
  }, [])

  const clearPlayDelayTimer = useCallback(() => {
    if (typeof window === 'undefined') return
    if (playDelayTimerRef.current !== null) {
      window.clearTimeout(playDelayTimerRef.current)
      playDelayTimerRef.current = null
    }
  }, [])

  const clearSplashTimers = useCallback(() => {
    if (typeof window === 'undefined') return
    if (showcaseTimerRef.current !== null) {
      window.clearTimeout(showcaseTimerRef.current)
      showcaseTimerRef.current = null
    }
    if (slideTimerRef.current !== null) {
      window.clearTimeout(slideTimerRef.current)
      slideTimerRef.current = null
    }
  }, [])

  const connectAnalyserGraph = useCallback((ctx: AudioContext, audio: HTMLAudioElement) => {
    if (mediaSourceRef.current || audioCtxRef.current !== ctx || audioRef.current !== audio) {
      return
    }
    try {
      const source = ctx.createMediaElementSource(audio)
      const analyser = ctx.createAnalyser()
      analyser.fftSize = 1024
      analyser.smoothingTimeConstant = 0.72
      source.connect(analyser)
      analyser.connect(ctx.destination)
      mediaSourceRef.current = source
      analyserRef.current = analyser
      setAnalyserNode(analyser)
    } catch {
      // Keep native audio output unaffected if graph binding fails or already attached
    }
  }, [])

  const ensureAnalyserGraph = useCallback(() => {
    if (typeof window === 'undefined') return
    const audio = audioRef.current
    if (!audio) return

    const existingCtx = audioCtxRef.current
    if (existingCtx && existingCtx.state !== 'closed') {
      if (existingCtx.state === 'suspended') {
        void existingCtx
          .resume()
          .then(() => {
            if (existingCtx.state === 'running' && !mediaSourceRef.current) {
              connectAnalyserGraph(existingCtx, audio)
            }
          })
          .catch(() => {})
      } else if (!mediaSourceRef.current) {
        connectAnalyserGraph(existingCtx, audio)
      }
      return
    }

    const AudioCtxCtor =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
    if (!AudioCtxCtor) return

    try {
      const ctx = new AudioCtxCtor()
      audioCtxRef.current = ctx

      if (ctx.state === 'running') {
        connectAnalyserGraph(ctx, audio)
        return
      }

      if (ctx.state === 'suspended') {
        void ctx
          .resume()
          .then(() => {
            if (ctx.state === 'running') {
              connectAnalyserGraph(ctx, audio)
            }
          })
          .catch(() => {
            // AudioContext awaiting user gesture; HTMLAudioElement remains audible until resumed
          })
      }
    } catch {
      // AudioContext unavailable in restricted environment; fallback animation still renders
    }
  }, [connectAnalyserGraph])

  const startPlayback = useCallback(
    (restart = false, fromUserGesture = false) => {
      const audio = audioRef.current
      if (!audio) return

      clearPlayDelayTimer()
      isPendingPlayRef.current = false
      const seq = ++playSequenceRef.current

      if (audio.error) {
        audio.load()
      }

      const resumePosition = restart || audio.ended || audio.readyState < 1 ? 0 : audio.currentTime
      const delayMs = reducedMotion ? 0 : PRE_PLAY_SLEEP_MS
      const canProbeMuted = fromUserGesture || hasPrimedRef.current

      if (fromUserGesture) {
        ensureAnalyserGraph()
      }

      // Probe playback eligibility and prime hardware sink without emitting clipped audio during the 500ms expand wait
      isPrimingRef.current = true
      if (canProbeMuted) {
        audio.muted = true
        audio.volume = 1
      } else {
        audio.muted = false
        audio.volume = 0
      }
      setHasAudioError(false)

      const finishBlockedOrErrored = (err: unknown) => {
        unlockInFlightRef.current = false
        if (seq !== playSequenceRef.current) return
        isPrimingRef.current = false
        isPendingPlayRef.current = false
        setIsWaitingBeforePlay(false)
        audio.muted = false
        audio.volume = 1
        setIsPlaying(false)
        const errorName = err instanceof DOMException ? err.name : ''
        if (errorName === 'NotAllowedError' || (errorName === 'AbortError' && !audio.error)) {
          setIsAutoplayBlocked(true)
          return
        }
        setHasAudioError(true)
      }

      const beginExpandedSleepThenPlay = () => {
        unlockInFlightRef.current = false
        if (seq !== playSequenceRef.current) {
          audio.pause()
          audio.muted = false
          audio.volume = 1
          if (audio.paused) isPrimingRef.current = false
          return
        }

        hasPrimedRef.current = true
        setIsAutoplayBlocked(false)
        setHasAudioError(false)

        if (delayMs <= 0) {
          audio.muted = false
          audio.volume = 1
          if (audio.readyState >= 1 && Math.abs(audio.currentTime - resumePosition) > 0.08) {
            audio.currentTime = resumePosition
          }
          isPrimingRef.current = false
          setIsWaitingBeforePlay(false)
          ensureAnalyserGraph()
          setIsPlaying(true)
          return
        }

        // Suppress queued HTMLMediaElement 'pause' event while paused intentionally during the 500ms expand sleep
        isPendingPlayRef.current = true
        setIsWaitingBeforePlay(true)
        setIsPlaying(true)

        const pausedSynchronously = audio.paused
        audio.pause()
        if (pausedSynchronously) {
          isPrimingRef.current = false
        }
        if (audio.readyState >= 1) {
          audio.currentTime = resumePosition
        }
        audio.muted = false
        audio.volume = 1

        // Warm up Web Audio sink during the card expand transition so initial syllables do not clip
        ensureAnalyserGraph()

        const startAudiblePlayback = () => {
          if (seq !== playSequenceRef.current) return
          isPendingPlayRef.current = false
          isPrimingRef.current = false
          playDelayTimerRef.current = null
          setIsWaitingBeforePlay(false)
          audio.muted = false
          audio.volume = 1
          if (audio.readyState >= 1) {
            audio.currentTime = resumePosition
          }
          ensureAnalyserGraph()

          unlockInFlightRef.current = true
          const playPromise = audio.play()
          if (playPromise) {
            playPromise
              .catch((err: unknown) => {
                if (seq !== playSequenceRef.current) return
                setIsPlaying(false)
                const errorName = err instanceof DOMException ? err.name : ''
                if (
                  errorName === 'NotAllowedError' ||
                  (errorName === 'AbortError' && !audio.error)
                ) {
                  setIsAutoplayBlocked(true)
                  return
                }
                setHasAudioError(true)
              })
              .finally(() => {
                unlockInFlightRef.current = false
              })
          } else {
            unlockInFlightRef.current = false
          }
        }

        playDelayTimerRef.current = window.setTimeout(startAudiblePlayback, delayMs)
      }

      unlockInFlightRef.current = true
      const probePromise = audio.play()
      if (probePromise) {
        probePromise
          .then(() => {
            beginExpandedSleepThenPlay()
          })
          .catch((err: unknown) => {
            finishBlockedOrErrored(err)
          })
      } else {
        beginExpandedSleepThenPlay()
      }
    },
    [clearPlayDelayTimer, ensureAnalyserGraph, reducedMotion],
  )

  const completeSlideUp = useCallback(() => {
    if (splashPhaseRef.current !== 'sliding-up') return
    clearSplashTimers()
    isPrimingRef.current = false
    updateSplashPhase('hidden')
    if (audioPermissionRef.current === 'denied') return
    ensureAnalyserGraph()
    startPlayback(true, hasPrimedRef.current)
  }, [clearSplashTimers, ensureAnalyserGraph, startPlayback, updateSplashPhase])

  const primeAudioElement = useCallback(
    (fromPermissionGate = false) => {
      const audio = audioRef.current
      if (!audio || hasPrimedRef.current || primeInFlightRef.current) return
      if (audio.error) {
        audio.load()
      }

      primeInFlightRef.current = true
      isPrimingRef.current = true
      const seqAtPrime = playSequenceRef.current
      audio.muted = true
      audio.volume = 1

      const playPromise = audio.play()
      if (playPromise) {
        playPromise
          .then(() => {
            hasPrimedRef.current = true
            // Complete slide-up already started a newer playback sequence; leave it untouched
            if (playSequenceRef.current !== seqAtPrime) return

            const shouldAutoplayNow =
              splashPhaseRef.current === 'hidden' &&
              audioPermissionRef.current !== 'denied' &&
              !fromPermissionGate
            const alreadyPaused = audio.paused
            audio.pause()
            if (alreadyPaused) isPrimingRef.current = false
            if (audio.readyState >= 1) {
              audio.currentTime = 0
            }
            audio.muted = false
            audio.volume = 1
            if (shouldAutoplayNow) {
              startPlayback(true, true)
            }
          })
          .catch(() => {
            if (playSequenceRef.current === seqAtPrime) {
              audio.muted = false
              audio.volume = 1
              isPrimingRef.current = false
            }
          })
          .finally(() => {
            primeInFlightRef.current = false
          })
      } else {
        hasPrimedRef.current = true
        audio.pause()
        audio.muted = false
        isPrimingRef.current = false
        primeInFlightRef.current = false
      }
    },
    [startPlayback],
  )

  const grantAudioPermission = useCallback(() => {
    if (splashPhaseRef.current !== 'awaiting-permission') return
    updateAudioPermission('granted')
    userDismissedPromptRef.current = false
    setIsAutoplayBlocked(false)
    setHasAudioError(false)
    ensureAnalyserGraph()
    primeAudioElement(true)
    updateSplashPhase('showcase')
  }, [ensureAnalyserGraph, primeAudioElement, updateAudioPermission, updateSplashPhase])

  const declineAudioPermission = useCallback(() => {
    if (splashPhaseRef.current !== 'awaiting-permission') return
    updateAudioPermission('denied')
    userDismissedPromptRef.current = true
    setIsAutoplayBlocked(false)
    updateSplashPhase('showcase')
  }, [updateAudioPermission, updateSplashPhase])

  const requestSlideUp = useCallback(() => {
    if (splashPhaseRef.current !== 'showcase') return

    clearSplashTimers()
    consumedHardReload = true
    userDismissedPromptRef.current = false
    writeWelcomeSeen()
    updateSplashPhase('sliding-up')

    // Watchdog guarantees phase completion even if a backgrounded tab throttles Motion RAF
    slideTimerRef.current = window.setTimeout(() => {
      slideTimerRef.current = null
      completeSlideUp()
    }, slideDurationMs + SLIDE_FALLBACK_BUFFER_MS)
  }, [clearSplashTimers, completeSlideUp, slideDurationMs, updateSplashPhase])

  // Initialize shared HTMLAudioElement once
  useEffect(() => {
    if (typeof window === 'undefined') return undefined

    const audio = new Audio(WELCOME_AUDIO_SRC)
    audio.preload = 'auto'
    audioRef.current = audio

    const onPlay = () => {
      if (isPrimingRef.current) return
      setIsPlaying(true)
      setIsAutoplayBlocked(false)
      setHasAudioError(false)
    }
    const onPause = () => {
      if (isPendingPlayRef.current || isPrimingRef.current) {
        isPrimingRef.current = false
        return
      }
      setIsPlaying(false)
    }
    const onEnded = () => setIsPlaying(false)
    const onError = () => {
      if (isPrimingRef.current) return
      setIsPlaying(false)
      setHasAudioError(true)
    }

    audio.addEventListener('play', onPlay)
    audio.addEventListener('pause', onPause)
    audio.addEventListener('ended', onEnded)
    audio.addEventListener('error', onError)

    return () => {
      playSequenceRef.current += 1
      clearSplashTimers()
      clearPlayDelayTimer()
      isPendingPlayRef.current = false
      audio.pause()
      audio.removeEventListener('play', onPlay)
      audio.removeEventListener('pause', onPause)
      audio.removeEventListener('ended', onEnded)
      audio.removeEventListener('error', onError)
      if (mediaSourceRef.current) {
        try {
          mediaSourceRef.current.disconnect()
        } catch {
          // Node already disconnected
        }
        mediaSourceRef.current = null
      }
      if (analyserRef.current) {
        try {
          analyserRef.current.disconnect()
        } catch {
          // Node already disconnected
        }
        analyserRef.current = null
      }
      if (audioCtxRef.current) {
        const ctx = audioCtxRef.current
        audioCtxRef.current = null
        if (ctx.state !== 'closed') {
          void ctx.close().catch(() => {})
        }
      }
      setIsWaitingBeforePlay(false)
      setAnalyserNode(null)
      audio.src = ''
      audioRef.current = null
    }
  }, [clearPlayDelayTimer, clearSplashTimers])

  // Safety fallback for showcase -> slide-up if animation callbacks stall (or reduced motion)
  useEffect(() => {
    if (!enabled) {
      clearSplashTimers()
      if (splashPhaseRef.current !== 'hidden') {
        updateSplashPhase('hidden')
      }
      return undefined
    }

    if (splashPhase !== 'showcase' || typeof window === 'undefined') return undefined

    const fallbackMs = reducedMotion ? REDUCED_SHOWCASE_MS : SHOWCASE_FALLBACK_MS
    showcaseTimerRef.current = window.setTimeout(() => {
      showcaseTimerRef.current = null
      requestSlideUp()
    }, fallbackMs)

    return clearSplashTimers
  }, [clearSplashTimers, enabled, reducedMotion, requestSlideUp, splashPhase, updateSplashPhase])

  const toggleAudio = useCallback(() => {
    const audio = audioRef.current
    if (!audio) return

    if (isPendingPlayRef.current || (!audio.paused && !audio.ended)) {
      playSequenceRef.current += 1
      clearPlayDelayTimer()
      isPendingPlayRef.current = false
      isPrimingRef.current = false
      setIsWaitingBeforePlay(false)
      audio.muted = false
      audio.volume = 1
      userDismissedPromptRef.current = true
      audio.pause()
      setIsPlaying(false)
      return
    }
    updateAudioPermission('granted')
    userDismissedPromptRef.current = false
    startPlayback(audio.ended, true)
  }, [clearPlayDelayTimer, startPlayback, updateAudioPermission])

  const dismissAutoplayPrompt = useCallback(() => {
    userDismissedPromptRef.current = true
    setIsAutoplayBlocked(false)
  }, [])

  // Prime audio silently on any click/tap/key during splash showcase if still unprimed (and not declined)
  useEffect(() => {
    if (
      splashPhase === 'hidden' ||
      splashPhase === 'awaiting-permission' ||
      audioPermission === 'denied' ||
      hasPrimedRef.current ||
      typeof window === 'undefined'
    ) {
      return undefined
    }

    const primeOnSplashGesture = (e: Event) => {
      if (
        splashPhaseRef.current === 'hidden' ||
        splashPhaseRef.current === 'awaiting-permission' ||
        audioPermissionRef.current === 'denied'
      ) {
        return
      }
      if (e instanceof KeyboardEvent && !UNLOCK_TRIGGER_KEYS.has(e.key)) {
        return
      }
      primeAudioElement(false)
    }

    return addCaptureGestureListeners(primeOnSplashGesture)
  }, [audioPermission, primeAudioElement, splashPhase])

  // Auto-unlock playback on first intentional gesture anywhere outside Hero audio controls if browser blocked autoplay
  useEffect(() => {
    if (
      !isAutoplayBlocked ||
      isPlaying ||
      hasAudioError ||
      userDismissedPromptRef.current ||
      typeof window === 'undefined'
    ) {
      return undefined
    }

    const unlockOnGesture = (e: Event) => {
      const audio = audioRef.current
      if (
        !audio ||
        unlockInFlightRef.current ||
        isPendingPlayRef.current ||
        (!audio.paused && !audio.ended)
      ) {
        return
      }
      const target = e.target
      if (
        target instanceof Element &&
        target.closest('#hero-welcome-audio-chip, #hero-audio-unlock-pill')
      ) {
        return
      }
      if (e instanceof KeyboardEvent && !UNLOCK_TRIGGER_KEYS.has(e.key)) {
        return
      }
      startPlayback(true, true)
    }

    return addCaptureGestureListeners(unlockOnGesture)
  }, [hasAudioError, isAutoplayBlocked, isPlaying, startPlayback])

  const value = useMemo<WelcomeAudioContextValue>(
    () => ({
      splashPhase,
      audioPermission,
      slideDurationMs,
      isPlaying,
      isAutoplayBlocked,
      hasAudioError,
      analyserNode: isWaitingBeforePlay ? null : analyserNode,
      grantAudioPermission,
      declineAudioPermission,
      requestSlideUp,
      completeSlideUp,
      toggleAudio,
      dismissAutoplayPrompt,
    }),
    [
      analyserNode,
      audioPermission,
      completeSlideUp,
      declineAudioPermission,
      dismissAutoplayPrompt,
      grantAudioPermission,
      hasAudioError,
      isAutoplayBlocked,
      isPlaying,
      isWaitingBeforePlay,
      requestSlideUp,
      slideDurationMs,
      splashPhase,
      toggleAudio,
    ],
  )

  return <WelcomeAudioContext.Provider value={value}>{children}</WelcomeAudioContext.Provider>
}
