import { ArrowLeft, Home } from 'lucide-react'
import { Link } from 'react-router'
import { Button, Container, LunaOrb } from '@/components/ui'

export function NotFoundPage() {
  return (
    <section className="relative flex min-h-[70vh] items-center justify-center py-20">
      <Container className="flex max-w-md flex-col items-center text-center">
        <LunaOrb className="size-20" still />
        <span className="mt-8 rounded-pill bg-primary-container px-3.5 py-1.5 text-overline uppercase text-primary">
          404 — Halaman Tidak Ditemukan
        </span>
        <h1 className="mt-4 text-headline text-ink">Sepertinya kamu tersesat</h1>
        <p className="mt-3 text-body-lg text-ink-soft">
          Halaman yang kamu cari belum tersedia atau sudah dipindahkan. Yuk kembali ke beranda bersama EVA.
        </p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link to="/">
            <Button size="md" leftIcon={<Home />}>
              Ke Beranda
            </Button>
          </Link>
          <Button variant="outline" size="md" leftIcon={<ArrowLeft />} onClick={() => window.history.back()}>
            Kembali
          </Button>
        </div>
      </Container>
    </section>
  )
}
