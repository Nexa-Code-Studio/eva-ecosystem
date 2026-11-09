import { useSearchParams } from 'react-router'
import { cn } from '@/lib/cn'
import type { PortalDatabase } from '@/types/portal'
import { AdminMobileContentTab } from './AdminMobileContentTab'
import { AdminCoinPackagesConfigTab } from './AdminCoinPackagesConfigTab'
import { AdminWebsiteContentTab } from './AdminWebsiteContentTab'

interface AdminContentConfigModuleProps {
  db: PortalDatabase
  onFeedback: (message: string) => void
}

export type CmsSubTab = 'mobile' | 'coins_catalog' | 'website'

export function AdminContentConfigModule({ db, onFeedback }: AdminContentConfigModuleProps) {
  const [searchParams, setSearchParams] = useSearchParams()
  const tabParam = searchParams.get('tab') as CmsSubTab | null
  const cmsSubTab: CmsSubTab =
    tabParam === 'coins_catalog' || tabParam === 'website' ? tabParam : 'mobile'

  const handleSubTabChange = (tab: CmsSubTab) => {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      if (tab === 'mobile') {
        next.delete('tab')
      } else {
        next.set('tab', tab)
      }
      return next
    })
  }

  return (
    <div>
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
        <div>
          <h1 className="text-xl font-bold tracking-[-0.02em] text-ink sm:text-2xl">
            Konten Aplikasi Mobile &amp; Operasional Website
          </h1>
          <p className="mt-0.5 text-xs text-ink-muted">
            Kelola Misi Koping Harian, Hotline Krisis SafetyNet, Kurs &amp; Katalog Paket Koin Suara, serta Waitlist &amp; FAQ Website.
          </p>
        </div>

        <div className="inline-flex flex-wrap rounded-[8px] border border-[#E2E8F0] bg-white p-1">
          <button
            type="button"
            onClick={() => handleSubTabChange('mobile')}
            className={cn(
              'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
              cmsSubTab === 'mobile'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            Misi Koping &amp; Krisis (Mobile)
          </button>
          <button
            type="button"
            onClick={() => handleSubTabChange('coins_catalog')}
            className={cn(
              'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
              cmsSubTab === 'coins_catalog'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            Kurs &amp; Paket Koin ({db.coinPackages.filter((pkg) => pkg.isActive).length})
          </button>
          <button
            type="button"
            onClick={() => handleSubTabChange('website')}
            className={cn(
              'cursor-pointer rounded-[6px] px-3 py-1.5 text-xs font-semibold transition-colors',
              cmsSubTab === 'website'
                ? 'bg-primary text-white'
                : 'text-ink-soft hover:text-ink',
            )}
          >
            Waitlist &amp; FAQ (Website)
          </button>
        </div>
      </div>

      {cmsSubTab === 'mobile' ? (
        <AdminMobileContentTab db={db} onFeedback={onFeedback} />
      ) : cmsSubTab === 'coins_catalog' ? (
        <AdminCoinPackagesConfigTab db={db} onFeedback={onFeedback} />
      ) : (
        <AdminWebsiteContentTab db={db} onFeedback={onFeedback} />
      )}
    </div>
  )
}
