import {
  Building2,
  ClipboardList,
  Stethoscope,
} from 'lucide-react'
import { useEffect } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router'
import { PortalFeedbackBanner, PortalTopbar } from '@/components/portal/PortalTopbar'
import { PartnerProfileTab } from '@/components/portal/partner/PartnerProfileTab'
import { PartnerPsychologistsTab } from '@/components/portal/partner/PartnerPsychologistsTab'
import { PartnerReferralsTab } from '@/components/portal/partner/PartnerReferralsTab'
import { PsychologistFormModal } from '@/components/portal/partner/PsychologistFormModal'
import { usePartnerDashboard } from '@/hooks/usePartnerDashboard'
import { usePartnerOutletContext } from '@/hooks/usePartnerOutletContext'
import { cn } from '@/lib/cn'
import {
  assignReferral,
  deletePsychologist,
  setPortalSession,
  updatePsychologistStatus,
  type ReferralStatus,
} from '@/lib/portalStore'

export function PartnerDashboardPage() {
  const navigate = useNavigate()
  const state = usePartnerDashboard()

  useEffect(() => {
    window.scrollTo(0, 0)
  }, [])

  if (!state.partner) return null

  const { partner, psychologists, referrals } = state
  const unassignedReferrals = referrals.filter((r) => r.status === 'unassigned').length

  return (
    <div className="min-h-[100dvh] bg-[#F8F9FE] text-ink">
      <PortalTopbar
        maxWidthClass="max-w-[1440px]"
        badgeLabel="Portal Mitra Faskes"
        title={partner.facilityName}
        subtitle={`${partner.facilityType} · ${partner.city}`}
        onLogout={() => {
          setPortalSession(null)
          navigate('/login')
        }}
      />

      <main className="mx-auto max-w-[1440px] px-4 py-6 sm:px-6 sm:py-8 lg:px-8">
        {/* 1. Header Faskes Ringkas & Switch Penerimaan Rujukan Cepat */}
        <div className="flex flex-col gap-3 rounded-[14px] border border-[#E2E8F0] bg-white p-4 sm:flex-row sm:items-center sm:justify-between sm:p-5 shadow-2xs">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="rounded-[6px] bg-primary/10 px-2.5 py-0.5 text-xs font-bold text-primary">
                {partner.facilityType}
              </span>
              <span className="text-xs text-ink-muted">·</span>
              <span className="text-xs font-medium text-ink-muted">{partner.city}</span>
            </div>
            <h1 className="mt-1 text-lg sm:text-xl font-bold tracking-tight text-ink">
              {partner.facilityName}
            </h1>
          </div>

          <div className="flex items-center gap-2 self-start sm:self-auto">
            <button
              type="button"
              onClick={state.handleToggleAcceptingReferrals}
              title="Klik untuk mengubah status penerimaan rujukan pasien baru"
              className={cn(
                'inline-flex h-9 items-center gap-2 rounded-[8px] border px-3 text-xs font-semibold transition-all cursor-pointer shadow-2xs active:scale-[0.98]',
                partner.acceptingReferrals
                  ? 'border-emerald-300 bg-emerald-50 text-emerald-800 hover:bg-emerald-100'
                  : 'border-[#CBD5E1] bg-slate-100 text-slate-700 hover:bg-slate-200',
              )}
            >
              <span
                className={cn(
                  'size-2 shrink-0 rounded-full',
                  partner.acceptingReferrals ? 'bg-emerald-600 ring-2 ring-emerald-200' : 'bg-slate-400',
                )}
              />
              <span>
                {partner.acceptingReferrals ? 'Menerima Rujukan Pasien' : 'Penerimaan Rujukan Dijeda'}
              </span>
            </button>
          </div>
        </div>

        <PortalFeedbackBanner
          message={state.banner}
          onClose={() => state.setBanner(null)}
          variant="primary"
        />

        <div
          className="mt-6 flex flex-wrap items-center gap-2 border-b border-[#E2E8F0] pb-3"
          role="tablist"
        >
          {/* 1. Tab Rujukan Pasien (Triage-First: Paling Kiri) */}
          <NavLink
            to="/mitra/referrals"
            className={({ isActive }) =>
              cn(
                'inline-flex h-10 cursor-pointer items-center gap-2 rounded-[8px] px-4 text-xs font-semibold transition-colors',
                isActive
                  ? 'bg-primary text-white'
                  : 'border border-[#E2E8F0] bg-white text-ink-soft hover:text-ink',
              )
            }
          >
            {({ isActive }) => (
              <>
                <ClipboardList className="size-4" />
                <span>Rujukan Pasien EVA ({referrals.length})</span>
                {unassignedReferrals > 0 && (
                  <span
                    className={cn(
                      'rounded-full px-2 py-0.5 text-[10px] font-bold shadow-2xs',
                      isActive ? 'bg-amber-300 text-amber-950' : 'bg-amber-100 text-amber-900 border border-amber-300/80',
                    )}
                  >
                    {unassignedReferrals} butuh tindakan
                  </span>
                )}
              </>
            )}
          </NavLink>

          {/* 2. Tab Manajemen Psikolog */}
          <NavLink
            to="/mitra/psychologists"
            className={({ isActive }) =>
              cn(
                'inline-flex h-10 cursor-pointer items-center gap-2 rounded-[8px] px-4 text-xs font-semibold transition-colors',
                isActive
                  ? 'bg-primary text-white'
                  : 'border border-[#E2E8F0] bg-white text-ink-soft hover:text-ink',
              )
            }
          >
            <Stethoscope className="size-4" />
            <span>Manajemen Psikolog ({psychologists.length})</span>
          </NavLink>

          {/* 3. Tab Profil Faskes */}
          <NavLink
            to="/mitra/profile"
            className={({ isActive }) =>
              cn(
                'inline-flex h-10 cursor-pointer items-center gap-2 rounded-[8px] px-4 text-xs font-semibold transition-colors',
                isActive
                  ? 'bg-primary text-white'
                  : 'border border-[#E2E8F0] bg-white text-ink-soft hover:text-ink',
              )
            }
          >
            <Building2 className="size-4" />
            <span>Profil &amp; Operasional Faskes</span>
          </NavLink>
        </div>

        <Outlet context={state} />
      </main>

      <PsychologistFormModal
        isOpen={state.modalOpen}
        editingPsy={state.editingPsy}
        fullName={state.fullName}
        sippNumber={state.sippNumber}
        selectedSpecs={state.selectedSpecs}
        practiceSchedule={state.practiceSchedule}
        psyStatus={state.psyStatus}
        weeklyQuota={state.weeklyQuota}
        yearsExperience={state.yearsExperience}
        education={state.education}
        sessionDurationMinutes={state.sessionDurationMinutes}
        sessionFeeCoins={state.sessionFeeCoins}
        errors={state.psyErrors}
        onClose={() => state.setModalOpen(false)}
        onSubmit={state.handleSavePsychologist}
        onFullNameChange={(val) => {
          state.setFullName(val)
          if (state.psyErrors.fullName) state.setPsyErrors((p) => ({ ...p, fullName: '' }))
        }}
        onSippNumberChange={(val) => {
          state.setSippNumber(val)
          if (state.psyErrors.sippNumber) state.setPsyErrors((p) => ({ ...p, sippNumber: '' }))
        }}
        onToggleSpec={state.toggleSpecialization}
        onPracticeScheduleChange={(val) => {
          state.setPracticeSchedule(val)
          if (state.psyErrors.practiceSchedule)
            state.setPsyErrors((p) => ({ ...p, practiceSchedule: '' }))
        }}
        onStatusChange={state.setPsyStatus}
        onWeeklyQuotaChange={state.setWeeklyQuota}
        onYearsExperienceChange={state.setYearsExperience}
        onEducationChange={state.setEducation}
        onDurationChange={state.setSessionDurationMinutes}
        onFeeCoinsChange={(val) => {
          state.setSessionFeeCoins(val)
          if (state.psyErrors.sessionFeeCoins)
            state.setPsyErrors((p) => ({ ...p, sessionFeeCoins: '' }))
        }}
      />
    </div>
  )
}

