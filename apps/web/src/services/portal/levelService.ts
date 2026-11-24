import { getActivePortalDataSource } from './storage'
import type { UpsertPsychologistLevelRequestDto } from '@/types/api/contracts'
import type { LevelEvaluationBatchSummary, PsychologistLevelConfig } from '@/types/domain/portal'

export async function fetchPsychologistLevels(): Promise<PsychologistLevelConfig[]> {
  return getActivePortalDataSource().fetchPsychologistLevels()
}

export async function createPsychologistLevel(
  input: UpsertPsychologistLevelRequestDto,
): Promise<PsychologistLevelConfig> {
  return getActivePortalDataSource().createPsychologistLevel(input)
}

export async function updatePsychologistLevel(
  levelId: string,
  input: UpsertPsychologistLevelRequestDto,
): Promise<PsychologistLevelConfig> {
  return getActivePortalDataSource().updatePsychologistLevel(levelId, input)
}

export async function togglePsychologistLevelActive(
  levelId: string,
): Promise<PsychologistLevelConfig> {
  return getActivePortalDataSource().togglePsychologistLevelActive(levelId)
}

export async function deletePsychologistLevel(levelId: string): Promise<void> {
  return getActivePortalDataSource().deletePsychologistLevel(levelId)
}

export async function evaluateAllPsychologistLevels(): Promise<LevelEvaluationBatchSummary> {
  return getActivePortalDataSource().evaluateAllPsychologistLevels()
}
