import { useEffect, useState } from 'react'
import apkMetadata from '@/config/apkMetadata.json'
import { DOWNLOAD_APK_URL, DOWNLOAD_COUNSELOR_APK_URL } from '@/content/landing'

const GITHUB_OWNER = 'Nexa-Code-Studio'
const GITHUB_REPO = 'eva-ecosystem'
const LATEST_RELEASE_API_URL = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest`
const RELEASES_LIST_API_URL = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases?per_page=10`
const CACHE_TTL_MS = 15 * 60 * 1000

export type AppReleaseTarget = 'mobile' | 'counselor'

export interface LatestReleaseInfo {
  version: string
  sizeBytes: number
  sizeFormatted: string
  downloadUrl: string
}

interface CachedRelease extends LatestReleaseInfo {
  cachedAt: number
}

interface GitHubAsset {
  name?: unknown
  size?: unknown
  browser_download_url?: unknown
}

interface GitHubRelease {
  tag_name?: unknown
  draft?: unknown
  assets?: unknown
}

const APP_RELEASE_CONFIG: Record<
  AppReleaseTarget,
  {
    assetName: string
    cacheKey: string
    fallback: LatestReleaseInfo
  }
> = {
  mobile: {
    assetName: 'eva-mobile-release.apk',
    cacheKey: 'eva_latest_apk_release_mobile_v1',
    fallback: {
      version: apkMetadata.mobile?.version || apkMetadata.version || 'latest',
      sizeBytes: apkMetadata.mobile?.sizeBytes || apkMetadata.sizeBytes || 115339517,
      sizeFormatted: apkMetadata.mobile?.sizeFormatted || apkMetadata.sizeFormatted || '~110 MB',
      downloadUrl: DOWNLOAD_APK_URL,
    },
  },
  counselor: {
    assetName: 'eva-counselor-mobile-release.apk',
    cacheKey: 'eva_latest_apk_release_counselor_v1',
    fallback: {
      version: apkMetadata.counselor?.version || 'prototype',
      sizeBytes: apkMetadata.counselor?.sizeBytes || 56818391,
      sizeFormatted: apkMetadata.counselor?.sizeFormatted || '~54 MB',
      downloadUrl: DOWNLOAD_COUNSELOR_APK_URL,
    },
  },
}

const memoryCache: Partial<Record<AppReleaseTarget, CachedRelease>> = {}
const inFlightFetch: Partial<Record<AppReleaseTarget, Promise<LatestReleaseInfo>>> = {}

export function formatApkSizeMb(bytes: number, fallbackFormatted = '~61 MB'): string {
  if (!Number.isFinite(bytes) || bytes <= 0) {
    return fallbackFormatted
  }
  return `~${Math.round(bytes / (1024 * 1024))} MB`
}

function isValidReleaseInfo(value: unknown): value is CachedRelease {
  if (!value || typeof value !== 'object') return false
  const record = value as Record<string, unknown>
  return (
    typeof record.version === 'string' &&
    record.version.length > 0 &&
    typeof record.sizeBytes === 'number' &&
    typeof record.sizeFormatted === 'string' &&
    record.sizeFormatted.length > 0 &&
    typeof record.downloadUrl === 'string' &&
    record.downloadUrl.length > 0 &&
    typeof record.cachedAt === 'number'
  )
}

function readCachedRelease(app: AppReleaseTarget): LatestReleaseInfo | null {
  const now = Date.now()
  const mem = memoryCache[app]
  if (mem && now - mem.cachedAt < CACHE_TTL_MS) {
    return mem
  }
  if (typeof window === 'undefined') return null

  const { cacheKey } = APP_RELEASE_CONFIG[app]
  try {
    const raw = window.sessionStorage.getItem(cacheKey)
    if (!raw) return null
    const parsed: unknown = JSON.parse(raw)
    if (!isValidReleaseInfo(parsed) || now - parsed.cachedAt >= CACHE_TTL_MS) {
      window.sessionStorage.removeItem(cacheKey)
      return null
    }
    memoryCache[app] = parsed
    return parsed
  } catch {
    return null
  }
}

