import { ShieldCheck, Stethoscope, X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { CounselorScreen } from '@/components/mockups/CounselorScreens'
import { PhoneFrame } from '@/components/mockups/PhoneFrame'
import { Badge, Button, Container, IconTile, SectionHeading } from '@/components/ui'
import {
  clinicalEvaluationData,
  COUNSELOR_SCREENSHOTS,
  counselorFeatures,
  counselorOnboardingHighlights,
  counselorSection,
  type CounselorFeatureId,
} from '@/content/landing'
import { cn } from '@/lib/cn'

export function PsychologistShowcase() {
  const [activeId, setActiveId] = useState<CounselorFeatureId>('schedule')
  const [evaluationOpen, setEvaluationOpen] = useState(false)
  const active = counselorFeatures.find((f) => f.id === activeId) ?? counselorFeatures[0]

  useEffect(() => {
    if (!evaluationOpen) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setEvaluationOpen(false)
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [evaluationOpen])

  return (
    <section
      id="psikolog"
      aria-labelledby="psikolog-title"
      className="relative isolate flex min-h-[100dvh] w-full flex-col justify-center overflow-hidden bg-white py-16 sm:py-20 lg:py-24 border-t border-border-subtle/50"
    >
      <Container className="my-auto flex flex-col justify-center">
        <div className="flex flex-col items-center text-center">
          <Badge tone="primary" kind="overline" icon={<Stethoscope />} className="mb-4">
            {counselorSection.kicker}
          </Badge>
          <SectionHeading
            id="psikolog-title"
            title={
              <>
                {counselorSection.titleLead}{' '}
                <span className="text-primary">{counselorSection.titleAccent}</span>
              </>
            }
            description={counselorSection.subtitle}
          />
        </div>

        <div className="mt-14 grid items-start gap-10 lg:mt-16 lg:grid-cols-[1fr_420px] lg:gap-14 xl:grid-cols-[1fr_450px] xl:gap-20 2xl:grid-cols-[1fr_470px]">
          {/* Left column: Interactive Counselor feature cards + onboarding summary + actions */}
          <div className="order-2 flex flex-col gap-6 lg:order-1">
            <div
              className="grid gap-5 sm:grid-cols-2"
              role="group"
              aria-label="Pilih fitur aplikasi Eva Counselor"
            >
              {counselorFeatures.map((f) => {
                const Icon = f.icon
                const isActive = f.id === activeId
                return (
                  <button
                    key={f.id}
                    id={`counselor-feature-${f.id}`}
                    type="button"
                    data-cursor="PRATINJAU"
                    aria-pressed={isActive}
                    aria-controls="counselor-feature-preview"
                    onClick={() => setActiveId(f.id)}
                    className={cn(
                      'reveal group relative flex cursor-pointer flex-col items-start rounded-card p-6 text-left focus-visible:outline-2 focus-visible:outline-primary',
                      'border-[1.2px] transition-[transform,box-shadow,background-color,border-color] duration-300 ease-luna',
                      isActive
                        ? 'border-primary/35 bg-canvas shadow-nav lg:-translate-y-0.5'
                        : 'border-border-subtle/80 bg-white shadow-subtle hover:-translate-y-0.5 hover:border-primary/20 hover:bg-canvas/50 hover:shadow-nav',
                    )}
                  >
                    <div className="flex w-full items-center justify-between gap-3">
                      <IconTile
                        tone={f.tone}
                        className="transition-transform duration-300 ease-luna group-hover:scale-105"
                      >
                        <Icon />
                      </IconTile>
                      <span className="text-right text-[10px] font-extrabold tracking-[0.1em] text-ink-muted uppercase">
                        {f.tag}
                      </span>
                    </div>
                    <h3 className="mt-4 text-title-md sm:text-[18px] text-ink">{f.title}</h3>
                    <p className="mt-2 text-body-md text-ink-soft leading-relaxed">{f.body}</p>
                  </button>
                )
              })}
            </div>

            {/* Verification & clinical standard summary bar */}
            <div className="reveal rounded-card border border-border-subtle/80 bg-canvas p-6 shadow-subtle sm:p-7">
              <p className="text-overline text-primary uppercase">{counselorSection.verifyHeading}</p>

              <p className="mt-2 text-body-md text-ink-soft leading-relaxed">
                {counselorSection.verifyNote}
              </p>

              <ul className="mt-4 grid gap-2.5 sm:grid-cols-3">
                {counselorOnboardingHighlights.map((item) => {
                  const Icon = item.icon
                  return (
                    <li
                      key={item.label}
                      className="flex items-start gap-2 rounded-[14px] border border-border-subtle/70 bg-white px-3 py-2.5 text-caption font-medium text-ink"
                    >
                      <Icon className="mt-0.5 size-3.5 shrink-0 text-primary" aria-hidden />
                      <span>{item.label}</span>
                    </li>
                  )
                })}
              </ul>

              <div className="mt-5">
                <Button
                  id="psikolog-open-evaluation"
                  type="button"
                  variant="secondary"
                  size="md"
                  leftIcon={<ShieldCheck />}
                  onClick={() => setEvaluationOpen(true)}
                >
                  {counselorSection.secondaryCta}
                </Button>
              </div>
            </div>
          </div>

          {/* Right column: Sticky Counselor PhoneFrame preview */}
          <div className="order-1 lg:sticky lg:top-28 lg:order-2">
            <div className="relative mx-auto flex w-fit flex-col items-center">
              <PhoneFrame
                key={activeId}
                screenshot={COUNSELOR_SCREENSHOTS[activeId]}
                screenshotAlt={`Pratinjau aplikasi Eva Counselor: ${active.title}`}
                className="w-[300px] sm:w-[330px] lg:w-[350px] xl:w-[370px]"
              >
                <div
                  id="counselor-feature-preview"
                  role="img"
                  aria-label={`Pratinjau aplikasi Eva Counselor: ${active.title}`}
                  className="h-full animate-enter"
                >
                  <CounselorScreen id={activeId} />
                </div>
              </PhoneFrame>

              {/* Mobile & Tablet Quick-Switcher Pills */}
              <div
                role="tablist"
                aria-label="Ganti layar pratinjau Eva Counselor"
                className="mt-5 flex max-w-[350px] flex-wrap items-center justify-center gap-1.5 lg:hidden"
              >
                {counselorFeatures.map((f) => {
                  const Icon = f.icon
                  const isActive = f.id === activeId
                  return (
                    <button
                      key={`counselor-pill-${f.id}`}
                      type="button"
                      role="tab"
                      aria-selected={isActive}
                      onClick={() => setActiveId(f.id)}
                      className={cn(
                        'inline-flex items-center gap-1.5 rounded-pill border px-3 py-1.5 text-caption !tracking-normal font-semibold transition-all duration-200 focus-visible:outline-2 focus-visible:outline-primary',
                        isActive
                          ? 'border-primary bg-primary text-white shadow-btn'
                          : 'border-border-subtle bg-white text-ink-soft hover:border-primary/30 hover:text-ink',
                      )}
                    >
                      <Icon className="size-3.5" />
                      <span>{f.tag.split(' ')[0]}</span>
                    </button>
                  )
                })}
              </div>

              <div
                className="mt-5 flex max-w-[360px] items-start gap-3 rounded-[18px] border border-border-subtle/80 bg-canvas p-4 shadow-subtle lg:mt-6"
                aria-live="polite"
              >
                <IconTile tone={active.tone} size="sm">
                  <active.icon />
                </IconTile>
                <div>
                  <p className="text-overline text-primary uppercase">Alur Kerja Klinis</p>
                  <p className="mt-1 text-body-md text-ink">{active.workflow}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </Container>

      {/* Clinical Evaluation Modal */}
      {evaluationOpen && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-obsidian/55 p-4 backdrop-blur-xs"
          onClick={() => setEvaluationOpen(false)}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="clinical-eval-modal-title"
            className="relative max-h-[88dvh] w-full max-w-2xl overflow-y-auto rounded-[28px] border border-border-subtle bg-white p-6 shadow-2xl sm:p-8"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-start justify-between gap-4 border-b border-divider pb-4">
              <div>
                <span className="text-overline text-primary uppercase">Standar Praktik EVA</span>
                <h3 id="clinical-eval-modal-title" className="mt-1 text-headline text-ink">
                  Evaluasi Klinis &amp; Etika Profesi
                </h3>
              </div>
              <button
                type="button"
                aria-label="Tutup dialog evaluasi klinis"
                onClick={() => setEvaluationOpen(false)}
                className="flex size-10 shrink-0 cursor-pointer items-center justify-center rounded-full border border-border-subtle text-ink-soft transition-colors hover:bg-canvas hover:text-ink focus-visible:outline-2 focus-visible:outline-primary"
              >
                <X className="size-4" />
              </button>
            </div>

            <div className="mt-5 space-y-4">
              {clinicalEvaluationData.map((item) => (
                <article
                  key={item.id}
                  className="rounded-card border border-border-subtle/80 bg-canvas p-5"
                >
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <h4 className="text-title-md text-ink">{item.title}</h4>
                    <Badge tone="primary">{item.badge}</Badge>
                  </div>
                  <p className="mt-2 text-body-md text-ink-soft leading-relaxed">{item.summary}</p>
                  <ul className="mt-3 space-y-1.5 text-caption font-medium text-ink">
                    {item.details.map((detail) => (
                      <li key={detail} className="flex items-start gap-2">
                        <span className="mt-1.5 size-1.5 shrink-0 rounded-full bg-primary" aria-hidden />
                        <span>{detail}</span>
                      </li>
                    ))}
                  </ul>
                </article>
              ))}
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
