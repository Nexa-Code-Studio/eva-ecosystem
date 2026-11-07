import {
  ArrowRight,
  ChevronDown,
  Download,
  Lock,
  Mic,
  ShieldCheck,
} from 'lucide-react'
import type { CSSProperties } from 'react'
import { HomeScreen, Waveform } from '@/components/mockups/AppScreens'
import { PhoneFrame } from '@/components/mockups/PhoneFrame'
import { Button, Container } from '@/components/ui'
import { DOWNLOAD_APK_URL, hero } from '@/content/landing'

const stagger = (i: number) => ({ '--i': i }) as CSSProperties

export function Hero() {
  return (
    <section
      id="top"
      aria-labelledby="hero-title"
      className="relative isolate flex min-h-[100dvh] w-full flex-col justify-center overflow-hidden bg-canvas pt-24 pb-16 sm:pt-28 sm:pb-16 lg:pt-28 lg:pb-16 border-b border-border-subtle/50"
    >
      <HeroBackdrop />

      {/* Unified container synchronized with Navbar and all content sections */}
      <Container className="flex flex-1 items-center">
        <div className="grid w-full items-center gap-12 lg:grid-cols-[1.12fr_0.88fr] lg:gap-12 xl:gap-16">
          {/* Copy column: Spans 100dvh on mobile with balanced proportional spacing */}
          <div className="flex min-h-[calc(100dvh-5.5rem)] w-full flex-col justify-center py-6 sm:py-8 items-center text-center lg:min-h-0 lg:py-0 lg:items-start lg:text-left">
            {/* Kicker */}
            <span
              className="animate-enter text-overline font-bold tracking-[0.14em] uppercase text-primary"
              style={stagger(0)}
            >
              {hero.kicker}
            </span>

            {/* Title: Tambah mt agar lebih lega dari kicker */}
            <h1
              id="hero-title"
              className="mt-6 max-w-3xl xl:max-w-4xl 2xl:max-w-5xl animate-enter text-hero sm:mt-8"
              style={stagger(1)}
            >
              {hero.titleLead} <span className="text-primary">{hero.titleAccent}</span>
            </h1>

            {/* Subtitle */}
            <p
              className="mt-3.5 max-w-2xl 2xl:max-w-3xl animate-enter text-body-lg text-ink-soft sm:mt-4 sm:text-[19px] sm:leading-[1.65]"
              style={stagger(2)}
            >
              {hero.subtitle}
            </p>

            {/* CTA Buttons & Microcopy: Kurangi mt menjadi proporsional */}
            <div className="mt-5 flex w-full flex-col items-center sm:mt-7 lg:items-start">
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
                  href={DOWNLOAD_APK_URL}
                  download="EVA-Beta.apk"
                  target="_blank"
                  rel="noopener noreferrer"
                  data-cursor="UNDUH"
                  variant="secondary"
                  size="lg"
                  leftIcon={<Download />}
                >
                  {hero.secondaryCta}
                </Button>
              </div>

              <ul
                className="mt-3.5 flex animate-enter flex-wrap justify-center gap-x-4 gap-y-2 text-caption text-ink-muted sm:mt-4 lg:justify-start"
                style={stagger(4)}
              >
                {hero.microcopy.map((m, i) => (
                  <li key={m} className="flex items-center gap-1.5">
                    {i === 0 ? (
                      <Lock className="size-3.5 text-primary" />
                    ) : (
                      <span className="size-1 rounded-full bg-primary-light" />
                    )}
                    {m}
                  </li>
                ))}
              </ul>
            </div>

            {/* Social Proof (Card 3 Kolom) & Scroll Cue: Kurangi mt menjadi proporsional */}
            <div className="mt-6 flex w-full flex-col items-center sm:mt-8 lg:items-start">
              <dl
                className="grid w-full max-w-xl animate-enter grid-cols-3 divide-x divide-border-subtle rounded-card border border-border-subtle/80 bg-white py-4 shadow-subtle"
                style={stagger(5)}
              >
                {hero.stats.map((s) => (
                  <div key={s.label} className="px-5 text-center">
                    <dt className="sr-only">{s.label}</dt>
                    <dd className="text-headline text-ink font-bold">{s.value}</dd>
                    <dd className="mt-0.5 text-[11px] leading-tight text-ink-soft">{s.label}</dd>
                  </div>
                ))}
              </dl>

              {/* Minimal scroll down cue below 3-column card on mobile */}
              <a
                href="#fitur"
                aria-label="Gulir ke bagian fitur"
                className="mt-3.5 flex size-8 items-center justify-center text-ink-muted/70 transition-colors hover:text-primary lg:hidden"
              >
                <ChevronDown className="size-5 animate-bounce text-primary/80" />
              </a>
            </div>
          </div>

          {/* Visual column: clean phone showcase visible only on desktop (lg:block), keeping mobile focus on Features mockup */}
          <div
            id="hero-mockup-preview"
            className="relative mx-auto hidden w-full max-w-[560px] animate-enter pt-12 pb-8 sm:pt-16 sm:pb-12 lg:block lg:max-w-none lg:pt-0 lg:pb-0"
            style={stagger(3)}
          >
            <div className="relative flex justify-center">
              <PhoneFrame className="w-[300px] sm:w-[330px] lg:w-[350px] xl:w-[380px]">
                <HomeScreen />
              </PhoneFrame>
            </div>

            {/* Contextual Chip 1: Voice Companion Active (Top-Left) */}
            <div className="absolute top-12 -left-4 hidden w-[220px] rounded-[18px] border border-border-subtle/80 bg-white/95 p-3.5 shadow-nav backdrop-blur-md sm:block lg:-left-8 xl:-left-12">
              <div className="flex items-center gap-2">
                <span className="flex size-8 items-center justify-center rounded-[10px] bg-primary text-white shadow-btn">
                  <Mic className="size-4" />
                </span>
                <div>
                  <p className="text-caption !tracking-normal font-bold text-ink">Curhat suara aktif</p>
                  <p className="text-[10px] text-ink-muted">Mendeteksi intonasi emosi…</p>
                </div>
              </div>
              <Waveform bars={24} className="mt-2.5 h-7" />
            </div>

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