function writeCachedRelease(app: AppReleaseTarget, info: LatestReleaseInfo): void {
  const entry: CachedRelease = { ...info, cachedAt: Date.now() }
  memoryCache[app] = entry
  if (typeof window === 'undefined') return
  try {
    window.sessionStorage.setItem(APP_RELEASE_CONFIG[app].cacheKey, JSON.stringify(entry))
  } catch {
    // Ignore storage quota or private browsing errors
  }
}

function extractApkFromRelease(release: GitHubRelease, app: AppReleaseTarget): LatestReleaseInfo | null {
  if (!release || release.draft === true) return null
  if (typeof release.tag_name !== 'string' || !release.tag_name.trim()) return null
  if (!Array.isArray(release.assets)) return null

  const { assetName, fallback } = APP_RELEASE_CONFIG[app]
  const apkAsset = release.assets.find(
    (asset): asset is GitHubAsset =>
      Boolean(asset) &&
      typeof asset === 'object' &&
      (asset as GitHubAsset).name === assetName,
  )
  if (!apkAsset) return null

  const sizeBytes =
    typeof apkAsset.size === 'number' && apkAsset.size > 0
      ? apkAsset.size
      : fallback.sizeBytes
  const downloadUrl =
    typeof apkAsset.browser_download_url === 'string' &&
    apkAsset.browser_download_url.startsWith('https://')
      ? apkAsset.browser_download_url
      : fallback.downloadUrl

  return {
    version: release.tag_name.trim(),
    sizeBytes,
    sizeFormatted: formatApkSizeMb(sizeBytes, fallback.sizeFormatted),
    downloadUrl,
  }
}

async function fetchGitHubJson<T>(url: string): Promise<T | null> {
  const response = await fetch(url, {
    headers: { Accept: 'application/vnd.github+json' },
  })
  if (!response.ok) return null
  return (await response.json()) as T
}

async function resolveLatestRelease(app: AppReleaseTarget): Promise<LatestReleaseInfo> {
  const cached = readCachedRelease(app)
  if (cached) return cached

  const pending = inFlightFetch[app]
  if (pending) return pending

  const { fallback } = APP_RELEASE_CONFIG[app]

  const promise = (async () => {
    try {
      const latest = await fetchGitHubJson<GitHubRelease>(LATEST_RELEASE_API_URL)
      const fromLatest = latest ? extractApkFromRelease(latest, app) : null
      if (fromLatest) {
        writeCachedRelease(app, fromLatest)
        return fromLatest
      }

      // Fallback when global `latest` release belongs to the sibling app or lacks this APK asset
      const releases = await fetchGitHubJson<GitHubRelease[]>(RELEASES_LIST_API_URL)
      if (Array.isArray(releases)) {
        for (const release of releases) {
          const matched = extractApkFromRelease(release, app)
          if (matched) {
            writeCachedRelease(app, matched)
            return matched
          }
        }
      }
    } catch {
      // Network errors or GitHub rate limits fall back cleanly to static metadata
    } finally {
      delete inFlightFetch[app]
    }

    return fallback
  })()

  inFlightFetch[app] = promise
  return promise
}

export function useAppRelease(app: AppReleaseTarget): LatestReleaseInfo {
  const [release, setRelease] = useState<LatestReleaseInfo>(
    () => readCachedRelease(app) ?? APP_RELEASE_CONFIG[app].fallback,
  )

  useEffect(() => {
    let active = true

    resolveLatestRelease(app).then((resolved) => {
      if (active) {
        setRelease(resolved)
      }
    })

    return () => {
      active = false
    }
  }, [app])

  return release
}

export function useLatestRelease(): LatestReleaseInfo {
  return useAppRelease('mobile')
}
