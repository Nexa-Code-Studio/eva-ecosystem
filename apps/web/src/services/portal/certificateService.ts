import { getActivePortalDataSource } from './storage'
import type {
  IssueCertificateRequestDto,
  UpsertCertificateTemplateRequestDto,
} from '@/types/api/contracts'
import type {
  CertificateEvaluationSummary,
  CertificateTemplate,
  CounselorCertificateEligibility,
  IssuedPsychologistCertificate,
} from '@/types/domain/portal'

export async function fetchCertificateTemplates(): Promise<CertificateTemplate[]> {
  return getActivePortalDataSource().fetchCertificateTemplates()
}

export async function upsertCertificateTemplate(
  input: UpsertCertificateTemplateRequestDto,
): Promise<CertificateTemplate> {
  return getActivePortalDataSource().upsertCertificateTemplate(input)
}

export async function toggleCertificateTemplateActive(
  templateId: string,
): Promise<CertificateTemplate> {
  return getActivePortalDataSource().toggleCertificateTemplateActive(templateId)
}

export async function fetchIssuedCertificates(): Promise<IssuedPsychologistCertificate[]> {
  return getActivePortalDataSource().fetchIssuedCertificates()
}

export async function fetchEligibleCounselorsForCertificates(): Promise<
  CounselorCertificateEligibility[]
> {
  return getActivePortalDataSource().fetchEligibleCounselorsForCertificates()
}

export async function issueCertificateManual(
  payload: IssueCertificateRequestDto,
): Promise<IssuedPsychologistCertificate> {
  return getActivePortalDataSource().issueCertificateManual(payload)
}

export async function evaluateAutoCertificates(): Promise<CertificateEvaluationSummary> {
  return getActivePortalDataSource().evaluateAutoCertificates()
}

export async function revokeCertificate(
  certificateId: string,
  reason: string,
): Promise<IssuedPsychologistCertificate> {
  return getActivePortalDataSource().revokeCertificate(certificateId, reason)
}

export async function downloadCertificatePdf(
  certificateId: string,
): Promise<{ blob: Blob; filename: string }> {
  return getActivePortalDataSource().downloadCertificatePdf(certificateId)
}
