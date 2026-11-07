/**
 * Placeholder app screens rendered inside <PhoneFrame>.
 * Modularized into MockupPrimitives, FeatureScreensPrimary, and FeatureScreensSecondary.
 */
import type { ComponentType } from 'react'
import type { FeatureId } from '@/content/landing'
import { Waveform } from './MockupPrimitives'
import {
  AvatarScreen,
  HomeScreen,
  QuestScreen,
  VoiceScreen,
} from './FeatureScreensPrimary'
import {
  DiaryScreen,
  SafetyScreen,
  ScreeningScreen,
} from './FeatureScreensSecondary'

export { Waveform, HomeScreen }

const featureScreens: Record<FeatureId, ComponentType> = {
  voice: VoiceScreen,
  quest: QuestScreen,
  avatar: AvatarScreen,
  diary: DiaryScreen,
  screening: ScreeningScreen,
  safety: SafetyScreen,
}

export function FeatureScreen({ id }: { id: FeatureId }) {
  const Screen = featureScreens[id]
  return <Screen />
}
