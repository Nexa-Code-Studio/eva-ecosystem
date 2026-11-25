import { getActivePortalDataSource } from './storage'
import type {
  BoothFeedbackListResult,
  SubmitBoothFeedbackPayload,
  SubmitBoothFeedbackResult,
} from '@/types/domain/portal'

export async function submitBoothFeedback(
  payload: SubmitBoothFeedbackPayload,
): Promise<SubmitBoothFeedbackResult> {
  return getActivePortalDataSource().submitBoothFeedback(payload)
}

export async function fetchAdminBoothFeedbacks(params?: {
  rating?: number
  search?: string
  page?: number
  pageSize?: number
}): Promise<BoothFeedbackListResult> {
  return getActivePortalDataSource().fetchAdminBoothFeedbacks(params)
}

export async function fetchAdminBoothFeedbackPhotoUrl(
  feedbackId: string,
  photoId: string,
): Promise<string> {
  return getActivePortalDataSource().fetchAdminBoothFeedbackPhotoUrl(feedbackId, photoId)
}

export async function deleteAdminBoothFeedback(feedbackId: string): Promise<void> {
  return getActivePortalDataSource().deleteAdminBoothFeedback(feedbackId)
}
