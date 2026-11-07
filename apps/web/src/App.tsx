import { lazy, Suspense } from 'react'
import { createBrowserRouter, RouterProvider } from 'react-router'
import { RootLayout } from '@/layouts/RootLayout'
import { LandingPage } from '@/pages/LandingPage'
import { NotFoundPage } from '@/pages/NotFoundPage'

const LoginPage = lazy(() =>
  import('@/pages/LoginPage').then((m) => ({ default: m.LoginPage })),
)
const PartnerApplyPage = lazy(() =>
  import('@/pages/PartnerApplyPage').then((m) => ({ default: m.PartnerApplyPage })),
)
const AdminDashboardPage = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminDashboardPage })),
)
const PartnerDashboardPage = lazy(() =>
  import('@/pages/PartnerDashboardPage').then((m) => ({ default: m.PartnerDashboardPage })),
)

const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    children: [
      {
        index: true,
        element: <LandingPage />,
      },
      {
        path: '*',
        element: <NotFoundPage />,
      },
    ],
  },
  {
    path: '/login',
    element: (
      <Suspense fallback={<div className="min-h-screen bg-[#F8F9FE]" />}>
        <LoginPage />
      </Suspense>
    ),
  },
  {
    path: '/pengajuan-mitra',
    element: (
      <Suspense fallback={<div className="min-h-screen bg-[#F8F9FE]" />}>
        <PartnerApplyPage />
      </Suspense>
    ),
  },
  {
    path: '/admin',
    element: (
      <Suspense fallback={<div className="min-h-screen bg-[#F8F9FE]" />}>
        <AdminDashboardPage />
      </Suspense>
    ),
  },
  {
    path: '/mitra',
    element: (
      <Suspense fallback={<div className="min-h-screen bg-[#F8F9FE]" />}>
        <PartnerDashboardPage />
      </Suspense>
    ),
  },
])

export default function App() {
  return <RouterProvider router={router} />
}
