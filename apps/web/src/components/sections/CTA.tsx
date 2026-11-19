import { Download, ShieldCheck } from 'lucide-react'
import { Button, Container, LunaOrb } from '@/components/ui'
import { waitlist } from '@/content/landing'
import { useLatestRelease } from '@/hooks/useLatestRelease'

export function CTA() {
  const { version, sizeFormatted, downloadUrl } = useLatestRelease()

  const specs = [
    { id: 'os', label: waitlist.specs[0] },
    { id: 'version', label: `Rilis ${version}` },
    { id: 'size', label: sizeFormatted },
    { id: 'price', label: waitlist.specs[3] },
  ]

  return (
    <section
      id="early-access"
      aria-labelledby="early-access-title"
      className="relative isolate flex min-h-[100dvh] w-full flex-col justify-center py-20 sm:py-24 lg:py-28"
    >
      <Container className="my-auto">
        <div
          id="early-access-card"
          data-cursor-theme="dark"
          className="reveal relative isolate overflow-hidden rounded-[32px] border border-white/10 bg-obsidian px-6 py-14 sm:px-12 sm:py-20 lg:px-24 lg:py-24 shadow-2xl"
        >
          {/* Ambient atmosphere behind the orb: Purpose-Gate (R-01/R-13) - focal atmosphere anchor for brand identity LunaOrb on obsidian card */}
          <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
            <div className="absolute -top-1/2 left-1/2 size-[680px] -translate-x-1/2 rounded-full bg-[radial-gradient(circle,rgba(83,88,203,0.35)_0%,transparent_70%)]" />
          </div>

          <div className="mx-auto flex max-w-4xl xl:max-w-5xl flex-col items-center text-center">
            <LunaOrb className="size-20" />
            <span className="mt-8 text-overline font-bold tracking-[0.14em] uppercase text-primary-light">
              {waitlist.kicker}
            </span>
            <h2 id="early-access-title" className="mt-4 text-section text-white max-w-3xl">
              {waitlist.title}
            </h2>
            <p className="mt-4 text-body-lg text-white/70 sm:text-[19px] sm:leading-relaxed max-w-2xl">
              {waitlist.description}
            </p>

            {/* Direct Download Action Card */}
            <div className="mt-10 flex w-full max-w-xl flex-col items-center">
              <Button
                id="early-access-download-btn"
                href={downloadUrl}
                target="_blank"
                rel="noopener noreferrer"
                data-cursor="UNDUH"
                size="lg"
                variant="light"
                className="h-[54px] w-full sm:w-auto px-8 text-base font-bold shadow-btn"
                leftIcon={<Download className="size-5" />}
              >
                {waitlist.button}
              </Button>

              {/* Version & Device Specs */}
              <div id="early-access-specs" className="mt-4 flex flex-wrap items-center justify-center gap-2">
                {specs.map((spec) => (
                  <span
                    key={spec.id}
                    className="rounded-pill border border-white/15 bg-white/10 px-3.5 py-1 text-xs font-semibold text-white/90 backdrop-blur-sm"
                  >
                    {spec.label}
                  </span>
                ))}
              </div>

              {/* Security & Privacy Assurance */}
              <p className="mt-4 inline-flex items-center gap-1.5 text-caption text-white/60">
                <ShieldCheck className="size-3.5 text-success" />
                {waitlist.note}
              </p>
            </div>
          </div>
        </div>
      </Container>
    </section>
  )
}
