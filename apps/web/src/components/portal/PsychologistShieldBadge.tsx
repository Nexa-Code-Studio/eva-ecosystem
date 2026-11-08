import {
  Building2,
  CheckCircle2,
  GraduationCap,
  HeartHandshake,
} from 'lucide-react'
import { useState, useRef, useEffect } from 'react'
import { createPortal } from 'react-dom'
import { cn } from '@/lib/cn'
import type { PsychologistRole, UpgradeRequest } from '@/types/portal'

export interface PsychologistShieldBadgeProps {
  role?: PsychologistRole
  partnerName?: string | null
  upgradeRequest?: UpgradeRequest | null
  size?: 'sm' | 'md'
  className?: string
}

interface MedallionInfo {
  icon: typeof Building2
  label: string
  bgClass: string
  borderClass: string
  shadowClass?: string
}

export function PsychologistShieldBadge({
  role,
  partnerName,
  upgradeRequest,
  size = 'md',
  className,
}: PsychologistShieldBadgeProps) {
  const [isOpen, setIsOpen] = useState(false)
  const [coords, setCoords] = useState<{ top: number; left: number; placeAbove: boolean } | null>(
    null,
  )
  const triggerRef = useRef<HTMLButtonElement>(null)
  const tooltipRef = useRef<HTMLDivElement>(null)

  // Resolve role config with intelligent fallbacks
  let effectiveRole = role
  if (!effectiveRole) {
    if (partnerName) {
      effectiveRole = 'professional_mitra'
    } else {
      effectiveRole = 'relawan_profesional'
    }
  }

  const isMitra = effectiveRole === 'professional_mitra'
  const isRelawanProf = effectiveRole === 'relawan_profesional'

  // Define Primary Base Medallion (Mitra or Relawan)
  const baseMedallion: MedallionInfo = isMitra
    ? {
        icon: Building2,
        label: 'Profesional Mitra',
        bgClass: 'bg-emerald-600',
        borderClass: 'border-emerald-700',
        shadowClass: 'shadow-emerald-900/20',
      }
    : {
        icon: HeartHandshake,
        label: 'Relawan',
        bgClass: 'bg-sky-500',
        borderClass: 'border-sky-600',
        shadowClass: 'shadow-sky-900/20',
      }

  // Define Secondary / Tier Medallion (Profesional for Relawan)
  let tierMedallion: MedallionInfo | null = null
  if (isRelawanProf) {
    tierMedallion = {
      icon: GraduationCap,
      label: 'Tingkat Profesional (S2 & SIPP)',
      bgClass: 'bg-gradient-to-br from-indigo-500 to-indigo-700',
      borderClass: 'border-indigo-800',
      shadowClass: 'shadow-indigo-900/25',
    }
  }

  // Position calculation
  const updatePosition = () => {
    if (!triggerRef.current) return
    const rect = triggerRef.current.getBoundingClientRect()
    const spaceBelow = window.innerHeight - rect.bottom
    const placeAbove = spaceBelow < 250 && rect.top > 250

    setCoords({
      top: placeAbove ? rect.top - 8 : rect.bottom + 8,
      left: Math.max(16, Math.min(window.innerWidth - 320, rect.left + rect.width / 2 - 150)),
      placeAbove,
    })
  }

  const handleOpen = () => {
    updatePosition()
    setIsOpen(true)
  }

  const handleClose = () => {
    setIsOpen(false)
  }

  const handleToggle = (e: React.MouseEvent) => {
    e.stopPropagation()
    if (!isOpen) {
      updatePosition()
      setIsOpen(true)
    } else {
      setIsOpen(false)
    }
  }

  useEffect(() => {
    if (!isOpen) return
    const onScrollOrResize = () => setIsOpen(false)
    const onDocClick = (e: MouseEvent | TouchEvent) => {
      const target = e.target as Node
      if (triggerRef.current?.contains(target) || tooltipRef.current?.contains(target)) {
        return
      }
      setIsOpen(false)
    }

    document.addEventListener('mousedown', onDocClick)
    document.addEventListener('touchstart', onDocClick)
    window.addEventListener('scroll', onScrollOrResize, true)
    window.addEventListener('resize', onScrollOrResize)

    return () => {
      document.removeEventListener('mousedown', onDocClick)
      document.removeEventListener('touchstart', onDocClick)
      window.removeEventListener('scroll', onScrollOrResize, true)
      window.removeEventListener('resize', onScrollOrResize)
    }
  }, [isOpen])

  const coinSizeClass = size === 'sm' ? 'size-[18px]' : 'size-[22px]'
  const glyphSizeClass = size === 'sm' ? 'size-2.5' : 'size-3'
  const BaseIcon = baseMedallion.icon
  const TierIcon = tierMedallion?.icon

  return (
    <span className={cn('relative inline-flex items-center align-middle', className)}>
      <button
        ref={triggerRef}
        type="button"
        aria-label={`Lencana peran: ${baseMedallion.label}${tierMedallion ? ` + ${tierMedallion.label}` : ''}. Klik untuk melihat penjelasan kualifikasi.`}
        aria-expanded={isOpen}
        onClick={handleToggle}
        onMouseEnter={handleOpen}
        onMouseLeave={handleClose}
        onFocus={handleOpen}
        onBlur={handleClose}
        className="group relative inline-flex cursor-pointer items-center p-0.5 focus:outline-none"
      >
        {/* Medallion Stack Container with smooth hover expand */}
        <div className="relative inline-flex items-center">
          {/* 1. Base Medallion (Relawan / Mitra) */}
          <span
            title={baseMedallion.label}
            className={cn(
              'relative z-10 flex shrink-0 items-center justify-center rounded-full text-white ring-2 ring-white shadow-xs transition-transform duration-200 ease-out',
              coinSizeClass,
              baseMedallion.bgClass,
              baseMedallion.borderClass,
              tierMedallion && 'group-hover:-translate-x-0.5',
            )}
          >
            <BaseIcon className={cn(glyphSizeClass, 'stroke-[2.5]')} />
          </span>

          {/* 2. Tier Medallion (Utama / Profesional) - Overlaps base medallion and slides out on hover */}
          {tierMedallion && TierIcon && (
            <span
              title={tierMedallion.label}
              className={cn(
                'relative z-20 -ml-2 flex shrink-0 items-center justify-center rounded-full text-white ring-2 ring-white shadow-xs transition-all duration-200 ease-out',
                coinSizeClass,
                tierMedallion.bgClass,
                tierMedallion.borderClass,
                'group-hover:ml-0.5 group-hover:scale-105',
              )}
            >
              <TierIcon className={cn(glyphSizeClass, 'stroke-[2.5]')} />
            </span>
          )}
        </div>
      </button>

      {/* Floating Rich Tooltip via React Portal */}
      {isOpen &&
        coords &&
        typeof document !== 'undefined' &&
        createPortal(
          <div
            ref={tooltipRef}
            role="tooltip"
            style={{
              position: 'fixed',
              top: coords.placeAbove ? 'auto' : `${coords.top}px`,
              bottom: coords.placeAbove ? `${window.innerHeight - coords.top}px` : 'auto',
              left: `${coords.left}px`,
              width: '304px',
            }}
            onClick={(e) => e.stopPropagation()}
            className="z-70 animate-in fade-in-0 zoom-in-95 duration-150 rounded-[12px] border border-[#CBD5E1] bg-white p-3.5 shadow-xl"
          >
            {/* Header: Visual Stack Representation + Full Title */}
            <div className="flex items-start gap-2.5 border-b border-[#F1F5F9] pb-3">
              {/* Stack Preview */}
              <div className="flex items-center pt-0.5">
                <span
                  className={cn(
                    'flex size-6 shrink-0 items-center justify-center rounded-full text-white ring-2 ring-white shadow-2xs',
                    baseMedallion.bgClass,
                  )}
                >
                  <BaseIcon className="size-3.5 stroke-[2.5]" />
                </span>
                {tierMedallion && TierIcon && (
                  <span
                    className={cn(
                      'ml-1 flex size-6 shrink-0 items-center justify-center rounded-full text-white ring-2 ring-white shadow-2xs',
                      tierMedallion.bgClass,
                    )}
                  >
                    <TierIcon className="size-3.5 stroke-[2.5]" />
                  </span>
                )}
              </div>

              {/* Title & Badges */}
              <div className="min-w-0 flex-1">
                <h4 className="text-xs font-bold text-ink">
                  {isMitra
                    ? 'Profesional Mitra'
                    : isRelawanProf
                      ? 'Relawan • Tingkat Profesional'
                      : 'Relawan Pendamping'}
                </h4>
                <div className="mt-1 flex flex-wrap items-center gap-1">
                  <span className="inline-flex rounded-[4px] bg-[#F1F5F9] px-1.5 py-0.5 text-[9.5px] font-semibold text-ink-muted">
                    {baseMedallion.label}
                  </span>
                  {tierMedallion && (
                    <span className="inline-flex items-center gap-0.5 rounded-[4px] bg-indigo-100 px-1.5 py-0.5 text-[9.5px] font-bold text-indigo-900">
                      {tierMedallion.label}
                    </span>
                  )}
                </div>
              </div>
            </div>

            {/* Layer Breakdown Content */}
            <div className="mt-2.5 space-y-2 text-[11px]">
              {/* 1. Base Layer */}
              <div className="flex items-start gap-2">
                <span
                  className={cn(
                    'mt-0.5 flex size-4 shrink-0 items-center justify-center rounded-full text-white text-[9px]',
                    baseMedallion.bgClass,
                  )}
                >
                  1
                </span>
                <div className="min-w-0 flex-1">
                  <span className="font-semibold text-ink">{baseMedallion.label}</span>
                  <p className="text-[10.5px] text-ink-muted leading-relaxed">
                    {isMitra
                      ? partnerName
                        ? `Terafiliasi resmi dengan faskes mitra ${partnerName}.`
                        : 'Psikolog resmi faskes mitra EVA.'
                      : 'Mahasiswa atau praktisi kesehatan mental dengan sertifikasi konseling sebaya.'}
                  </p>
                </div>
              </div>

              {/* 2. Tier Layer (If applicable) */}
              {tierMedallion && (
                <div className="flex items-start gap-2 border-t border-[#F1F5F9] pt-2">
                  <span
                    className={cn(
                      'mt-0.5 flex size-4 shrink-0 items-center justify-center rounded-full text-white text-[9px]',
                      tierMedallion.bgClass,
                    )}
                  >
                    2
                  </span>
                  <div className="min-w-0 flex-1">
                    <span className="font-semibold text-ink">
                      {tierMedallion.label}
                    </span>
                    <p className="text-[10.5px] text-ink-muted leading-relaxed">
                      Lulusan Magister Profesi Psikologi (S2) dengan izin praktik SIPP dan STR aktif.
                    </p>
                  </div>
                </div>
              )}
            </div>

            {/* Perks Summary */}
            <div className="mt-2.5 rounded-[8px] border border-[#F1F5F9] bg-[#F8FAFC] p-2 text-[10.5px]">
              <div className="flex items-center gap-1 font-semibold text-ink">
                <CheckCircle2 className="size-3 text-emerald-600" />
                <span>Akses &amp; Ketentuan Layanan:</span>
              </div>
              <p className="mt-0.5 text-ink-muted leading-relaxed">
                {isMitra
                  ? 'Layanan konseling faskes, integrasi rekam medis, dan rujukan klinis.'
                  : isRelawanProf
                    ? 'Layanan konseling psikologi profesional berizin resmi serta supervisi relawan.'
                    : 'Pendampingan sebaya awal (Psychological First Aid) dan memenuhi syarat mengajukan upgrade.'}
              </p>
            </div>

            {/* Active Upgrade Notice */}
            {upgradeRequest && (
              <div className="mt-2 rounded-[6px] border border-amber-300 bg-amber-50 p-2 text-[10.5px] text-amber-900">
                <span className="font-bold">Pengajuan Upgrade:</span> Menunggu verifikasi ke{' '}
                <strong>Relawan Profesional</strong> ({upgradeRequest.requestedAt}).
              </div>
            )}
          </div>,
          document.body,
        )}
    </span>
  )
}

export { PsychologistShieldBadge as PsychologistMedallionBadge }
