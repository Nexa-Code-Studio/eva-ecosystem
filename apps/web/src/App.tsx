import { lazy, Suspense } from 'react'
import { createBrowserRouter, Navigate, RouterProvider } from 'react-router'
import { RootLayout } from '@/layouts/RootLayout'
import { LandingPage } from '@/pages/LandingPage'
import { NotFoundPage } from '@/pages/NotFoundPage'

const LoginPage = lazy(() =>
  import('@/pages/LoginPage').then((m) => ({ default: m.LoginPage })),
)
const FeedbackPage = lazy(() =>
  import('@/pages/FeedbackPage').then((m) => ({ default: m.FeedbackPage })),
)
const AdminDashboardPage = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminDashboardPage })),
)
const AdminDashboardRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminDashboardRoute })),
)
const AdminPsychologistsRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({
    default: m.AdminPsychologistsRoute,
  })),
)
const AdminMonitoringRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminMonitoringRoute })),
)
const AdminSettingsRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminSettingsRoute })),
)
const AdminUsersCoinsRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminUsersCoinsRoute })),
)
const AdminFinanceRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({ default: m.AdminFinanceRoute })),
)
const AdminContentConfigRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({
    default: m.AdminContentConfigRoute,
  })),
)
const AdminCertificatesRoute = lazy(() =>
  import('@/pages/AdminDashboardPage').then((m) => ({
    default: m.AdminCertificatesRoute,
  })),
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
    path: '/feedback',
    element: (
      <Suspense fallback={<div className="min-h-screen bg-[#F8F9FE]" />}>
        <FeedbackPage />
      </Suspense>
    ),
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
        path: 'certificates',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <AdminCertificatesRoute />
          </Suspense>
        ),
      },
      {
        path: 'monitoring',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <AdminMonitoringRoute />
          </Suspense>
        ),
      },
      {
        path: 'settings',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <AdminSettingsRoute />
          </Suspense>
        ),
      },
      {
        path: 'settings/psychologist-levels',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <AdminSettingsRoute />
          </Suspense>
        ),
      },
      {
        path: 'referrals',
        element: <Navigate to="/admin/monitoring" replace />,
      },
      {
        path: 'partners',
        element: <Navigate to="/admin/psychologists" replace />,
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
        path: 'finance',
        element: (
          <Suspense fallback={<div className="min-h-[400px] animate-pulse rounded-xl bg-white/50" />}>
            <AdminFinanceRoute />
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
])

export default function App() {
  return <RouterProvider router={router} />
}
