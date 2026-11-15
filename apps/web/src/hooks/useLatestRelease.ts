import { useEffect, useState } from 'react'
import apkMetadata from '@/config/apkMetadata.json'
import { DOWNLOAD_APK_URL } from '@/content/landing'

const GITHUB_OWNER = 'Nexa-Code-Studio'
const GITHUB_REPO = 'eva-ecosystem'
const APK_ASSET_NAME = 'eva-mobile-release.apk'
const LATEST_RELEASE_API_URL = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest`
const RELEASES_LIST_API_URL = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases?per_page=10`
const CACHE_KEY = 'eva_latest_apk_release_v1'
const CACHE_TTL_MS = 15 * 60 * 1000

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

const FALLBACK_RELEASE: LatestReleaseInfo = {
  version: apkMetadata.version || 'prototype',
  sizeBytes: apkMetadata.sizeBytes || 64164832,
  sizeFormatted: apkMetadata.sizeFormatted || '~61 MB',
  downloadUrl: DOWNLOAD_APK_URL,
}

let memoryCache: CachedRelease | null = null
let inFlightFetch: Promise<LatestReleaseInfo> | null = null

export function formatApkSizeMb(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) {
    return FALLBACK_RELEASE.sizeFormatted
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

function readCachedRelease(): LatestReleaseInfo | null {
  const now = Date.now()
  if (memoryCache && now - memoryCache.cachedAt < CACHE_TTL_MS) {
    return memoryCache
  }
  if (typeof window === 'undefined') return null

  try {
    const raw = window.sessionStorage.getItem(CACHE_KEY)
    if (!raw) return null
    const parsed: unknown = JSON.parse(raw)
    if (!isValidReleaseInfo(parsed) || now - parsed.cachedAt >= CACHE_TTL_MS) {
      window.sessionStorage.removeItem(CACHE_KEY)
      return null
    }
    memoryCache = parsed
    return parsed
  } catch {
    return null
  }
}

function writeCachedRelease(info: LatestReleaseInfo): void {
  const entry: CachedRelease = { ...info, cachedAt: Date.now() }
  memoryCache = entry
  if (typeof window === 'undefined') return
  try {
    window.sessionStorage.setItem(CACHE_KEY, JSON.stringify(entry))
  } catch {
    // Ignore storage quota or private browsing errors
  }
}

function extractApkFromRelease(release: GitHubRelease): LatestReleaseInfo | null {
  if (!release || release.draft === true) return null
  if (typeof release.tag_name !== 'string' || !release.tag_name.trim()) return null
  if (!Array.isArray(release.assets)) return null

  const apkAsset = release.assets.find(
    (asset): asset is GitHubAsset =>
      Boolean(asset) &&
      typeof asset === 'object' &&
      (asset as GitHubAsset).name === APK_ASSET_NAME,
  )
  if (!apkAsset) return null

  const sizeBytes =
    typeof apkAsset.size === 'number' && apkAsset.size > 0
      ? apkAsset.size
      : FALLBACK_RELEASE.sizeBytes
  const downloadUrl =
    typeof apkAsset.browser_download_url === 'string' &&
    apkAsset.browser_download_url.startsWith('https://')
      ? apkAsset.browser_download_url
      : DOWNLOAD_APK_URL

  return {
    version: release.tag_name.trim(),
    sizeBytes,
    sizeFormatted: formatApkSizeMb(sizeBytes),
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

async function resolveLatestRelease(): Promise<LatestReleaseInfo> {
  const cached = readCachedRelease()
  if (cached) return cached

  if (inFlightFetch) return inFlightFetch

  inFlightFetch = (async () => {
    try {
      const latest = await fetchGitHubJson<GitHubRelease>(LATEST_RELEASE_API_URL)
      const fromLatest = latest ? extractApkFromRelease(latest) : null
      if (fromLatest) {
        writeCachedRelease(fromLatest)
        return fromLatest
      }

      // Fallback when global `latest` release belongs to another app without eva-mobile-release.apk
      const releases = await fetchGitHubJson<GitHubRelease[]>(RELEASES_LIST_API_URL)
      if (Array.isArray(releases)) {
        for (const release of releases) {
          const matched = extractApkFromRelease(release)
          if (matched) {
            writeCachedRelease(matched)
            return matched
          }
        }
      }
    } catch {
      // Network errors or GitHub rate limits fall back cleanly to static metadata
    } finally {
      inFlightFetch = null
    }

    return FALLBACK_RELEASE
  })()

  return inFlightFetch
}

export function useLatestRelease(): LatestReleaseInfo {
  const [release, setRelease] = useState<LatestReleaseInfo>(
    () => readCachedRelease() ?? FALLBACK_RELEASE,
  )

  useEffect(() => {
    let active = true

    resolveLatestRelease().then((resolved) => {
      if (active) {
        setRelease(resolved)
      }
    })

    return () => {
      active = false
    }
  }, [])

  return release
}
