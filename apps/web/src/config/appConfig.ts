/**
 * Single-Point Application Configuration (`appConfig`)
 *
 * Mengatur peralihan sumber data antara Mock Data Layer (`src/data/mock/`)
 * dan Production Backend API (`src/services/remote/`).
 *
 * Variabel Environment yang didukung:
 * - VITE_USE_MOCK_DATA: 'true' (default) | 'false'
 * - VITE_API_BASE_URL: URL base FastAPI backend (default: 'http://localhost:8888/api/v1')
 * - VITE_ENABLE_DEMO_TOOLS: 'true' (default saat mock aktif) | 'false'
 */

function parseBooleanEnv(value: unknown, defaultValue: boolean): boolean {
  if (value === undefined || value === null || value === '') return defaultValue
  const normalized = String(value).trim().toLowerCase()
  if (normalized === 'false' || normalized === '0' || normalized === 'off') return false
  if (normalized === 'true' || normalized === '1' || normalized === 'on') return true
  return defaultValue
}

const useMockFromEnv = parseBooleanEnv(
  import.meta.env.VITE_USE_MOCK_DATA ?? import.meta.env.VITE_ENABLE_DEMO,
  true,
)

const enableDevToolsFromEnv = parseBooleanEnv(
  import.meta.env.VITE_ENABLE_DEMO_TOOLS,
  useMockFromEnv,
)

export const APP_CONFIG = {
  useMockData: useMockFromEnv,
  apiBaseUrl:
    (import.meta.env.VITE_API_BASE_URL as string | undefined)?.trim() ||
    'http://localhost:8888/api/v1',
  enableDevTools: useMockFromEnv && enableDevToolsFromEnv,
} as const

