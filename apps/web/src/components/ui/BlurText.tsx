import { type Easing, motion, type TargetAndTransition, type Transition } from 'motion/react'
import { Fragment, useMemo, useRef } from 'react'
import { usePrefersReducedMotion } from '@/hooks/useScroll'
import { cn } from '@/lib/cn'

export interface BlurTextSegment {
  text: string
  className?: string
  /** Additional conversational pause in seconds inserted after this segment before subsequent segments start. */
  extraDelayAfter?: number
}

export interface BlurTextProps {
  /** Single plain text string (ignored when `segments` is provided). */
  text?: string
  /** Styled segments concatenated continuously for unified stagger timing. */
  segments?: readonly BlurTextSegment[]
  /** Granularity of animation: whole words (`'words'`) or individual letters (`'letters'`). */
  animateBy?: 'words' | 'letters'
  /** Delay between consecutive units in milliseconds. */
  delay?: number
  /** Initial delay before the first unit begins animating, in seconds. */
  initialDelay?: number
  /** Duration of each animation step, in seconds. */
  stepDuration?: number
  /** Vertical drift direction into focus. */
  direction?: 'top' | 'bottom'
  /** Easing curve passed to Motion. */
  easing?: Easing
  className?: string
  onAnimationComplete?: () => void
}

interface TextUnit {
  text: string
  seqIndex: number
  pauseBeforeSec: number
}

type WordOrSpaceToken =
  | { kind: 'space'; key: string }
  | { kind: 'word'; key: string; className?: string; units: TextUnit[] }

function buildTokens(segments: readonly BlurTextSegment[], animateBy: 'words' | 'letters') {
  const tokens: WordOrSpaceToken[] = []
  let seqIndex = 0
  let pauseOffsetSec = 0

  segments.forEach((segment, segIdx) => {
    const parts = segment.text.split(/(\s+)/)
    parts.forEach((part, partIdx) => {
      if (!part) return
      if (/^\s+$/.test(part)) {
        tokens.push({ kind: 'space', key: `s-${segIdx}-${partIdx}` })
        return
      }
      const units: TextUnit[] =
        animateBy === 'words'
          ? [{ text: part, seqIndex: seqIndex++, pauseBeforeSec: pauseOffsetSec }]
          : Array.from(part).map((char) => ({
              text: char,
              seqIndex: seqIndex++,
              pauseBeforeSec: pauseOffsetSec,
            }))

      tokens.push({
        kind: 'word',
        key: `w-${segIdx}-${partIdx}`,
        className: segment.className,
        units,
      })
    })

    if (segment.extraDelayAfter) {
      pauseOffsetSec += segment.extraDelayAfter
    }
  })

  return { tokens, totalUnits: seqIndex }
}

/**
 * React Bits BlurText implementation built on `motion/react` for smooth,
 * word-boundary-safe word-by-word or letter-by-letter blur entrance animations.
 */
export function BlurText({
  text = '',
  segments,
  animateBy = 'words',
  delay = 420,
  initialDelay = 0.16,
  stepDuration = 0.475,
  direction = 'bottom',
  easing = [0.22, 1, 0.36, 1],
  className,
  onAnimationComplete,
}: BlurTextProps) {
  const reducedMotion = usePrefersReducedMotion()
  const completedRef = useRef(false)

  const resolvedSegments = useMemo<readonly BlurTextSegment[]>(
    () => (segments && segments.length > 0 ? segments : [{ text }]),
    [segments, text],
  )

  const { tokens, totalUnits } = useMemo(
    () => buildTokens(resolvedSegments, animateBy),
    [animateBy, resolvedSegments],
  )

  const initialPose = useMemo<TargetAndTransition>(
    () =>
      reducedMotion
        ? { opacity: 0 }
        : {
            filter: 'blur(12px)',
            opacity: 0,
            y: direction === 'top' ? -16 : 16,
          },
    [direction, reducedMotion],
  )

  const animateKeyframes = useMemo<TargetAndTransition>(
    () =>
      reducedMotion
        ? { opacity: 1 }
        : {
            filter: ['blur(12px)', 'blur(4px)', 'blur(0px)'],
            opacity: [0, 0.65, 1],
            y: [direction === 'top' ? -16 : 16, direction === 'top' ? 2 : -2, 0],
          },
    [direction, reducedMotion],
  )

  const stepCount = reducedMotion ? 1 : 2
  const totalDuration = (reducedMotion ? 0.15 : stepDuration) * stepCount
  const times = useMemo(
    () => (reducedMotion ? [0, 1] : [0, 0.5, 1]),
    [reducedMotion],
  )

  const notifyComplete = () => {
    if (completedRef.current) return
    completedRef.current = true
    onAnimationComplete?.()
  }

  return (
    <span aria-hidden="true" className={cn('inline', className)}>
      {tokens.map((token) => {
        if (token.kind === 'space') {
          return <Fragment key={token.key}> </Fragment>
        }

        return (
          <span key={token.key} className={cn('inline-block whitespace-nowrap', token.className)}>
            {token.units.map(({ text: unitText, seqIndex, pauseBeforeSec }) => {
              const isLast = seqIndex === totalUnits - 1
              const transition: Transition = reducedMotion
                ? { duration: 0.15 }
                : {
                    duration: totalDuration,
                    times,
                    delay: initialDelay + (seqIndex * delay) / 1000 + pauseBeforeSec,
                    ease: easing,
                  }

              return (
                <motion.span
                  key={seqIndex}
                  initial={initialPose}
                  animate={animateKeyframes}
                  transition={transition}
                  onAnimationComplete={isLast ? notifyComplete : undefined}
                  className="inline-block will-change-[transform,filter,opacity]"
                >
                  {unitText}
                </motion.span>
              )
            })}
          </span>
        )
      })}
    </span>
  )
}
