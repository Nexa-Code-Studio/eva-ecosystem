import { useEffect, useMemo, useState } from 'react'

const MIN_VOICE_DB = -90
const VOICE_DB_RANGE = 50
const HIGH_FORMANT_TILT_DB = 10
const SILENT_FLOOR_DB = -120
const VOICE_ACTIVITY_THRESHOLD = 0.08
const SILENCE_HYSTERESIS_MS = 260

export interface AnalyserBandOptions {
  /** Whether frequency extraction is active (e.g. voice playback running). */
  active: boolean
  /** Number of output bar levels to return. */
  bars?: number
  /** Lowest FFT bin sampled (~129 Hz at 44.1 kHz / fftSize 1024). */
  loPass?: number
  /** Exclusive upper FFT bin bound (~3.7 kHz at 44.1 kHz / fftSize 1024). */
  hiPass?: number
  /** Mirror vocal bands from center outward for a balanced center-aligned voice wave. */
  symmetric?: boolean
  /** Disables dynamic animation when the user prefers reduced motion. */
  reducedMotion?: boolean
  /** Minimum React state commit interval in milliseconds (~30 fps). */
  updateIntervalMs?: number
}

export interface AnalyserBandsResult {
  /** Normalized 0..1 per-bar frequency magnitudes. */
  bands: number[]
  /** True while real vocal energy is present (or decaying within silence hysteresis). */
  hasLiveAudio: boolean
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value))
}

function createZeroBands(count: number): number[] {
  return new Array<number>(count).fill(0)
}

function sampleBandEnergy(
  fftData: Float32Array,
  startBin: number,
  endBin: number,
  bandRatio: number,
): number {
  let sum = 0
  let maxDb = -Infinity
  let count = 0

  for (let bin = startBin; bin < endBin; bin++) {
    const value = fftData[bin]
    if (!Number.isFinite(value) || value <= SILENT_FLOOR_DB) continue
    sum += value
    if (value > maxDb) maxDb = value
    count += 1
  }

  if (count === 0) return 0
  const meanDb = sum / count
  // Weight formant peaks more strongly and gently compensate natural vocal HF roll-off (~2–3.7 kHz)
  const tiltDb = bandRatio * HIGH_FORMANT_TILT_DB
  const effectiveDb = maxDb * 0.72 + meanDb * 0.28 + tiltDb
  const linear = clamp01((effectiveDb - MIN_VOICE_DB) / VOICE_DB_RANGE)
  return Math.pow(linear, 0.88)
}

/**
 * Extracts normalized vocal-band amplitudes from a Web Audio `AnalyserNode` at ~30 fps,
 * tracking live voice activity so visualizers can fall back cleanly to passive wave animations
 * during extended silence or paused states.
 */
export function useAnalyserBands(
  analyser: AnalyserNode | null,
  {
    active,
    bars = 24,
    loPass = 3,
    hiPass = 87,
    symmetric = true,
    reducedMotion = false,
    updateIntervalMs = 32,
  }: AnalyserBandOptions,
): AnalyserBandsResult {
  const zeroBands = useMemo(() => createZeroBands(bars), [bars])
  const [liveState, setLiveState] = useState<AnalyserBandsResult>(() => ({
    bands: zeroBands,
    hasLiveAudio: false,
  }))

  const shouldSample = active && !reducedMotion && analyser !== null

  useEffect(() => {
    if (!shouldSample || !analyser) return undefined

    let rafId = 0
    let lastCommit = 0
    let lastCommittedLive = false
    let lastVoiceTimestamp = -1

    const smoothed = createZeroBands(bars)
    const bandCount = symmetric ? Math.ceil(bars / 2) : bars
    const bandEnergies = new Array<number>(bandCount).fill(0)
    const fftData = new Float32Array(analyser.frequencyBinCount)

    const step = (timestamp: number) => {
      analyser.getFloatFrequencyData(fftData)

      const upper = Math.min(fftData.length, Math.max(loPass + bandCount, hiPass))
      const lower = Math.max(0, Math.min(loPass, upper - bandCount))
      const span = Math.max(1, upper - lower)
      const binsPerBand = span / bandCount

      let peakEnergy = 0
      for (let b = 0; b < bandCount; b++) {
        const startBin = Math.floor(lower + b * binsPerBand)
        const endBin = Math.max(startBin + 1, Math.floor(lower + (b + 1) * binsPerBand))
        const bandRatio = bandCount > 1 ? b / (bandCount - 1) : 0
        const energy = sampleBandEnergy(fftData, startBin, endBin, bandRatio)
        bandEnergies[b] = energy
        if (energy > peakEnergy) peakEnergy = energy
      }

      if (peakEnergy >= VOICE_ACTIVITY_THRESHOLD) {
        lastVoiceTimestamp = timestamp
      }

      const hasLiveAudio =
        lastVoiceTimestamp >= 0 && timestamp - lastVoiceTimestamp < SILENCE_HYSTERESIS_MS

      const center = (bars - 1) / 2
      for (let i = 0; i < bars; i++) {
        const bandIndex = symmetric
          ? Math.min(
              bandCount - 1,
              Math.round((center > 0 ? Math.abs(i - center) / center : 0) * (bandCount - 1)),
            )
          : Math.min(bandCount - 1, i)
        const target = bandEnergies[bandIndex] ?? 0
        const alpha = target > smoothed[i] ? 0.58 : 0.32
        smoothed[i] += (target - smoothed[i]) * alpha
      }

      if (hasLiveAudio !== lastCommittedLive || timestamp - lastCommit >= updateIntervalMs) {
        lastCommit = timestamp
        lastCommittedLive = hasLiveAudio
        setLiveState({
          bands: [...smoothed],
          hasLiveAudio,
        })
      }

      rafId = window.requestAnimationFrame(step)
    }

    rafId = window.requestAnimationFrame(step)
    return () => {
      window.cancelAnimationFrame(rafId)
    }
  }, [analyser, bars, hiPass, loPass, shouldSample, symmetric, updateIntervalMs])

  if (!shouldSample) {
    return { bands: zeroBands, hasLiveAudio: false }
  }

  return liveState.bands.length === bars
    ? liveState
    : { bands: zeroBands, hasLiveAudio: false }
}
