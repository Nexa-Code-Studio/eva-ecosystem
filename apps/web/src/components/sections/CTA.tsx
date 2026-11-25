import { Download, ShieldCheck, Smartphone, Stethoscope } from 'lucide-react'
import { Button, Container, LunaOrb } from '@/components/ui'
import { counselorCta, waitlist } from '@/content/landing'
import { useAppRelease } from '@/hooks/useLatestRelease'

export function CTA() {
  const mobileRelease = useAppRelease('mobile')
  const counselorRelease = useAppRelease('counselor')

  const apps = [
    {
      id: 'mobile',
      icon: Smartphone,
      badge: waitlist.badge,
      name: waitlist.appName,
      subtitle: waitlist.subtitle,
      buttonId: 'early-access-download-btn',
      specsId: 'early-access-specs',
      buttonLabel: waitlist.button,
      downloadUrl: mobileRelease.downloadUrl,
      specs: [
        { id: 'os', label: waitlist.specs[0] },
        { id: 'version', label: `Rilis ${mobileRelease.version}` },
        { id: 'size', label: mobileRelease.sizeFormatted },
        { id: 'price', label: waitlist.specs[3] },
      ],
      note: waitlist.note,
    },
    {
      id: 'counselor',
      icon: Stethoscope,
      badge: counselorCta.badge,
      name: counselorCta.appName,
      subtitle: counselorCta.subtitle,
      buttonId: 'early-access-counselor-download-btn',
      specsId: 'early-access-counselor-specs',
      buttonLabel: counselorCta.button,
      downloadUrl: counselorRelease.downloadUrl,
      specs: [
        { id: 'os', label: counselorCta.specs[0] },
        { id: 'version', label: `Rilis ${counselorRelease.version}` },
        { id: 'size', label: counselorRelease.sizeFormatted },
        { id: 'verify', label: counselorCta.specs[3] },
      ],
      note: counselorCta.note,
    },
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
          className="reveal relative isolate overflow-hidden rounded-[32px] border border-white/10 bg-obsidian px-6 py-14 sm:px-10 sm:py-16 lg:px-14 lg:py-20 shadow-2xl"
        >
          {/* Ambient atmosphere behind the orb: focal anchor for LunaOrb on obsidian card */}
          <div aria-hidden className="pointer-events-none absolute inset-0 -z-10">
            <div className="absolute -top-1/2 left-1/2 size-[680px] -translate-x-1/2 rounded-full bg-[radial-gradient(circle,rgba(83,88,203,0.35)_0%,transparent_70%)]" />
          </div>

          <div className="mx-auto flex max-w-5xl flex-col items-center text-center">
            <LunaOrb className="size-16 sm:size-20" />
            <span className="mt-6 text-overline font-bold tracking-[0.14em] uppercase text-primary-light">
              {waitlist.kicker}
            </span>
            <h2 id="early-access-title" className="mt-3 text-section text-white max-w-3xl">
              {waitlist.title}
            </h2>
            <p className="mt-3 text-body-lg text-white/75 sm:text-[18px] sm:leading-relaxed max-w-2xl">
              {waitlist.description}
            </p>

            {/* Dual-App Download Cards: Eva Mobile & Eva Counselor */}
            <div className="mt-10 grid w-full grid-cols-1 gap-6 text-left lg:grid-cols-2">
              {apps.map((app) => {
                const AppIcon = app.icon
                return (
                  <div
                    key={app.id}
                    id={`early-access-app-${app.id}`}
                    className="flex flex-col justify-between rounded-[24px] border border-white/15 bg-white/[0.06] p-6 backdrop-blur-md sm:p-7"
                  >
                    <div>
                      <div className="flex items-center justify-between gap-3">
                        <span className="inline-flex items-center gap-2 rounded-pill border border-white/15 bg-white/10 px-3 py-1 text-caption font-bold text-primary-light">
                          <AppIcon className="size-3.5" aria-hidden />
                          {app.badge}
                        </span>
                      </div>

                      <h3 className="mt-4 text-headline text-white">{app.name}</h3>
                      <p className="mt-2 text-body-md text-white/75 leading-relaxed">
                        {app.subtitle}
                      </p>
                    </div>

                    <div className="mt-6 pt-2">
                      <Button
                        id={app.buttonId}
                        href={app.downloadUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        data-cursor="UNDUH"
                        size="lg"
                        variant="light"
                        className="h-[52px] w-full text-base font-bold shadow-btn"
                        leftIcon={<Download className="size-5" />}
                      >
                        {app.buttonLabel}
                      </Button>

                      <div id={app.specsId} className="mt-4 flex flex-wrap items-center gap-2">
                        {app.specs.map((spec) => (
                          <span
                            key={spec.id}
                            className="rounded-pill border border-white/15 bg-white/10 px-3 py-1 text-xs font-semibold text-white/90 backdrop-blur-sm"
                          >
                            {spec.label}
                          </span>
                        ))}
                      </div>

                      <p className="mt-3.5 inline-flex items-center gap-1.5 text-caption text-white/65">
                        <ShieldCheck className="size-3.5 shrink-0 text-success" aria-hidden />
                        <span>{app.note}</span>
                      </p>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        </div>
      </Container>
    </section>
  )
}
