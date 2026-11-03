import { Check, Minus } from 'lucide-react'
import { Container, IconTile, LogoMark, SectionHeading } from '@/components/ui'
import { uspRows } from '@/content/landing'

export function USP() {
  return (
    <section
      id="keunggulan"
      aria-labelledby="keunggulan-title"
      className="relative isolate flex min-h-[100dvh] w-full flex-col justify-center overflow-hidden bg-canvas py-16 sm:py-20 lg:py-24 border-t border-border-subtle/50"
    >
      <Container className="flex flex-col justify-center my-auto">
        <SectionHeading
          id="keunggulan-title"
          title={
            <>
              Bukan chatbot biasa. <span className="text-primary">Sahabat yang paham.</span>
            </>
          }
          description="Perbedaan yang terasa sejak percakapan pertama — dari cara EVA mendengar hingga cara ia menjaga rahasiamu."
        />

        <div className="reveal mt-14 overflow-hidden rounded-[24px] border border-border-subtle/80 bg-white shadow-subtle">
          {/* Header row (desktop) */}
          <div className="hidden grid-cols-[1fr_1.15fr_1.45fr] border-b border-border-subtle/80 md:grid">
            <div className="p-6 md:p-8 xl:p-9 text-caption text-ink-muted uppercase">Dimensi</div>
            <div className="p-6 md:p-8 xl:p-9 text-caption text-ink-muted uppercase">Konvensional / Chatbot Biasa</div>
            <div className="flex items-center gap-2.5 bg-primary-container/40 p-6 md:p-8 xl:p-9">
              <LogoMark className="size-6 rounded-[7px] [&>svg]:size-3.5" />
              <span className="text-title-md font-bold text-primary">EVA (Empathetic Vitality Assistant)</span>
            </div>
          </div>

          <ul>
            {uspRows.map((r) => {
              const Icon = r.icon
              return (
                <li
                  key={r.dimension}
                  className="group grid border-b border-border-subtle/80 transition-colors duration-[250ms] last:border-b-0 hover:bg-canvas/50 md:grid-cols-[1fr_1.15fr_1.45fr]"
                >
                  <div className="flex items-center gap-4 p-5 pb-3 md:p-8 xl:p-9">
                    <IconTile size="sm" className="transition-transform duration-300 ease-luna group-hover:scale-110">
                      <Icon />
                    </IconTile>
                    <h3 className="text-title-md font-semibold text-ink">{r.dimension}</h3>
                  </div>
                  <div className="flex gap-3 px-5 pb-3 md:p-8 xl:p-9">
                    <span className="mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full bg-ink-muted/15 text-ink-muted">
                      <Minus className="size-3" />
                    </span>
                    <p className="text-body-md text-ink-muted leading-relaxed">
                      <span className="font-semibold md:hidden">Biasanya: </span>
                      {r.others}
                    </p>
                  </div>
                  <div className="mx-3 mb-3 flex gap-3 rounded-[18px] bg-primary-container/40 p-4 md:m-0 md:rounded-none md:p-8 xl:p-9">
                    <span className="mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full bg-primary text-white shadow-btn">
                      <Check className="size-3" strokeWidth={3} />
                    </span>
                    <p className="text-body-md font-medium text-ink leading-relaxed">{r.eva}</p>
                  </div>
                </li>
              )
            })}
          </ul>
        </div>
      </Container>
    </section>
  )
}
