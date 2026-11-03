import { Building2, ClipboardList, Stethoscope } from 'lucide-react'
import { useEffect } from 'react'
import { useNavigate } from 'react-router'
import { PortalFeedbackBanner, PortalTopbar } from '@/components/portal/PortalTopbar'
import { PartnerProfileTab } from '@/components/portal/partner/PartnerProfileTab'
import { PartnerPsychologistsTab } from '@/components/portal/partner/PartnerPsychologistsTab'
import { PartnerReferralsTab } from '@/components/portal/partner/PartnerReferralsTab'
import { PsychologistFormModal } from '@/components/portal/partner/PsychologistFormModal'
import { usePartnerDashboard } from '@/hooks/usePartnerDashboard'
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
  const activeCount = psychologists.filter((p) => p.status === 'active').length
  const leaveCount = psychologists.filter((p) => p.status === 'on_leave').length
  const unassignedReferrals = referrals.filter((r) => r.status === 'unassigned').length

  return (
    <div className="min-h-[100dvh] bg-[#F8F9FE] text-ink">
      <PortalTopbar
        badgeLabel="Portal Mitra Faskes"
        title={partner.facilityName}
        subtitle={`${partner.facilityType} · ${partner.city}`}
        onLogout={() => {
          setPortalSession(null)
          navigate('/login')
        }}
      />

      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-col justify-between gap-4 rounded-[12px] border border-[#E2E8F0] bg-white p-5 sm:flex-row sm:items-center">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="rounded-[5px] bg-primary-container px-2 py-0.5 text-xs font-semibold text-primary">
                {partner.facilityType}
              </span>
              <span className="text-xs text-ink-muted">Izin: {partner.licenseNumber}</span>
              <span
                className={cn(
                  'inline-flex items-center gap-1 rounded-[5px] px-2 py-0.5 text-xs font-semibold',
                  partner.acceptingReferrals
                    ? 'bg-success/10 text-success'
                    : 'bg-[#F1F5F9] text-ink-muted',
                )}
              >
                {partner.acceptingReferrals
                  ? '● Menerima Rujukan Pasien EVA'
                  : '○ Rujukan Baru Dijeda'}
              </span>
            </div>
            <h1 className="mt-1.5 text-xl font-semibold tracking-[-0.015em] text-ink">
              {partner.facilityName}
            </h1>
            <p className="mt-0.5 text-xs text-ink-soft">
              PIC: {partner.picName} ({partner.picRole}) · {partner.address}
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3 text-xs">
            <div className="rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] px-3.5 py-2 text-center">
              <p className="text-lg font-bold text-ink">{activeCount}</p>
              <p className="text-[11px] text-ink-soft">Psikolog Aktif</p>
            </div>
            <div className="rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] px-3.5 py-2 text-center">
              <p className="text-lg font-bold text-ink">{leaveCount}</p>
              <p className="text-[11px] text-ink-soft">Sedang Cuti</p>
            </div>
            <div className="rounded-[8px] border border-[#E2E8F0] bg-[#F8FAFC] px-3.5 py-2 text-center">
              <p className="text-lg font-bold text-primary">{unassignedReferrals}</p>
              <p className="text-[11px] text-ink-soft">Rujukan Baru</p>
            </div>
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
          <button
            type="button"
            role="tab"
            aria-selected={state.activeTab === 'psychologists'}
            onClick={() => state.setActiveTab('psychologists')}
            className={cn(
              'inline-flex h-10 cursor-pointer items-center gap-2 rounded-[8px] px-4 text-xs font-semibold transition-colors',
              state.activeTab === 'psychologists'
                ? 'bg-primary text-white'
                : 'border border-[#E2E8F0] bg-white text-ink-soft hover:text-ink',
            )}
          >
            <Stethoscope className="size-4" />
            <span>Manajemen Psikolog ({psychologists.length})</span>
          </button>

          <button
            type="button"
            role="tab"
            aria-selected={state.activeTab === 'referrals'}
            onClick={() => state.setActiveTab('referrals')}
            className={cn(
              'inline-flex h-10 cursor-pointer items-center gap-2 rounded-[8px] px-4 text-xs font-semibold transition-colors',
              state.activeTab === 'referrals'
                ? 'bg-primary text-white'
                : 'border border-[#E2E8F0] bg-white text-ink-soft hover:text-ink',
            )}
          >
            <ClipboardList className="size-4" />
            <span>Rujukan Pasien EVA ({referrals.length})</span>
            {unassignedReferrals > 0 && (
              <span
                className={cn(
                  'rounded-full px-1.5 py-0.5 text-[10px] font-bold',
                  state.activeTab === 'referrals'
                    ? 'bg-white text-primary'
                    : 'bg-primary text-white',
                )}
              >
                {unassignedReferrals} baru
              </span>
            )}
          </button>

          <button
            type="button"
            role="tab"
            aria-selected={state.activeTab === 'profile'}
            onClick={() => state.setActiveTab('profile')}
            className={cn(
              'inline-flex h-10 cursor-pointer items-center gap-2 rounded-[8px] px-4 text-xs font-semibold transition-colors',
              state.activeTab === 'profile'
                ? 'bg-primary text-white'
                : 'border border-[#E2E8F0] bg-white text-ink-soft hover:text-ink',
            )}
          >
            <Building2 className="size-4" />
            <span>Profil &amp; Operasional Faskes</span>
          </button>
        </div>

        {state.activeTab === 'psychologists' && (
          <PartnerPsychologistsTab
            psychologists={state.filteredPsychologists}
            psySearch={state.psySearch}
            psyStatusFilter={state.psyStatusFilter}
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
        )}

        {state.activeTab === 'referrals' && (
          <PartnerReferralsTab
            referrals={referrals}
            psychologists={psychologists}
            onAssignReferral={(refId, psyId, status: ReferralStatus, patientCode) => {
              assignReferral(refId, psyId, status)
              state.setBanner(`Penugasan psikolog untuk rujukan ${patientCode} diperbarui.`)
            }}
          />
        )}

        {state.activeTab === 'profile' && (
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
        )}
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
      />
    </div>
  )
}
