import assert from 'node:assert/strict'
import test from 'node:test'
import { mapBackendAdminBoothFeedbackListToDomain } from '../../src/services/contracts/boothFeedbackMappers.ts'

test('mapBackendAdminBoothFeedbackListToDomain maps usageLikelihood, recommendationScore, and KPI summary fields', () => {
  const result = mapBackendAdminBoothFeedbackListToDomain({
    summary: {
      total_count: 4,
      average_rating: 4.5,
      rating_counts: { '1': 0, '2': 0, '3': 0, '4': 2, '5': 2 },
      role_counts: { user: 3, counselor: 1 },
      average_usage_likelihood: 4.25,
      high_usage_intent_count: 3,
      high_usage_intent_percentage: 75.0,
      average_recommendation_score: 4.75,
      promoter_count: 4,
      promoter_percentage: 100.0,
    },
    items: [
      {
        id: 'bf-1',
        rating: 5,
        usage_likelihood: 4,
        recommendation_score: 5,
        visitor_role: 'counselor',
        message: 'Sangat membantu saat dicoba langsung di booth.',
        visitor_name: 'Nadia',
        visitor_contact: '@nadia.id',
        event_label: 'Event Booth EVA',
        photos: [],
        created_at: '2026-11-26T10:00:00Z',
      },
    ],
    total: 4,
    page: 1,
    page_size: 10,
  })

  assert.equal(result.summary.roleCounts.user, 3)
  assert.equal(result.summary.roleCounts.counselor, 1)
  assert.equal(result.summary.averageUsageLikelihood, 4.25)
  assert.equal(result.summary.highUsageIntentCount, 3)
  assert.equal(result.summary.highUsageIntentPercentage, 75.0)
  assert.equal(result.summary.averageRecommendationScore, 4.75)
  assert.equal(result.summary.promoterCount, 4)
  assert.equal(result.summary.promoterPercentage, 100.0)
  assert.equal(result.items[0]?.usageLikelihood, 4)
  assert.equal(result.items[0]?.recommendationScore, 5)
  assert.equal(result.items[0]?.visitorRole, 'counselor')
})

test('mapBackendAdminBoothFeedbackListToDomain safely falls back when optional summary metrics are omitted', () => {
  const result = mapBackendAdminBoothFeedbackListToDomain({
    summary: {
      total_count: 1,
      average_rating: 4.0,
      rating_counts: { '4': 1 },
    },
    items: [
      {
        id: 'bf-legacy',
        rating: 4,
        usage_likelihood: 3,
        recommendation_score: 3,
        message: 'Bagus.',
        event_label: 'Event Booth EVA',
        photos: [],
        created_at: '2026-11-26T10:00:00Z',
      },
    ],
    total: 1,
    page: 1,
    page_size: 10,
  })

  assert.equal(result.summary.roleCounts.user, 0)
  assert.equal(result.summary.roleCounts.counselor, 0)
  assert.equal(result.items[0]?.visitorRole, 'user')
  assert.equal(result.summary.averageUsageLikelihood, 0)
  assert.equal(result.summary.highUsageIntentCount, 0)
  assert.equal(result.summary.highUsageIntentPercentage, 0)
  assert.equal(result.summary.averageRecommendationScore, 0)
  assert.equal(result.summary.promoterCount, 0)
  assert.equal(result.summary.promoterPercentage, 0)
})
