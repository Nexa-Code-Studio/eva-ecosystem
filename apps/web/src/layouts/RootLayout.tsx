import { Outlet } from 'react-router'
import { Footer, Navbar } from '@/components/sections'
import { BreathingWidget, CustomCursor, ScrollToTop, SmoothScroll } from '@/components/ui'

export function RootLayout() {
  return (
    <div className="relative flex min-h-screen flex-col overflow-x-hidden bg-canvas">
      <SmoothScroll />
      <CustomCursor />

      {/* Keyboard Accessibility Skip Link */}
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-[100] focus:rounded-pill focus:bg-primary focus:px-5 focus:py-2.5 focus:text-body-md focus:font-bold focus:text-white focus:shadow-fab"
      >
        Lewati ke konten utama
      </a>

      <Navbar />
      <main id="main-content" className="flex-1">
        <Outlet />
      </main>
      <Footer />

      <BreathingWidget />
      <ScrollToTop />
    </div>
  )
}
