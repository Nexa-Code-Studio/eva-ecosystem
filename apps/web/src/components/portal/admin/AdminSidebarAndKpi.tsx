import {
  Building2,
  ChevronDown,
  ClipboardList,
  Globe,
  LayoutDashboard,
  Smartphone,
  Stethoscope,
} from 'lucide-react'
import { useState } from 'react'
import { NavLink, useLocation } from 'react-router'
import { cn } from '@/lib/cn'
import {
  getActiveAdminModule,
  type AdminModule,
  type AdminSummaryCounts,
} from './adminPortalContext'

export type { AdminModule, AdminSummaryCounts }

export function AdminSidebar({
  activeModule: propActiveModule,
  counts,
  onSelectModule,
}: {
  activeModule?: AdminModule
  counts: AdminSummaryCounts
  onSelectModule?: (mod: AdminModule) => void
}) {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)
  const location = useLocation()
  const activeModule = propActiveModule ?? getActiveAdminModule(location.pathname)

  const psyBadge = counts.pendingPsyAction ?? counts.pendingMandiri

  const totalAttention =
    psyBadge +
    counts.pendingPartners +
    counts.crisisUsers +
    counts.unassignedRefs

  const navItems = [
    {
      id: 'dashboard' as const,
      path: '/admin/dashboard',
      label: 'Dashboard Utama',
      icon: LayoutDashboard,
      badge: totalAttention,
      badgeColor: 'bg-[#EEF0FF] text-primary',
    },
    {
      id: 'psychologists' as const,
      path: '/admin/psychologists',
      label: 'Psikolog & Relawan',
      icon: Stethoscope,
      badge: psyBadge,
      badgeColor: 'bg-[#FEF3C7] text-[#92400E]',
    },
    {
      id: 'partners' as const,
      path: '/admin/partners',
      label: 'Mitra Faskes',
      icon: Building2,
      badge: counts.pendingPartners,
      badgeColor: 'bg-[#FEF3C7] text-[#92400E]',
    },
    {
      id: 'referrals' as const,
      path: '/admin/referrals',
      label: 'Rujukan Pasien',
      icon: ClipboardList,
      badge: counts.unassignedRefs,
      badgeColor: 'bg-[#FEE2E2] text-[#991B1B]',
    },
    {
      id: 'users_coins' as const,
      path: '/admin/users-coins',
      label: 'Pengguna & Koin',
      icon: Smartphone,
      badge: counts.crisisUsers,
      badgeColor: 'bg-[#FEF3C7] text-[#92400E]',
    },
    {
      id: 'content_config' as const,
      path: '/admin/content-config',
      label: 'Konten Mobile & Website',
      icon: Globe,
      badge: counts.newWaitlist,
      badgeColor: 'bg-[#EEF0FF] text-primary',
    },
  ]

  const currentItem = navItems.find((item) => item.id === activeModule) ?? navItems[0]
  const CurrentIcon = currentItem.icon

  return (
    <>
      {/* 1. Mobile Module Dropdown (Layar < lg, Hemat Ruang) */}
      <div className="relative w-full lg:hidden">
        <button
          type="button"
          onClick={() => setIsMobileMenuOpen((prev) => !prev)}
          className="flex h-11 w-full cursor-pointer items-center justify-between rounded-[12px] border border-[#CBD5E1] bg-white px-3.5 shadow-2xs transition-colors hover:border-primary/50"
        >
          <div className="flex items-center gap-2.5 min-w-0">
            <span className="flex size-7 shrink-0 items-center justify-center rounded-[8px] bg-primary/10 text-primary">
              <CurrentIcon className="size-4" />
            </span>
            <span className="truncate text-xs font-bold text-ink">
              {currentItem.label}
            </span>
            {currentItem.badge > 0 && (
              <span className={cn('shrink-0 rounded-[5px] px-1.5 py-0.5 text-[10px] font-bold', currentItem.badgeColor)}>
                {currentItem.badge}
              </span>
            )}
          </div>
          <ChevronDown className={cn('size-4 text-ink-muted transition-transform duration-200', isMobileMenuOpen && 'rotate-180')} />
        </button>

        {/* Dropdown Menu Popover */}
        {isMobileMenuOpen && (
          <div className="absolute top-12 left-0 z-40 w-full rounded-[12px] border border-[#E2E8F0] bg-white p-2 shadow-xl animate-in fade-in zoom-in-95 duration-150">
            <p className="px-2 py-1 text-[10px] font-bold tracking-wider text-ink-muted uppercase">
              Pilih Modul Admin
            </p>
            <div className="mt-1 space-y-1">
              {navItems.map((item) => {
                const Icon = item.icon
                const isActive = item.id === activeModule
                return (
                  <NavLink
                    key={item.id}
                    to={item.path}
                    onClick={() => {
                      onSelectModule?.(item.id)
                      setIsMobileMenuOpen(false)
                    }}
                    className={cn(
                      'flex w-full cursor-pointer items-center justify-between rounded-[8px] px-3 py-2 text-xs font-semibold transition-colors',
                      isActive ? 'bg-primary text-white' : 'text-ink-soft hover:bg-[#F8FAFC] hover:text-ink',
                    )}
                  >
                    <span className="flex items-center gap-2">
                      <Icon className="size-4 shrink-0" />
                      <span>{item.label}</span>
                    </span>
                    {item.badge > 0 && (
                      <span
                        className={cn(
                          'rounded-[5px] px-1.5 py-0.5 text-[10px] font-bold',
                          isActive ? 'bg-white text-primary' : item.badgeColor,
                        )}
                      >
                        {item.badge}
                      </span>
                    )}
                  </NavLink>
                )
              })}
            </div>
          </div>
        )}
      </div>

      {/* 2. Desktop Sticky Sidebar (Layar >= lg) */}
      <aside className="hidden w-64 shrink-0 rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 lg:sticky lg:top-22 lg:block">
        <p className="px-2.5 text-[11px] font-bold tracking-wider text-ink-muted uppercase">
          Menu Ekosistem EVA
        </p>
        <nav className="mt-2.5 space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon
            const isActive = item.id === activeModule
            return (
              <NavLink
                key={item.id}
                to={item.path}
                onClick={() => onSelectModule?.(item.id)}
                className={cn(
                  'flex w-full cursor-pointer items-center justify-between rounded-[8px] px-3 py-2.5 text-left text-xs font-semibold transition-colors',
                  isActive ? 'bg-primary text-white shadow-2xs' : 'text-ink-soft hover:bg-[#F8FAFC] hover:text-ink',
                )}
              >
                <span className="inline-flex items-center gap-2.5">
                  <Icon className="size-4 shrink-0" />
                  <span>{item.label}</span>
                </span>
                {item.badge > 0 && (
                  <span
                    className={cn(
                      'rounded-[5px] px-1.5 py-0.5 text-[10px] font-bold',
                      isActive ? 'bg-white text-primary' : item.badgeColor,
                    )}
                  >
                    {item.badge}
                  </span>
                )}
              </NavLink>
            )
          })}
        </nav>
      </aside>
    </>
  )
}

