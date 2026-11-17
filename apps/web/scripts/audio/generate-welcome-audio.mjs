import dns from 'node:dns'
import { existsSync, readFileSync } from 'node:fs'
import { mkdir, writeFile } from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

dns.setDefaultResultOrder('ipv4first')

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url))
const WEB_ROOT = path.resolve(SCRIPT_DIR, '../..')
const REPO_ROOT = path.resolve(WEB_ROOT, '../..')
const OUTPUT_PATH = path.join(WEB_ROOT, 'public/audio/eva-welcome.mp3')

const VOICE_ID = 'cgSgspJ2msm6clMCkdW9' // Jessica (consistent with Eva Mobile default)
const PRIMARY_MODEL = 'eleven_v4'
const EXPRESSIVE_FALLBACK_MODEL = 'eleven_v3'
const LEGACY_FALLBACK_MODEL = 'eleven_multilingual_v2'
const OUTPUT_FORMAT = 'mp3_44100_128'

const WELCOME_SCRIPT =
  '[warm, calm] Tarik napas pelan dulu, ya... hari ini mungkin terasa penuh. [gentle] Aku EVA. [warmly] Jelajahi ruang ini dengan tenang... dan mulai saat kamu merasa siap.'

function stripAudioTags(text) {
  return text.replace(/\[[^\]]+\]\s*/g, '').replace(/\s+/g, ' ').trim()
}

function buildVoiceSettingsForModel(modelId) {
  if (modelId.startsWith('eleven_v4')) {
    // ElevenLabs v4 strictly accepts stability, similarity_boost, and use_speaker_boost (no style/speed)
    return {
      stability: 0.45,
      similarity_boost: 0.8,
      use_speaker_boost: true,
    }
  }
  if (modelId.startsWith('eleven_v3')) {
    // ElevenLabs v3 requires discrete stability presets (0.0 Creative, 0.5 Natural, 1.0 Robust)
    return {
      stability: 0.5,
      similarity_boost: 0.8,
      use_speaker_boost: true,
    }
  }
  return {
    stability: 0.45,
    similarity_boost: 0.8,
    style: 0.15,
    use_speaker_boost: true,
  }
}

function parseEnvFile(filePath, targetKey) {
  if (!existsSync(filePath)) return null
  const lines = readFileSync(filePath, 'utf8').split(/\r?\n/)
  for (const rawLine of lines) {
    const line = rawLine.trim()
    if (!line || line.startsWith('#')) continue
    const normalized = line.startsWith('export ') ? line.slice(7).trim() : line
    const eqIndex = normalized.indexOf('=')
    if (eqIndex <= 0) continue
    const key = normalized.slice(0, eqIndex).trim()
    if (key !== targetKey) continue
    let value = normalized.slice(eqIndex + 1).trim()
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1)
    }
    return value || null
  }
  return null
}

function resolveApiKeys() {
  const keys = []
  const pushKeys = (raw) => {
    if (!raw) return
    for (const part of raw.split(',')) {
      const cleaned = part.trim()
      if (cleaned && !keys.includes(cleaned)) keys.push(cleaned)
    }
  }

  pushKeys(process.env.ELEVENLABS_API_KEY)
  pushKeys(process.env.ELEVENLABS_API_KEYS)

  const candidates = [
    path.join(os.homedir(), '.env'),
    path.join(REPO_ROOT, '.env'),
    path.join(WEB_ROOT, '.env'),
  ]
  for (const candidate of candidates) {
    pushKeys(parseEnvFile(candidate, 'ELEVENLABS_API_KEY'))
    pushKeys(parseEnvFile(candidate, 'ELEVENLABS_API_KEYS'))
  }
  return keys
}

async function synthesize({ apiKey, modelId, includeLanguageCode }) {
  const endpoint = `https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}?output_format=${OUTPUT_FORMAT}`
  const supportsAudioTags = modelId.startsWith('eleven_v4') || modelId.startsWith('eleven_v3')
  const payload = {
    text: supportsAudioTags ? WELCOME_SCRIPT : stripAudioTags(WELCOME_SCRIPT),
    model_id: modelId,
    voice_settings: buildVoiceSettingsForModel(modelId),
    ...(includeLanguageCode ? { language_code: 'id' } : {}),
  }

  return fetch(endpoint, {
    method: 'POST',
    headers: {
      'xi-api-key': apiKey,
      'Content-Type': 'application/json',
      Accept: 'audio/mpeg',
    },
    body: JSON.stringify(payload),
  })
}

async function main() {
  const apiKeys = resolveApiKeys()
  if (apiKeys.length === 0) {
    console.error(
      'Missing ELEVENLABS_API_KEY or ELEVENLABS_API_KEYS in environment, ~/.env, or project .env. Aborting.',
    )
    process.exit(1)
  }

  const attempts = [
    { modelId: PRIMARY_MODEL, includeLanguageCode: true },
    { modelId: PRIMARY_MODEL, includeLanguageCode: false },
    { modelId: EXPRESSIVE_FALLBACK_MODEL, includeLanguageCode: true },
    { modelId: EXPRESSIVE_FALLBACK_MODEL, includeLanguageCode: false },
    { modelId: LEGACY_FALLBACK_MODEL, includeLanguageCode: false },
  ]

  let successResponse = null
  for (const [keyIndex, apiKey] of apiKeys.entries()) {
    for (const attempt of attempts) {
      const response = await synthesize({ apiKey, ...attempt })
      if (response.ok) {
        console.log(`Generated welcome audio via ${attempt.modelId} (key #${keyIndex + 1})`)
        successResponse = response
        break
      }
      const errText = await response.text()
      console.warn(
        `Attempt (${attempt.modelId}, lang=${attempt.includeLanguageCode}, key #${keyIndex + 1}) failed (${response.status}): ${errText.slice(0, 200)}`,
      )
      if (response.status === 401 || response.status === 403 || response.status === 429) {
        break
      }
    }
    if (successResponse) break
  }

  if (!successResponse) {
    console.error('Failed to synthesize welcome audio after fallback attempts.')
    process.exit(1)
  }

  const audioBuffer = Buffer.from(await successResponse.arrayBuffer())
  await mkdir(path.dirname(OUTPUT_PATH), { recursive: true })
  await writeFile(OUTPUT_PATH, audioBuffer)
  console.log(`Saved ${audioBuffer.byteLength} bytes to ${path.relative(REPO_ROOT, OUTPUT_PATH)}`)
}

main().catch((error) => {
  console.error('Unexpected error generating welcome audio:', error)
  process.exit(1)
})
