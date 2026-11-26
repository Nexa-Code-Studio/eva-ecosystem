import type { BackendAdminBoothFeedbackListDto } from '../../types/api/contracts.ts'
import type {
  BoothFeedbackEntry,
  BoothFeedbackListResult,
  BoothVisitorRole,
} from '../../types/domain/portal.ts'

function normalizeBoothVisitorRole(raw?: string | null): BoothVisitorRole {
  return raw === 'counselor' ? 'counselor' : 'user'
}

export function mapBackendAdminBoothFeedbackListToDomain(
  dto: BackendAdminBoothFeedbackListDto,
): BoothFeedbackListResult {
  const counts: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
  for (const score of [1, 2, 3, 4, 5]) {
    counts[score] = Number(dto.summary.rating_counts?.[String(score)] ?? 0)
  }

  const items: BoothFeedbackEntry[] = dto.items.map((item) => ({
    id: item.id,
    rating: item.rating,
    usageLikelihood: item.usage_likelihood ?? 3,
    recommendationScore: item.recommendation_score ?? 3,
    visitorRole: normalizeBoothVisitorRole(item.visitor_role),
    message: item.message,
    visitorName: item.visitor_name ?? null,
    visitorContact: item.visitor_contact ?? null,
    eventLabel: item.event_label || 'Event Booth EVA',
    photos: item.photos.map((p) => ({
      id: p.id,
      mimeType: p.mime_type,
      fileSizeBytes: p.file_size_bytes,
      sortOrder: p.sort_order,
      createdAt: p.created_at,
    })),
    createdAt: item.created_at,
  }))

  return {
    summary: {
      totalCount: dto.summary.total_count,
      averageRating: dto.summary.average_rating,
      ratingCounts: counts,
      roleCounts: {
        user: Number(dto.summary.role_counts?.user ?? 0),
        counselor: Number(dto.summary.role_counts?.counselor ?? 0),
      },
      averageUsageLikelihood: Number(dto.summary.average_usage_likelihood ?? 0),
      highUsageIntentCount: Number(dto.summary.high_usage_intent_count ?? 0),
      highUsageIntentPercentage: Number(dto.summary.high_usage_intent_percentage ?? 0),
      averageRecommendationScore: Number(dto.summary.average_recommendation_score ?? 0),
      promoterCount: Number(dto.summary.promoter_count ?? 0),
      promoterPercentage: Number(dto.summary.promoter_percentage ?? 0),
    },
    items,
    total: dto.total,
    page: dto.page,
    pageSize: dto.page_size,
  }
}
