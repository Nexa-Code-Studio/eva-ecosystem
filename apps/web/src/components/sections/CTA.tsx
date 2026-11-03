import { Download, ShieldCheck, Sparkles, X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Button, Container, LunaOrb } from '@/components/ui'
import { DOWNLOAD_APK_URL, waitlist } from '@/content/landing'

export function CTA() {
  const [partnerTopic, setPartnerTopic] = useState<string | null>(null)
  const [apkSize, setApkSize] = useState(() => waitlist.specs[1] || '~59 MB')

  useEffect(() => {
    // Dynamic runtime check: in case APK file on server was replaced without rebuilding frontend
    if (!DOWNLOAD_APK_URL.startsWith('http') && !DOWNLOAD_APK_URL.startsWith('/')) return
    let active = true

    fetch(DOWNLOAD_APK_URL, { method: 'HEAD' })
      .then((res) => {
        if (!res.ok) return
        const len = res.headers.get('content-length')
        if (len && active) {
          const bytes = parseInt(len, 10)
          if (!isNaN(bytes) && bytes > 0) {
            const mb = Math.round(bytes / (1024 * 1024))
            setApkSize(`~${mb} MB`)
          }
        }
      })
      .catch(() => {})

    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    const onPartnerInquiry = (e: Event) => {
      const customEvent = e as CustomEvent<{ topic: string }>
      const topic = customEvent.detail?.topic
      if (topic) {
        setPartnerTopic(topic)
      }
    }
    window.addEventListener('eva:partner-inquiry', onPartnerInquiry)
    return () => window.removeEventListener('eva:partner-inquiry', onPartnerInquiry)
  }, [])

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
          {/* Ambient atmosphere behind the orb */}
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

            {/* Partner inquiry context banner triggered from Footer */}
            {partnerTopic && (
              <div className="mt-6 inline-flex items-center gap-2 rounded-pill border border-primary-light/30 bg-primary/25 py-2 pr-3 pl-4 text-caption !tracking-normal text-white backdrop-blur-sm animate-enter">
                <Sparkles className="size-3.5 text-primary-light" />
                <span>
                  Topik Kemitraan: <strong>{partnerTopic}</strong> — hubungi tim kami di{' '}
                  <a
                    href={`mailto:kemitraan@eva.id?subject=${encodeURIComponent(`Kemitraan EVA: ${partnerTopic}`)}`}
                    className="underline decoration-primary-light font-bold hover:text-primary-light"
                  >
                    kemitraan@eva.id
                  </a>
                </span>
                <button
                  type="button"
                  onClick={() => setPartnerTopic(null)}
                  data-cursor="HAPUS"
                  aria-label="Hapus topik kemitraan"
                  className="ml-1 flex size-5 items-center justify-center rounded-full bg-white/10 text-white/80 hover:bg-white/20 hover:text-white"
                >
                  <X className="size-3" />
                </button>
              </div>
            )}

            {/* Direct Download Action Card */}
            <div className="mt-10 flex w-full max-w-xl flex-col items-center">
              <Button
                id="early-access-download-btn"
                href={DOWNLOAD_APK_URL}
                download="EVA-Beta.apk"
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
              <div className="mt-4 flex flex-wrap items-center justify-center gap-2">
                {waitlist.specs.map((spec, i) => (
                  <span
                    key={spec}
                    className="rounded-pill border border-white/15 bg-white/10 px-3.5 py-1 text-xs font-semibold text-white/90 backdrop-blur-sm"
                  >
                    {i === 1 ? apkSize : spec}
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
