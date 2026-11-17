import { createContext, useContext } from 'react'

export type SplashPhase = 'hidden' | 'showcase' | 'awaiting-enter' | 'sliding-up'

export interface WelcomeAudioContextValue {
  /** Current lifecycle phase of the entrance splash curtain. */
  splashPhase: SplashPhase
  /** Landing page slide-up transition duration in ms. */
  slideDurationMs: number
  /** True while `/audio/eva-welcome.mp3` is actively playing. */
  isPlaying: boolean
  /** True when automatic post-splash playback was blocked by browser autoplay policy. */
  isAutoplayBlocked: boolean
  /** True when the user explicitly skipped sound via Escape on the splash curtain. */
  audioDeclined: boolean
  /** True if the browser could not load or decode the welcome audio asset. */
  hasAudioError: boolean
  /** Live Web Audio API AnalyserNode wired to `/audio/eva-welcome.mp3` once active. */
  analyserNode: AnalyserNode | null
  /** Finishes showcase reveal: auto-slides up if autoplay is unlocked, or pauses on the splash hint. */
  completeShowcase: () => void
  /** Unlocks audio and AudioContext inside a user gesture and triggers landing sheet slide-up. */
  enterWithAudio: () => void
  /** Exits the splash hint silently via Escape without autoplaying welcome audio. */
  enterSilently: () => void
  /** Starts the bottom-to-top landing page slide-up transition once typography choreography finishes. */
  requestSlideUp: () => void
  /** Finalizes slide-up at resting `top: 0`, reveals normal scroll flow, and starts EVA voice greeting. */
  completeSlideUp: () => void
  /** Plays, pauses, or replays the welcome greeting audio from Hero controls. */
  toggleAudio: () => void
  /** Dismisses the subtle autoplay-blocked Hero prompt without playing audio. */
  dismissAutoplayPrompt: () => void
}

export const WelcomeAudioContext = createContext<WelcomeAudioContextValue | null>(null)

/** Returns shared welcome splash and ambient greeting audio controls. */
export function useWelcomeAudio(): WelcomeAudioContextValue {
  const ctx = useContext(WelcomeAudioContext)
  if (!ctx) {
    throw new Error('useWelcomeAudio must be used within WelcomeAudioProvider')
  }
  return ctx
}
