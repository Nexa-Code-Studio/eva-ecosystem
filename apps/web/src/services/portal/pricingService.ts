import { calculatePricingBreakdown } from '@/services/contracts/portalMappers'
import { getActivePortalDataSource } from './storage'
import type { UpsertPlatformPricingRequestDto } from '@/types/api/contracts'
import type { PlatformPricingConfig } from '@/types/domain/portal'

export { calculatePricingBreakdown }

export async function fetchActivePlatformPricing(): Promise<PlatformPricingConfig> {
  return getActivePortalDataSource().fetchActivePricing()
}

export async function fetchPlatformPricingHistory(): Promise<PlatformPricingConfig[]> {
  return getActivePortalDataSource().fetchPricingHistory()
}

export async function savePlatformPricingConfig(
  payload: UpsertPlatformPricingRequestDto,
  existingConfigId?: string,
): Promise<PlatformPricingConfig> {
  const totalShare =
    Math.round((payload.counselor_share_percentage + payload.platform_fee_percentage) * 100) / 100
  if (Math.abs(totalShare - 100) > 0.01) {
    throw new Error('Total persentase bagi hasil (Hak Psikolog + Fee Platform) harus tepat 100%.')
  }
  if (payload.price_per_session < 0 || payload.extension_price_per_session < 0) {
    throw new Error('Tarif sesi dan tarif perpanjangan tidak boleh bernilai negatif.')
  }

  return getActivePortalDataSource().savePlatformPricing(payload, existingConfigId)
}
