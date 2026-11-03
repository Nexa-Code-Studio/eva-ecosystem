/**
 * Master Demo & Fixtures Configuration
 *
 * Mengontrol seluruh ketersediaan data dummy (seed) dan fitur-fitur simulasi
 * non-produksi di seluruh aplikasi EVA Portal.
 *
 * Untuk beralih ke Mode Produksi (data kosong/asli & tanpa tombol simulasi):
 * - Atur VITE_ENABLE_DEMO=false di file .env, atau
 * - Jalankan: VITE_ENABLE_DEMO=false npm run dev / npm run build
 */
const rawEnv = (import.meta.env.VITE_ENABLE_DEMO ?? '').toString().trim().toLowerCase()
export const isDemoMode = rawEnv !== 'false' && rawEnv !== '0' && rawEnv !== 'off'

export const DEMO_CONFIG = {
  enabled: isDemoMode,
  showDemoAccountsOnLogin: isDemoMode,
  showSimulateMobileRegistration: isDemoMode,
  showResetDemoButton: isDemoMode,
  useDummySeedData: isDemoMode,
}
