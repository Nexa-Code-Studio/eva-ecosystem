import type { CSSProperties, HTMLAttributes } from 'react'
import { useAnalyserBands } from '@/hooks/useAnalyserBands'
import { usePrefersReducedMotion } from '@/hooks/useScroll'
import { cn } from '@/lib/cn'

export type AgentState = 'idle' | 'speaking' | 'listening' | 'connecting' | 'thinking'
export type VisualizerAudioMode = 'live' | 'wave-silence' | 'wave-passive' | 'reduced-motion'

export interface BarVisualizerProps extends HTMLAttributes<HTMLDivElement> {
  /** Web Audio AnalyserNode driving live frequency bar motion. */
  analyserNode?: AnalyserNode | null
  /** Current voice state controlling whether equalizer bars react to live voice. */
  state?: AgentState
  /** Total capsule bars rendered across the container. Default: 24. */
  barCount?: number
  /** Minimum bar height percentage during active live voice playback. Default: 22. */
  minHeight?: number
  /** Maximum bar height percentage on peak vocal energy. Default: 100. */
  maxHeight?: number
  /** Vertically centers capsule bars cleanly around the midline. Default: true. */
  centerAlign?: boolean
  /** Emphasizes bar thickness and gap slightly during active speaking state. Default: false. */
  prominent?: boolean
}

function getClassicSilhouetteHeight(index: number): number {
  return 30 + Math.abs(Math.sin(index * 1.7)) * 70
}

/**
 * Audio-reactive symmetric bar equalizer adapted from ElevenLabs UI (`BarVisualizer`)
 * with exact Waveform width/gap geometry and gentle classic CSS wave fallback when silent or passive.
 */
export function BarVisualizer({
  analyserNode = null,
  state = 'idle',
  barCount = 24,
  minHeight = 22,
  maxHeight = 100,
  centerAlign = true,
  prominent = false,
  className,
  ...props
}: BarVisualizerProps) {
  const reducedMotion = usePrefersReducedMotion()
  const isSpeakingState = state === 'speaking' || state === 'listening'
  const isActive = isSpeakingState && !reducedMotion

  const { bands, hasLiveAudio } = useAnalyserBands(analyserNode, {
    active: isSpeakingState,
    bars: barCount,
    symmetric: centerAlign,
    reducedMotion,
  })

  const audioMode: VisualizerAudioMode = reducedMotion
    ? 'reduced-motion'
    : isActive
      ? hasLiveAudio
        ? 'live'
        : 'wave-silence'
      : 'wave-passive'

  const useWidePitch = prominent && isActive

  return (
    <div
      role="presentation"
      aria-hidden="true"
      data-slot="bar-visualizer"
      data-state={state}
      data-audio-mode={audioMode}
      className={cn(
        'flex w-full justify-center',
        centerAlign ? 'items-center' : 'items-end',
        useWidePitch ? 'gap-[3.5px]' : 'gap-[3px]',
        className,
      )}
      {...props}
    >
      {bands.map((level, index) => {
        const isLiveFft = audioMode === 'live'
        const useWaveKeyframes = audioMode === 'wave-silence' || audioMode === 'wave-passive'

        const heightPercent = isLiveFft
          ? Math.min(maxHeight, Math.max(minHeight, minHeight + level * (maxHeight - minHeight)))
          : getClassicSilhouetteHeight(index)

        const style: CSSProperties = {
          height: `${heightPercent.toFixed(1)}%`,
          animationDelay: useWaveKeyframes ? `${(index % 7) * 110}ms` : undefined,
        }

        return (
          <span
            key={index}
            data-bar-index={index}
            className={cn(
              'origin-center shrink-0 rounded-full bg-linear-to-t from-primary to-primary-light transition-[height,opacity,width] duration-100 ease-out',
              useWidePitch ? 'w-[3.5px]' : 'w-[3px]',
              audioMode === 'live' && 'opacity-100',
              audioMode === 'wave-silence' && 'animate-wave opacity-100',
              audioMode === 'wave-passive' && 'animate-wave opacity-55 [animation-duration:1.8s]',
              audioMode === 'reduced-motion' &&
                (isSpeakingState ? 'scale-y-[0.65] opacity-100' : 'scale-y-[0.38] opacity-55'),
            )}
            style={style}
          />
        )
      })}
    </div>
  )
}
