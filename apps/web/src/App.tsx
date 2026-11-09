import { lazy, Suspense } from 'react'
import { createBrowserRouter, Navigate, RouterProvider } from 'react-router'
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
const AdminDashboardRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminDashboardRoute })),
)
const AdminPsychologistsRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminPsychologistsRoute })),
)
const AdminPartnersRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminPartnersRoute })),
)
const AdminReferralsRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminReferralsRoute })),
)
const AdminUsersCoinsRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminUsersCoinsRoute })),
)
const AdminContentConfigRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminContentConfigRoute })),
)

const PartnerDashboardPage = lazy(() =>
  import('@/pages/PartnerDashboardPage').then((m) => ({ default: m.PartnerDashboardPage })),
)
const PartnerPsychologistsRoute = lazy(() =>
  import('@/pages/PartnerDashboardPage').then((m) => ({ default: m.PartnerPsychologistsRoute })),
)
const PartnerReferralsRoute = lazy(() =>
  import('@/pages/PartnerDashboardPage').then((m) => ({ default: m.PartnerReferralsRoute })),
)
const PartnerProfileRoute = lazy(() =>
  import('@/pages/PartnerDashboardPage').then((m) => ({ default: m.PartnerProfileRoute })),
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
      <Suspense fallback={<div className="min-h-screen bg-[#F8FAFC]" />}>
        <AdminDashboardPage />
      </Suspense>
    ),
    children: [
      {
        index: true,
        element: <Navigate to="/admin/dashboard" replace />,
      },
      {
        path: 'dashboard',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <AdminDashboardRoute />
          </Suspense>
        ),
      },
      {
        path: 'psychologists',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <AdminPsychologistsRoute />
          </Suspense>
        ),
      },
      {
        path: 'partners',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <AdminPartnersRoute />
          </Suspense>
        ),
      },
      {
        path: 'referrals',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <AdminReferralsRoute />
          </Suspense>
        ),
      },
      {
        path: 'users-coins',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <AdminUsersCoinsRoute />
          </Suspense>
        ),
      },
      {
        path: 'content-config',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <AdminContentConfigRoute />
          </Suspense>
        ),
      },
      {
        path: '*',
        element: <Navigate to="/admin/dashboard" replace />,
      },
    ],
  },
  {
    path: '/mitra',
    element: (
      <Suspense fallback={<div className="min-h-screen bg-[#F8F9FE]" />}>
        <PartnerDashboardPage />
      </Suspense>
    ),
    children: [
      {
        index: true,
        element: <Navigate to="/mitra/psychologists" replace />,
      },
      {
        path: 'psychologists',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <PartnerPsychologistsRoute />
          </Suspense>
        ),
      },
      {
        path: 'referrals',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <PartnerReferralsRoute />
          </Suspense>
        ),
      },
      {
        path: 'profile',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <PartnerProfileRoute />
          </Suspense>
        ),
      },
      {
        path: '*',
        element: <Navigate to="/mitra/psychologists" replace />,
      },
    ],
  },
])

export default function App() {
  return <RouterProvider router={router} />
}
