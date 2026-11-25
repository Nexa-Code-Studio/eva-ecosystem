import {
  ArrowRight,
  ChevronDown,
  Download,
  Lock,
  Pause,
  ShieldCheck,
  Volume2,
  X,
} from 'lucide-react'
import type { CSSProperties } from 'react'
import { HomeScreen } from '@/components/mockups/AppScreens'
import { PhoneFrame } from '@/components/mockups/PhoneFrame'
import { BarVisualizer, Button, Container } from '@/components/ui'
import { hero } from '@/content/landing'
import { useLatestRelease } from '@/hooks/useLatestRelease'
import { useWelcomeAudio } from '@/hooks/useWelcomeAudio'
import { cn } from '@/lib/cn'

const stagger = (i: number) => ({ '--i': i }) as CSSProperties

export function Hero() {
  const {
    splashPhase,
    isPlaying,
    isAutoplayBlocked,
    audioDeclined,
    hasAudioError,
    analyserNode,
    toggleAudio,
    dismissAutoplayPrompt,
  } = useWelcomeAudio()
  const { version, sizeFormatted, downloadUrl } = useLatestRelease()
  return (
    <section
      id="top"
      aria-labelledby="hero-title"
      className="relative isolate flex min-h-[100dvh] w-full flex-col justify-center overflow-hidden bg-canvas pt-20 pb-8 sm:pt-24 sm:pb-12 lg:pt-20 lg:pb-14 border-b border-border-subtle/50"
    >
      <HeroBackdrop />

      {/* Unified container synchronized with Navbar and all content sections */}
      <Container className="flex flex-1 items-center">
        <div className="grid w-full items-center gap-10 lg:grid-cols-[1.15fr_0.85fr] lg:gap-10 xl:gap-14">
          {/* Copy column */}
          <div className="flex w-full flex-col justify-center py-4 sm:py-6 items-center text-center lg:py-0 lg:items-start lg:text-left">
            {/* Kicker */}
            <span
              className="animate-enter text-overline font-bold tracking-[0.14em] uppercase text-primary"
              style={stagger(0)}
            >
              {hero.kicker}
            </span>

            {/* Title */}
            <h1
              id="hero-title"
              className="mt-4 max-w-3xl xl:max-w-4xl 2xl:max-w-5xl animate-enter text-hero sm:mt-5"
              style={stagger(1)}
            >
              {hero.titleLead} <span className="text-primary">{hero.titleAccent}</span>
            </h1>

            {/* Subtitle */}
            <p
              className="mt-3 max-w-xl 2xl:max-w-2xl animate-enter text-body-lg text-ink-soft sm:mt-4 sm:text-[18px] sm:leading-[1.6]"
              style={stagger(2)}
            >
              {hero.subtitle}
            </p>

            {/* CTA Buttons & Unified Metadata Line */}
            <div className="mt-5 flex w-full flex-col items-center sm:mt-6 lg:items-start">
              <div
                className="flex w-full animate-enter flex-col gap-3 sm:w-auto sm:flex-row"
                style={stagger(3)}
              >
                <Button
                  id="hero-cta-primary"
                  href="#early-access"
                  data-cursor="MULAI"
                  variant="primary"
                  size="lg"
                  rightIcon={<ArrowRight />}
                >
                  {hero.primaryCta}
                </Button>
                <Button
                  id="hero-cta-apk"
                  href={downloadUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  data-cursor="UNDUH"
                  variant="secondary"
                  size="lg"
                  className="hidden lg:inline-flex"
                  leftIcon={<Download />}
                >
                  {hero.secondaryCta}
                </Button>
                <a
                  id="hero-mobile-apk-link"
                  href={downloadUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex min-h-10 items-center justify-center gap-1.5 text-body-md font-semibold text-primary transition-colors hover:text-primary-deep focus-visible:outline-2 focus-visible:outline-primary lg:hidden"
                >
                  <Download className="size-4" aria-hidden />
                  <span>Unduh APK Android ({sizeFormatted})</span>
                </a>
              </div>

              <div
                id="hero-apk-specs"
                className="mt-3.5 hidden animate-enter flex-wrap items-center gap-x-2.5 gap-y-1 text-caption font-medium text-ink-soft lg:flex"
                style={stagger(4)}
              >
                <span className="inline-flex items-center gap-1.5 text-ink">
                  <Lock className="size-3.5 text-primary" aria-hidden />
                  100% Privat di Ponsel
                </span>
                <span aria-hidden className="text-ink-muted">
                  ·
                </span>
                <span>Android 8.0+</span>
                <span aria-hidden className="text-ink-muted">
                  ·
                </span>
                <span>Rilis {version} ({sizeFormatted})</span>
              </div>

              {splashPhase === 'hidden' &&
                !audioDeclined &&
                isAutoplayBlocked &&
                !isPlaying &&
                !hasAudioError && (
                <div
                  id="hero-audio-unlock-pill"
                  className="mt-4 inline-flex items-center gap-1 rounded-pill border border-primary/25 bg-primary-container/90 p-1 pl-3.5 text-primary-deep shadow-subtle backdrop-blur-sm animate-enter"
                >
                  <button
                    type="button"
                    onClick={toggleAudio}
                    data-cursor="PUTAR"
                    className="inline-flex min-h-9 cursor-pointer items-center gap-2 pr-2 text-xs font-bold text-primary-deep transition-colors hover:text-primary"
                  >
                    <Volume2 className="size-4 shrink-0 text-primary" aria-hidden="true" />
                    <span>Sapaan suara EVA siap, ketuk untuk dengar</span>
                  </button>
                  <button
                    type="button"
                    onClick={dismissAutoplayPrompt}
                    data-cursor="TUTUP"
                    aria-label="Tutup pengingat sapaan suara"
                    className="flex size-8 cursor-pointer items-center justify-center rounded-full text-primary-deep/70 transition-colors hover:bg-primary/10 hover:text-primary-deep"
                  >
                    <X className="size-3.5" />
                  </button>
                </div>
              )}
            </div>

            {/* Concise inline metrics on desktop (unboxed to avoid Hero card bloat) & Scroll Cue on mobile */}
            <div className="mt-6 flex w-full flex-col items-center lg:mt-7 lg:items-start">
              <dl
                className="hidden w-full max-w-lg animate-enter grid-cols-3 gap-6 border-t border-border-subtle/80 pt-5 lg:grid"
                style={stagger(5)}
              >
                {hero.stats.map((s) => (
                  <div key={s.label}>
                    <dt className="sr-only">{s.label}</dt>
                    <dd className="text-title-md font-bold text-ink">{s.value}</dd>
                    <dd className="mt-0.5 text-caption leading-snug text-ink-soft">{s.label}</dd>
                  </div>
                ))}
              </dl>

              {/* Minimal scroll down cue on mobile */}
              <a
                href="#fitur"
                aria-label="Gulir ke bagian fitur"
                className="mt-3.5 flex size-8 items-center justify-center text-ink-muted/70 transition-colors hover:text-primary lg:hidden"
              >
                <ChevronDown className="size-5 animate-bounce text-primary/80" />
              </a>
            </div>
          </div>

          {/* Visual column: proportional PhoneFrame sized to fit inside 100dvh on laptops & desktops */}
          <div
            id="hero-mockup-preview"
            className="relative mx-auto hidden w-full max-w-[460px] animate-enter lg:block lg:max-w-none"
            style={stagger(3)}
          >
            <div className="relative flex justify-center">
              <PhoneFrame
                screenshot="/images/mockups/home.webp"
                screenshotAlt="Tangkapan layar asli beranda aplikasi Eva Mobile"
                priority
                className="w-[268px] xl:w-[296px] 2xl:w-[324px]"
              >
                <HomeScreen speaking={isPlaying} />
              </PhoneFrame>
            </div>

            {/* Contextual Chip 1: Interactive Welcome Greeting Replay & Speaking Card (Top-Left) */}
            <button
              id="hero-welcome-audio-chip"
              type="button"
              onClick={toggleAudio}
              aria-pressed={isPlaying}
              aria-label={isPlaying ? 'Jeda sapaan suara EVA' : 'Putar sapaan suara EVA'}
              data-cursor={isPlaying ? 'JEDA' : 'PUTAR'}
              className={cn(
                'group absolute top-10 -left-4 hidden cursor-pointer rounded-[18px] border bg-white/95 text-left backdrop-blur-md transition-[width,padding,transform,box-shadow,border-color] duration-500 ease-luna hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-fab sm:block lg:-left-10 xl:-left-14',
                isPlaying
                  ? 'w-[296px] border-primary/45 p-4 shadow-fab motion-reduce:w-[228px]'
                  : 'w-[228px] border-border-subtle/80 p-3.5 shadow-nav',
              )}
            >
              <div className="flex items-center gap-2.5">
                <span
                  className={cn(
                    'flex shrink-0 items-center justify-center rounded-[10px] text-white shadow-btn transition-[width,height,background-color] duration-300',
                    isPlaying
                      ? 'size-9 bg-primary-deep motion-reduce:size-8'
                      : 'size-8 bg-primary group-hover:brightness-110',
                  )}
                >
                  {isPlaying ? <Pause className="size-4" /> : <Volume2 className="size-4" />}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-caption !tracking-normal font-bold text-ink">
                      Curhat suara aktif
                    </p>
                    {isPlaying && (
                      <span className="inline-flex shrink-0 items-center gap-1 rounded-pill bg-primary-container px-2 py-0.5 text-[10px] font-bold text-primary-deep">
                        <span className="size-1.5 rounded-full bg-primary" aria-hidden />
                        Berbicara
                      </span>
                    )}
                  </div>
                  <p className="truncate text-[11px] font-medium text-ink-soft">
                    {hasAudioError
                      ? 'Audio belum tersedia'
                      : isPlaying
                        ? 'Memutar sapaan EVA…'
                        : isAutoplayBlocked
                          ? 'Ketuk untuk putar sapaan'
                          : 'Putar sapaan EVA'}
                  </p>
                </div>
              </div>
              <BarVisualizer
                analyserNode={analyserNode}
                state={isPlaying ? 'speaking' : 'idle'}
                barCount={24}
                centerAlign
                prominent={isPlaying}
                minHeight={24}
                className={cn(
                  'w-full transition-[height,margin] duration-500 ease-luna',
                  isPlaying ? 'mt-3 h-14 motion-reduce:h-7' : 'mt-2.5 h-7',
                )}
              />
            </button>

            {/* Contextual Chip 2: On-Device Encryption (Bottom-Right) */}
            <div className="absolute bottom-6 -right-2 hidden items-center gap-2 rounded-pill border border-border-subtle/80 bg-white/95 py-2 pr-4 pl-2 shadow-nav backdrop-blur-md sm:flex lg:-right-6 xl:-right-8">
              <span className="flex size-7 items-center justify-center rounded-full bg-success/15 text-success">
                <ShieldCheck className="size-4" />
              </span>
              <p className="text-caption !tracking-normal font-bold text-ink">100% Enkripsi di Perangkat</p>
            </div>
          </div>
        </div>
      </Container>

      {/* Floating scroll down invitation */}
      <div className="absolute inset-x-0 bottom-4 hidden justify-center md:flex">
        <a
          href="#fitur"
          data-cursor="JELAJAHI"
          aria-label="Gulir ke bagian fitur"
          className="group flex flex-col items-center gap-1 text-caption font-semibold text-ink-soft transition-colors hover:text-primary"
        >
          <span className="text-[10px] font-bold tracking-widest text-ink-muted uppercase transition-colors group-hover:text-primary">
            Jelajahi Fitur
          </span>
          <span className="flex h-6 w-3.5 items-start justify-center rounded-pill border-[1.5px] border-ink-muted/40 p-[2px] transition-colors group-hover:border-primary">
            <span className="h-1.5 w-1 rounded-full bg-primary transition-transform group-hover:translate-y-1" />
          </span>
          <ChevronDown className="size-3.5 -mt-0.5 animate-bounce text-primary" />
        </a>
      </div>
    </section>
  )
}

function HeroBackdrop() {
  return null
}
