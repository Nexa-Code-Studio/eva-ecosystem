import { Container, SectionHeading } from '@/components/ui'
import { steps } from '@/content/landing'

export function HowItWorks() {
  return (
    <section
      id="cara-kerja"
      aria-labelledby="cara-kerja-title"
      className="relative isolate flex min-h-[100dvh] w-full flex-col justify-center overflow-hidden bg-canvas py-20 sm:py-24 lg:py-28 border-t border-border-subtle/50"
    >
      <Container className="flex flex-col justify-center my-auto">
        <SectionHeading
          id="cara-kerja-title"
          title="4 langkah kecil menuju hati yang lebih ringan"
          description="Tidak perlu persiapan, tidak perlu kata-kata yang sempurna. Mulai saja dari apa yang kamu rasakan sekarang."
        />

        <ol className="relative mt-16 grid gap-6 md:grid-cols-2 lg:grid-cols-4 lg:gap-5">
          {/* connector line (desktop) */}
          <span
            aria-hidden
            className="absolute top-7 right-[12%] left-[12%] hidden h-[1.5px] bg-border-subtle lg:block"
          />
          {steps.map((s, i) => {
            const Icon = s.icon
            return (
              <li key={s.title} className="reveal group relative flex gap-5 lg:flex-col lg:items-center lg:text-center">
                {/* connector line (mobile) */}
                {i < steps.length - 1 && (
                  <span aria-hidden className="absolute top-16 bottom-[-24px] left-7 w-[2px] bg-border-subtle md:hidden" />
                )}
                <span className="relative z-10 flex size-14 shrink-0 items-center justify-center rounded-full border-[3px] border-white bg-primary text-white shadow-btn transition-transform duration-300 ease-luna group-hover:scale-105">
                  <Icon className="size-6" />
                  <span className="absolute -top-1.5 -right-1.5 flex size-6 items-center justify-center rounded-full bg-white text-[11px] font-extrabold text-primary shadow-subtle border border-border-subtle/60">
                    {i + 1}
                  </span>
                </span>
                <div className="flex-1 rounded-card border border-border-subtle/80 bg-white p-6 sm:p-7 shadow-subtle transition-[transform,box-shadow,border-color] duration-300 ease-luna group-hover:-translate-y-1 group-hover:border-primary/25 group-hover:shadow-nav lg:mt-6 lg:w-full">
                  <p className="text-overline text-primary uppercase">Langkah {i + 1}</p>
                  <h3 className="mt-1.5 text-title-md sm:text-[18px]">{s.title}</h3>
                  <p className="mt-2 text-body-md text-ink-soft leading-relaxed">{s.body}</p>
                </div>
              </li>
            )
          })}
        </ol>
      </Container>
    </section>
  )
}
