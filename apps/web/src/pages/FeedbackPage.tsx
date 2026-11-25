import { useEffect, useRef, useState, type FormEvent } from 'react'
import { ArrowLeft, CheckCircle2, Circle, Loader2, Lock, Send } from 'lucide-react'
import { Link } from 'react-router'
import {
  BoothPhotoPicker,
  type SelectedBoothPhoto,
} from '@/components/feedback/BoothPhotoPicker'
import { RatingSelector } from '@/components/feedback/RatingSelector'
import { Button, Logo } from '@/components/ui'
import { cn } from '@/lib/cn'
import { submitBoothFeedback } from '@/lib/portalStore'
import type { SubmitBoothFeedbackResult } from '@/types/portal'

export function FeedbackPage() {
  const [visitorName, setVisitorName] = useState('')
  const [visitorContact, setVisitorContact] = useState('')
  const [rating, setRating] = useState<number>(0)
  const [message, setMessage] = useState('')
  const [photos, setPhotos] = useState<SelectedBoothPhoto[]>([])
  const [photoNote, setPhotoNote] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [submittedResult, setSubmittedResult] = useState<SubmitBoothFeedbackResult | null>(null)

  const photosRef = useRef<SelectedBoothPhoto[]>([])
  useEffect(() => {
    photosRef.current = photos
  }, [photos])

  useEffect(() => {
    return () => {
      photosRef.current.forEach((p) => URL.revokeObjectURL(p.previewUrl))
    }
  }, [])

  const handleAddPhotos = (newItems: SelectedBoothPhoto[]) => {
    setPhotos((prev) => [...prev, ...newItems].slice(0, 5))
    setErrorMessage(null)
  }

  const handleRemovePhoto = (id: string) => {
    setPhotos((prev) => {
      const target = prev.find((p) => p.id === id)
      if (target) URL.revokeObjectURL(target.previewUrl)
      return prev.filter((p) => p.id !== id)
    })
  }

  const resetForm = () => {
    photos.forEach((p) => URL.revokeObjectURL(p.previewUrl))
    setVisitorName('')
    setVisitorContact('')
    setRating(0)
    setMessage('')
    setPhotos([])
    setPhotoNote(null)
    setErrorMessage(null)
    setSubmittedResult(null)
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    if (submitting) return

    if (rating < 1 || rating > 5) {
      setErrorMessage('Ketuk bintang 1 sampai 5 terlebih dahulu sebelum mengirim.')
      return
    }
    const trimmedMessage = message.trim()
    if (trimmedMessage.length < 5) {
      setErrorMessage('Tuliskan masukan, saran, atau kritik minimal 5 karakter.')
      return
    }
    if (photos.length === 0) {
      setErrorMessage('Lampirkan minimal 1 foto selfie atau momen Anda di booth EVA.')
      return
    }

    setSubmitting(true)
    setErrorMessage(null)
    try {
      const result = await submitBoothFeedback({
        rating,
        message: trimmedMessage,
        visitorName: visitorName.trim() || undefined,
        visitorContact: visitorContact.trim() || undefined,
        eventLabel: 'Event Booth EVA',
        photos: photos.map((p) => p.file),
      })
      setSubmittedResult(result)
    } catch (err) {
      setErrorMessage(
        err instanceof Error ? err.message : 'Gagal mengirim feedback booth. Silakan coba lagi.',
      )
    } finally {
      setSubmitting(false)
    }
  }

  const isRatingDone = rating >= 1 && rating <= 5
  const isMessageDone = message.trim().length >= 5
  const isPhotosDone = photos.length >= 1

  return (
    <div className="min-h-screen bg-canvas text-ink">
      {/* Keyboard Skip Link (R-39) */}
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:z-50 focus:rounded-pill focus:bg-primary focus:px-4 focus:py-2 focus:text-xs focus:font-bold focus:text-white"
      >
        Lewati ke form feedback
      </a>

      <header className="border-b border-border-subtle bg-white">
        <div className="mx-auto flex h-14 max-w-5xl items-center justify-between px-4 sm:h-16 sm:px-6">
          <Link
            to="/"
            aria-label="Kembali ke beranda EVA"
            className="inline-flex min-h-11 items-center focus-visible:outline-2 focus-visible:outline-primary"
          >
            <Logo />
          </Link>
          <Link
            to="/"
            className="inline-flex min-h-11 items-center gap-1.5 rounded-pill border border-[#CBD5E1] bg-white px-4 text-xs font-semibold text-ink hover:bg-canvas focus-visible:outline-2 focus-visible:outline-primary"
          >
            <ArrowLeft className="size-3.5 shrink-0" aria-hidden="true" />
            <span>Beranda</span>
          </Link>
        </div>
      </header>

      <main
        id="main-content"
        className={cn(
          'mx-auto max-w-5xl px-4 pt-5 sm:px-6 sm:pt-8 sm:pb-16',
          submittedResult ? 'pb-14' : 'pb-28',
        )}
      >
        {submittedResult ? (
          <section
            aria-labelledby="feedback-success-title"
            className="mx-auto max-w-lg rounded-[24px] border border-[#BBF7D0] bg-white p-6 shadow-subtle sm:p-8"
          >
            <div className="inline-flex size-12 items-center justify-center rounded-full bg-[#ECFDF5] text-[#047857]">
              <CheckCircle2 className="size-6" aria-hidden="true" />
            </div>
            <h1 id="feedback-success-title" className="mt-4 text-xl font-bold text-ink sm:text-2xl">
              Terima kasih telah singgah di Booth EVA
            </h1>
            <p className="mt-2 text-sm leading-relaxed text-ink-soft">
              {submittedResult.message}
            </p>
            <dl className="mt-5 grid grid-cols-2 gap-3 rounded-[16px] border border-[#E2E8F0] bg-canvas p-4 text-center text-xs">
              <div>
                <dt className="text-ink-muted">Rating Anda</dt>
                <dd className="mt-1 text-base font-bold text-ink">{submittedResult.rating} / 5 Bintang</dd>
              </div>
              <div>
                <dt className="text-ink-muted">Foto Booth</dt>
                <dd className="mt-1 text-base font-bold text-ink">{submittedResult.photoCount} foto tersimpan</dd>
              </div>
            </dl>
            <div className="mt-6 flex flex-col gap-2.5 sm:flex-row">
              <Button type="button" onClick={resetForm} fullWidth className="min-h-11">
                Kirim Feedback Lainnya
              </Button>
              <Button to="/" variant="secondary" fullWidth className="min-h-11">
                Kembali ke Beranda
              </Button>
            </div>
          </section>
        ) : (
          <div className="mx-auto max-w-xl lg:grid lg:max-w-none lg:grid-cols-[5fr_7fr] lg:items-start lg:gap-8">
            {/* Left Editorial Brief & Readiness Panel (Desktop sticky, Mobile compact header) */}
            <aside className="mb-5 lg:sticky lg:top-8 lg:mb-0">
              <div className="rounded-[20px] border border-primary/20 bg-white p-4 shadow-subtle sm:p-6">
                <p className="text-overline font-bold tracking-[0.12em] text-primary-deep uppercase">
                  Guestbook Event Booth
                </p>
                <h1 className="mt-1.5 text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl lg:text-[28px] lg:leading-tight">
                  Bagikan Kesan &amp; Foto Booth Anda
                </h1>
                <p className="mt-2 text-sm leading-relaxed text-ink-soft">
                  Beri rating pengalaman mencoba EVA, tulis masukan atau saran Anda, lalu lampirkan selfie momen di booth.
                </p>

                <div className="mt-4 flex items-start gap-2.5 rounded-[14px] border border-[#E2E8F0] bg-canvas px-3.5 py-3 text-xs text-ink-soft">
                  <Lock className="mt-0.5 size-4 shrink-0 text-primary-deep" aria-hidden="true" />
                  <span>
                    Foto selfie hanya disimpan untuk dokumentasi internal panitia event dan tidak dipublikasikan ke halaman umum.
                  </span>
                </div>

                {/* Desktop Live Checklist Summary */}
                <div className="mt-5 hidden border-t border-[#F1F5F9] pt-4 lg:block">
                  <p className="text-xs font-bold text-ink">Kelengkapan Kiriman</p>
                  <ul className="mt-2.5 space-y-2 text-xs">
                    <li className="flex items-center gap-2">
                      {isRatingDone ? (
                        <CheckCircle2 className="size-4 shrink-0 text-[#047857]" aria-hidden="true" />
                      ) : (
                        <Circle className="size-4 shrink-0 text-ink-muted" aria-hidden="true" />
                      )}
                      <span className={isRatingDone ? 'font-semibold text-ink' : 'text-ink-muted'}>
                        Rating pengalaman ({isRatingDone ? `${rating}/5` : 'belum dipilih'})
                      </span>
                    </li>
                    <li className="flex items-center gap-2">
                      {isMessageDone ? (
                        <CheckCircle2 className="size-4 shrink-0 text-[#047857]" aria-hidden="true" />
                      ) : (
                        <Circle className="size-4 shrink-0 text-ink-muted" aria-hidden="true" />
                      )}
                      <span className={isMessageDone ? 'font-semibold text-ink' : 'text-ink-muted'}>
                        Masukan / saran / kritik ({message.trim().length} karakter)
                      </span>
                    </li>
                    <li className="flex items-center gap-2">
                      {isPhotosDone ? (
                        <CheckCircle2 className="size-4 shrink-0 text-[#047857]" aria-hidden="true" />
                      ) : (
                        <Circle className="size-4 shrink-0 text-ink-muted" aria-hidden="true" />
                      )}
                      <span className={isPhotosDone ? 'font-semibold text-ink' : 'text-ink-muted'}>
                        Foto booth ({photos.length}/5 terlampir, min 1)
                      </span>
                    </li>
                  </ul>
                </div>
              </div>
            </aside>

            {/* Right Interactive Composer */}
            <form
              id="booth-feedback-form"
              onSubmit={(e) => void handleSubmit(e)}
              noValidate
              className="space-y-5 rounded-[20px] border border-border-subtle bg-white p-4 shadow-subtle sm:rounded-[24px] sm:p-6"
            >
              {/* 1. Gojek / Shopee Open Star Rating */}
              <div className="rounded-[16px] bg-canvas/70 px-3 py-4 text-center sm:px-4">
                <span className="mb-3 block text-sm font-bold text-ink">
                  Bagaimana pengalaman Anda di booth EVA? <span className="text-[#B91C1C]">*</span>
                </span>
                <RatingSelector value={rating} onChange={(val) => setRating(val)} disabled={submitting} />
              </div>

              {/* 2. Comment Input */}
              <div className="border-t border-[#F1F5F9] pt-4">
                <div className="flex items-center justify-between gap-2">
                  <label htmlFor="booth-message" className="text-xs font-semibold text-ink">
                    Masukan, Saran, atau Kritik <span className="text-[#B91C1C]">*</span>
                  </label>
                  <span className="text-xs text-ink-muted">{message.trim().length} / 2000</span>
                </div>

                <textarea
                  id="booth-message"
                  required
                  rows={4}
                  minLength={5}
                  maxLength={2000}
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  placeholder="Ceritakan pengalaman, saran, atau kritik Anda setelah mencoba EVA..."
                  className="mt-2 w-full resize-none rounded-[14px] border border-[#CBD5E1] bg-white p-3.5 text-sm leading-relaxed text-ink focus:border-primary focus:outline-none"
                />
              </div>

              {/* 3. Multi-Photo Picker + Live Camera Selector */}
              <div className="border-t border-[#F1F5F9] pt-4">
                <BoothPhotoPicker
                  photos={photos}
                  disabled={submitting}
                  onAddPhotos={handleAddPhotos}
                  onRemovePhoto={handleRemovePhoto}
                  onValidationMessage={setPhotoNote}
                />
                {photoNote && (
                  <p className="mt-2 rounded-[10px] border border-[#FDE68A] bg-[#FFFBEB] px-3 py-2 text-xs font-medium text-[#92400E]">
                    {photoNote}
                  </p>
                )}
              </div>

              {/* 4. Optional Identity (1 col phone -> 2 col tablet/desktop) */}
              <div className="border-t border-[#F1F5F9] pt-4">
                <p className="mb-2.5 text-xs font-semibold text-ink">
                  Identitas Pengunjung <span className="font-normal text-ink-muted">(Opsional)</span>
                </p>
                <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                  <div>
                    <label htmlFor="visitor-name" className="block text-xs font-medium text-ink-soft">
                      Nama atau Inisial
                    </label>
                    <input
                      id="visitor-name"
                      type="text"
                      maxLength={120}
                      value={visitorName}
                      onChange={(e) => setVisitorName(e.target.value)}
                      placeholder="Nama Anda"
                      className="mt-1 min-h-11 w-full rounded-[12px] border border-[#CBD5E1] bg-white px-3 text-sm text-ink focus:border-primary focus:outline-none"
                    />
                  </div>
                  <div>
                    <label htmlFor="visitor-contact" className="block text-xs font-medium text-ink-soft">
                      Instagram / Kontak
                    </label>
                    <input
                      id="visitor-contact"
                      type="text"
                      maxLength={150}
                      value={visitorContact}
                      onChange={(e) => setVisitorContact(e.target.value)}
                      placeholder="@username atau email"
                      className="mt-1 min-h-11 w-full rounded-[12px] border border-[#CBD5E1] bg-white px-3 text-sm text-ink focus:border-primary focus:outline-none"
                    />
                  </div>
                </div>
              </div>

              {errorMessage && (
                <div
                  role="alert"
                  className="rounded-[12px] border border-[#FECACA] bg-[#FEF2F2] px-3.5 py-2.5 text-xs font-semibold text-[#991B1B]"
                >
                  {errorMessage}
                </div>
              )}

              {/* Tablet & Desktop Inline Submit */}
              <div className="hidden pt-1 sm:flex">
                <button
                  type="submit"
                  disabled={submitting}
                  className="flex min-h-12 w-full cursor-pointer items-center justify-center gap-2 rounded-pill bg-primary px-6 text-sm font-bold text-white shadow-btn transition-colors hover:bg-primary-deep focus-visible:outline-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {submitting ? (
                    <>
                      <Loader2 className="size-4 animate-spin" aria-hidden="true" />
                      <span>Mengirim Feedback &amp; Foto...</span>
                    </>
                  ) : (
                    <>
                      <Send className="size-4 shrink-0" aria-hidden="true" />
                      <span>Kirim Feedback Booth</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        )}
      </main>

      {/* Mobile Sticky Bottom Submit Bar (< 640px, safe-area inset respected) */}
      {!submittedResult && (
        <div className="fixed inset-x-0 bottom-0 z-30 border-t border-border-subtle bg-white/95 px-4 pt-2.5 pb-[max(12px,env(safe-area-inset-bottom))] backdrop-blur-md sm:hidden">
          <div className="mx-auto flex max-w-xl items-center gap-3">
            <div className="min-w-0 shrink-0 text-[11px] leading-tight text-ink-soft">
              <p className="font-bold text-ink">{isRatingDone ? `${rating}/5 Bintang` : 'Belum beri bintang'}</p>
              <p>{photos.length}/5 foto</p>
            </div>
            <button
              type="submit"
              form="booth-feedback-form"
              disabled={submitting}
              className="flex min-h-12 flex-1 cursor-pointer items-center justify-center gap-2 rounded-pill bg-primary px-4 text-sm font-bold text-white shadow-btn active:scale-[0.98] focus-visible:outline-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-60"
            >
              {submitting ? (
                <>
                  <Loader2 className="size-4 animate-spin" aria-hidden="true" />
                  <span>Mengirim...</span>
                </>
              ) : (
                <>
                  <Send className="size-4 shrink-0" aria-hidden="true" />
                  <span>Kirim Feedback</span>
                </>
              )}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