// Child Route Components for Mitra
export function PartnerPsychologistsRoute() {
  const state = usePartnerOutletContext()
  return (
    <PartnerPsychologistsTab
      psychologists={state.filteredPsychologists}
      psySearch={state.psySearch}
      psyStatusFilter={state.psyStatusFilter}
      psyCounts={state.psyCounts}
      onSearchChange={state.setPsySearch}
      onFilterChange={state.setPsyStatusFilter}
      onOpenAddModal={state.openAddModal}
      onOpenEditModal={state.openEditModal}
      onDeletePsychologist={(psy) => {
        deletePsychologist(psy.id)
        state.setBanner(`Data psikolog "${psy.fullName}" telah dihapus dari daftar faskes.`)
      }}
      onStatusChange={updatePsychologistStatus}
    />
  )
}

export function PartnerReferralsRoute() {
  const state = usePartnerOutletContext()
  return (
    <PartnerReferralsTab
      referrals={state.referrals}
      psychologists={state.psychologists}
      onAssignReferral={(refId, psyId, status: ReferralStatus, patientCode) => {
        assignReferral(refId, psyId, status)
        state.setBanner(`Penugasan psikolog untuk rujukan ${patientCode} diperbarui.`)
      }}
    />
  )
}

export function PartnerProfileRoute() {
  const state = usePartnerOutletContext()
  return (
    <PartnerProfileTab
      profFacilityName={state.profFacilityName}
      profFacilityType={state.profFacilityType}
      profLicense={state.profLicense}
      profCity={state.profCity}
      profPhone={state.profPhone}
      profAddress={state.profAddress}
      profPicName={state.profPicName}
      profPicRole={state.profPicRole}
      profOperatingHours={state.profOperatingHours}
      profWebsite={state.profWebsite}
      profAccepting={state.profAccepting}
      profBpjs={state.profBpjs}
      profNotes={state.profNotes}
      onSaveProfile={state.handleSaveProfile}
      onFacilityNameChange={state.setProfFacilityName}
      onFacilityTypeChange={state.setProfFacilityType}
      onLicenseChange={state.setProfLicense}
      onCityChange={state.setProfCity}
      onPhoneChange={state.setProfPhone}
      onAddressChange={state.setProfAddress}
      onPicNameChange={state.setProfPicName}
      onPicRoleChange={state.setProfPicRole}
      onOperatingHoursChange={state.setProfOperatingHours}
      onWebsiteChange={state.setProfWebsite}
      onAcceptingChange={state.setProfAccepting}
      onBpjsChange={state.setProfBpjs}
      onNotesChange={state.setProfNotes}
    />
  )
}
