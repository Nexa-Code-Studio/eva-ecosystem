import { ChevronDown, HelpCircle, Sparkles } from 'lucide-react'
import { useMemo, useState } from 'react'
import { Container, SectionHeading } from '@/components/ui'
import { faqs as defaultFaqs } from '@/content/landing'
import { cn } from '@/lib/cn'
import { usePortalDb } from '@/lib/portalStore'

export function FAQ() {
  const { db } = usePortalDb()
  const faqs = useMemo(() => {
    const published = db.faqs?.filter((item) => item.isPublished)
    return published && published.length > 0 ? published : defaultFaqs
  }, [db.faqs])

  const [openId, setOpenId] = useState<string | null>(() => faqs[0]?.id ?? null)

  const toggle = (id: string) => {
    setOpenId((prev) => (prev === id ? null : id))
  }

  return (
    <section
      id="faq"
      aria-labelledby="faq-title"
      className="relative isolate flex min-h-[100dvh] w-full flex-col justify-center overflow-hidden bg-canvas py-16 sm:py-20 lg:py-24 border-t border-border-subtle/50"
    >
      <Container className="flex flex-col justify-center my-auto">
        <SectionHeading
          id="faq-title"
          title={
            <>
              Pertanyaan yang sering <span className="text-primary">ditanyakan</span>
            </>
          }
          description="Transparansi penuh tentang cara EVA menjaga privasimu, batas klinis, hingga akses gratis selama masa beta."
        />

        <div className="mx-auto mt-14 max-w-3xl space-y-4">
          {faqs.map((item) => {
            const isOpen = openId === item.id
            const panelId = `faq-panel-${item.id}`
            const triggerId = `faq-trigger-${item.id}`

            return (
              <div
                key={item.id}
                className={cn(
                  'reveal overflow-hidden rounded-[22px] border-[1.2px] transition-[border-color,background-color,box-shadow] duration-300 ease-luna',
                  isOpen
                    ? 'border-primary/30 bg-white shadow-nav'
                    : 'border-border-subtle/80 bg-white/80 shadow-subtle hover:border-primary/20 hover:bg-white',
                )}
              >
                <h3>
                  <button
                    id={triggerId}
                    type="button"
                    aria-expanded={isOpen}
                    aria-controls={panelId}
                    data-cursor={isOpen ? 'TUTUP' : 'BUKA'}
                    onClick={() => toggle(item.id)}
                    className="flex w-full items-center justify-between gap-4 p-5 text-left sm:p-6"
                  >
                    <div className="flex flex-col gap-1">
                      <span className="text-[10px] font-extrabold tracking-widest text-primary uppercase">
                        {item.category}
                      </span>
                      <span className="text-title-md sm:text-[17px] font-bold text-ink">
                        {item.question}
                      </span>
                    </div>
                    <span
                      aria-hidden="true"
                      className={cn(
                        'flex size-9 shrink-0 items-center justify-center rounded-full transition-colors duration-300',
                        isOpen
                          ? 'bg-primary text-white shadow-btn'
                          : 'bg-primary-container/60 text-primary',
                      )}
                    >
                      <ChevronDown
                        className={cn(
                          'size-4 transition-transform duration-300 ease-luna',
                          isOpen && 'rotate-180',
                        )}
                      />
                    </span>
                  </button>
                </h3>

                <div
                  id={panelId}
                  role="region"
                  aria-labelledby={triggerId}
                  className={cn(
                    'grid transition-[grid-template-rows,opacity] duration-300 ease-luna',
                    isOpen ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0',
                  )}
                >
                  <div className="overflow-hidden">
                    <p className="border-t border-border-subtle/60 px-5 pt-4 pb-6 text-body-md leading-relaxed text-ink-soft sm:px-6">
                      {item.answer}
                    </p>
                  </div>
                </div>
              </div>
            )
          })}
        </div>

        {/* Calming micro-prompt below FAQ */}
        <div className="mx-auto mt-10 flex max-w-3xl flex-col items-center justify-between gap-4 rounded-[20px] border border-primary/15 bg-primary-container/40 px-6 py-4 sm:flex-row">
          <div className="flex items-center gap-3 text-center sm:text-left">
            <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-white text-primary shadow-subtle">
              <HelpCircle className="size-4" />
            </span>
            <p className="text-body-md font-medium text-ink">
              Sedang merasa cemas saat membaca halaman ini? Ambil jeda napas terpandu dulu.
            </p>
          </div>
          <button
            type="button"
            data-cursor="TENANG"
            onClick={() => window.dispatchEvent(new CustomEvent('eva:open-breathing'))}
            className="inline-flex shrink-0 items-center gap-2 rounded-pill bg-white px-4 py-2.5 text-caption !tracking-normal font-bold text-primary shadow-subtle transition-all hover:-translate-y-0.5 hover:shadow-nav"
          >
            <Sparkles className="size-3.5" /> Coba Tarik Napas 30d
          </button>
        </div>
      </Container>
    </section>
  )
}

