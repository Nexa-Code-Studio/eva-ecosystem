import { ArrowRight, Menu, X } from 'lucide-react'
import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { Link } from 'react-router'
import { Button, Container, Logo } from '@/components/ui'
import { navLinks } from '@/content/landing'
import { scrollToCenteredSection, useActiveSection, useScrolled } from '@/hooks/useScroll'
import { cn } from '@/lib/cn'

const sectionIds = navLinks.map((l) => l.id)

/**
 * Floating glass navbar inspired by the mobile FloatingNavBar:
 * pill container, L4 shadow, and a sliding active-indicator pill (#E8E9FF, easeOutCubic).
 */
export function Navbar() {
  const scrolled = useScrolled()
  const active = useActiveSection(sectionIds)
  const [open, setOpen] = useState(false)

  const linkRefs = useRef<Record<string, HTMLAnchorElement | null>>({})
  const [pill, setPill] = useState<{ left: number; width: number } | null>(null)

  // Universal centered smooth scroll handler for all sections
  const handleNavClick = (e: React.MouseEvent<HTMLAnchorElement>, id: string) => {
    e.preventDefault()
    setOpen(false)
    scrollToCenteredSection(id)
  }

  useLayoutEffect(() => {
    const el = active ? linkRefs.current[active] : null
    setPill(el ? { left: el.offsetLeft, width: el.offsetWidth } : null)
  }, [active])

  // Close mobile menu on Escape / resize to desktop
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false)
    const mq = window.matchMedia('(min-width: 768px)')
    const onMq = () => mq.matches && setOpen(false)
    window.addEventListener('keydown', onKey)
    mq.addEventListener('change', onMq)
    return () => {
      window.removeEventListener('keydown', onKey)
      mq.removeEventListener('change', onMq)
    }
  }, [open])

  return (
    <header className="fixed inset-x-0 top-0 z-50 pt-3 sm:pt-4">
      <Container>
        <nav
          aria-label="Navigasi utama"
          className={cn(
            'relative flex h-[62px] items-center justify-between rounded-pill pr-2 pl-5 sm:pr-3 sm:pl-6 transition-[background-color,box-shadow,border-color,backdrop-filter] duration-300 ease-luna',
            scrolled || open
              ? 'border border-white/80 bg-white/90 shadow-nav backdrop-blur-xl'
              : 'border border-transparent bg-transparent',
          )}
        >
          <a
            href="#top"
            onClick={(e) => handleNavClick(e, 'top')}
            data-cursor="BERANDA"
            aria-label="EVA — kembali ke atas"
            className="shrink-0"
          >
            <Logo />
          </a>

          {/* Desktop links with sliding indicator */}
          <div className="relative hidden items-center md:flex">
            <span
              aria-hidden
              className="absolute inset-y-0 rounded-[16px] bg-primary-container transition-[left,width,opacity] duration-300 ease-luna"
              style={{ left: pill?.left ?? 0, width: pill?.width ?? 0, opacity: pill ? 1 : 0 }}
            />
            {navLinks.map((l) => (
              <a
                key={l.id}
                id={`nav-${l.id}`}
                ref={(el) => {
                  linkRefs.current[l.id] = el
                }}
                href={`#${l.id}`}
                onClick={(e) => handleNavClick(e, l.id)}
                data-cursor="LIHAT"
                aria-current={active === l.id ? 'true' : undefined}
                className={cn(
                  'relative z-10 rounded-[16px] px-4 py-2 text-body-md font-semibold transition-colors duration-[250ms]',
                  active === l.id ? 'text-primary' : 'text-ink-soft hover:text-ink',
                )}
              >
                {l.label}
              </a>
            ))}
          </div>

          <div className="flex items-center gap-2">
            <Link
              to="/login"
              id="nav-login"
              data-cursor="MASUK"
              className="hidden h-10 items-center justify-center rounded-pill px-4 text-xs font-semibold text-ink-soft transition-colors duration-[250ms] hover:bg-primary-container/60 hover:text-primary sm:inline-flex"
            >
              Masuk
            </Link>
            <Button
              id="nav-cta"
              href="#early-access"
              onClick={(e) => handleNavClick(e, 'early-access')}
              data-cursor="MULAI"
              size="sm"
              className="hidden sm:inline-flex"
              rightIcon={<ArrowRight />}
            >
              Coba Gratis
            </Button>
            <button
              id="nav-menu-toggle"
              type="button"
              data-cursor={open ? 'TUTUP' : 'MENU'}
              aria-label={open ? 'Tutup menu' : 'Buka menu'}
              aria-expanded={open}
              aria-controls="mobile-menu"
              onClick={() => setOpen((v) => !v)}
              className="flex size-11 items-center justify-center rounded-full text-ink transition-colors hover:bg-primary-container md:hidden"
            >
              {open ? <X className="size-5" /> : <Menu className="size-5" />}
            </button>
          </div>
        </nav>

        {/* Mobile menu */}
        <div
          id="mobile-menu"
          hidden={!open}
          className="mt-2 origin-top animate-enter rounded-card border border-border-subtle/80 bg-white/96 p-3 shadow-nav backdrop-blur-xl md:hidden"
        >
          <ul className="flex flex-col">
            {navLinks.map((l) => (
              <li key={l.id}>
                <a
                  href={`#${l.id}`}
                  onClick={(e) => handleNavClick(e, l.id)}
                  className={cn(
                    'flex items-center justify-between rounded-[16px] px-4 py-3.5 text-title-md transition-colors',
                    active === l.id ? 'bg-primary-container text-primary' : 'text-ink hover:bg-primary-container/50',
                  )}
                >
                  {l.label}
                  <ArrowRight className="size-4 opacity-50" />
                </a>
              </li>
            ))}
            <li>
              <Link
                to="/login"
                onClick={() => setOpen(false)}
                className="flex items-center justify-between rounded-[16px] px-4 py-3.5 text-title-md text-ink transition-colors hover:bg-primary-container/50"
              >
                Masuk
                <ArrowRight className="size-4 opacity-50" />
              </Link>
            </li>
          </ul>
          <Button
            href="#early-access"
            onClick={(e) => handleNavClick(e, 'early-access')}
            fullWidth
            size="lg"
            className="mt-2"
          >
            Coba EVA Sekarang — Gratis
          </Button>
        </div>
      </Container>
    </header>
  )
}
