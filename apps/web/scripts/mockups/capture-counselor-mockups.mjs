#!/usr/bin/env node
import { execFileSync, spawnSync } from 'node:child_process'
import fs from 'node:fs'
import http from 'node:http'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium } from '@playwright/test'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const WEB_ROOT = path.resolve(__dirname, '../..')
const MONOREPO_ROOT = path.resolve(WEB_ROOT, '../..')
const COUNSELOR_ROOT = path.join(MONOREPO_ROOT, 'apps/eva_counselor_mobile')
const FLUTTER_BUILD_WEB = path.join(COUNSELOR_ROOT, 'build/web')
const OUTPUT_DIR = path.join(WEB_ROOT, 'public/images/mockups/counselor')

const PORT = 8099
const BASE_URL = `http://127.0.0.1:${PORT}`

const ROUTES_TO_CAPTURE = [
  {
    id: 'schedule',
    route: '/#/counselor-shell',
    title: 'Beranda Praktik & Jadwal Psikolog',
    description: 'Kalender jadwal mingguan, status verifikasi STR/SIP, dan sesi aktif',
  },
  {
    id: 'consent',
    route: '/#/counselor-patient-detail',
    title: 'Ringkasan Klinis DASS-21 Berbasis Consent',
    description: 'Skor skrining DASS-21 dan catatan ringkas pasien dengan izin eksplisit',
  },
  {
    id: 'teleconsult',
    route: '/#/counselor-video-call',
    title: 'Ruang Telekonsultasi Video 30 Menit',
    description: 'Panggilan video WebRTC langsung antar psikolog dan pasien di aplikasi',
  },
  {
    id: 'finance',
    route: '/#/counselor-finances',
    title: 'Honorarium EVA Coin & Pencairan Dana',
    description: 'Riwayat pendapatan sesi konsultasi dan penarikan dana rekening bank',
  },
]

function ensureFlutterWebBuild() {
  const needsRebuild =
    process.argv.includes('--rebuild') || !fs.existsSync(path.join(FLUTTER_BUILD_WEB, 'index.html'))

  if (!needsRebuild) {
    console.log(`Build Flutter Web Counselor ditemukan di: ${FLUTTER_BUILD_WEB}`)
    return
  }

  console.log('Mengompilasi aplikasi Flutter eva_counselor_mobile untuk Web (USE_MOCK_DATA=true)...')
  const buildResult = spawnSync(
    'flutter',
    [
      'build',
      'web',
      '--dart-define=USE_MOCK_DATA=true',
      '--dart-define=MOCK=true',
    ],
    {
      cwd: COUNSELOR_ROOT,
      stdio: 'inherit',
    },
  )

  if (buildResult.status !== 0) {
    throw new Error('Gagal mengompilasi Flutter Web eva_counselor_mobile.')
  }
  console.log('Kompilasi Flutter Web Counselor selesai.')
}

function startStaticServer() {
  const mimes = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.wasm': 'application/wasm',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.css': 'text/css; charset=utf-8',
    '.ttf': 'font/ttf',
    '.otf': 'font/otf',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
  }

  const server = http.createServer((req, res) => {
    const reqPath = req.url.split('?')[0].split('#')[0]
    let filePath = path.join(FLUTTER_BUILD_WEB, reqPath)

    if (filePath.endsWith('/') || !fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
      filePath = path.join(FLUTTER_BUILD_WEB, 'index.html')
    }

    const ext = path.extname(filePath).toLowerCase()
    const contentType = mimes[ext] || 'application/octet-stream'

    res.writeHead(200, {
      'Content-Type': contentType,
      'Access-Control-Allow-Origin': '*',
      'Cross-Origin-Embedder-Policy': 'credentialless',
      'Cross-Origin-Opener-Policy': 'same-origin',
    })
    fs.createReadStream(filePath).pipe(res)
  })

  return new Promise((resolve, reject) => {
    server.listen(PORT, '127.0.0.1', (err) => {
      if (err) reject(err)
      else resolve(server)
    })
  })
}

function convertPngToWebp(pngPath, webpPath) {
  try {
    execFileSync('ffmpeg', ['-y', '-i', pngPath, '-c:v', 'libwebp', '-quality', '86', webpPath], {
      stdio: 'ignore',
    })
    return true
  } catch {
    try {
      execFileSync(
        'python3',
        ['-c', `from PIL import Image; Image.open("${pngPath}").save("${webpPath}", "WEBP", quality=86)`],
        { stdio: 'ignore' },
      )
      return true
    } catch {
      return false
    }
  }
}

async function main() {
  console.log('==============================================================')
  console.log('EVA Counselor Screenshot Capture Pipeline (Issue #142)')
  console.log('Target Output: apps/web/public/images/mockups/counselor/')
  console.log('==============================================================')

  ensureFlutterWebBuild()
  fs.mkdirSync(OUTPUT_DIR, { recursive: true })

  console.log(`Menjalankan server lokal Flutter di ${BASE_URL}...`)
  const server = await startStaticServer()

  let browser = null
  try {
    browser = await chromium.launch({
      headless: true,
      args: ['--disable-web-security', '--allow-running-insecure-content'],
    })

    const context = await browser.newContext({
      viewport: { width: 390, height: 844 },
      deviceScaleFactor: 2,
      isMobile: true,
      hasTouch: true,
    })

    await context.addInitScript(() => {
      window.localStorage.setItem('flutter.counselor_has_seen_menu_tour', 'true')
    })

    const page = await context.newPage()
    const metadata = {
      generatedAt: new Date().toISOString(),
      viewport: { width: 390, height: 844, scale: 2 },
      screens: [],
    }

    for (let i = 0; i < ROUTES_TO_CAPTURE.length; i++) {
      const item = ROUTES_TO_CAPTURE[i]
      const targetUrl = `${BASE_URL}${item.route}`
      const numPrefix = `[${String(i + 1).padStart(2, '0')}/${String(ROUTES_TO_CAPTURE.length).padStart(2, '0')}]`

      console.log(`\n${numPrefix} Mengambil tangkapan layar: ${item.title}`)
      console.log(`     Route: ${item.route}`)

      await page.goto(targetUrl, { waitUntil: 'networkidle', timeout: 30000 })
      await page.waitForTimeout(2500)

      const pngPath = path.join(OUTPUT_DIR, `${item.id}.png`)
      const webpPath = path.join(OUTPUT_DIR, `${item.id}.webp`)

      await page.screenshot({ path: pngPath })

      const webpSuccess = convertPngToWebp(pngPath, webpPath)
      const finalFile = webpSuccess ? `${item.id}.webp` : `${item.id}.png`
      const fileSizeKb = (fs.statSync(path.join(OUTPUT_DIR, finalFile)).size / 1024).toFixed(1)

      console.log(`     Berhasil disimpan: ${finalFile} (${fileSizeKb} KB)`)

      metadata.screens.push({
        id: item.id,
        title: item.title,
        route: item.route,
        webp: `${item.id}.webp`,
        png: `${item.id}.png`,
        fileSizeKb: Number(fileSizeKb),
      })
    }

    const metaPath = path.join(OUTPUT_DIR, 'metadata.json')
    fs.writeFileSync(metaPath, JSON.stringify(metadata, null, 2), 'utf8')
    console.log(`\nMetadata screenshot tersimpan di: ${metaPath}`)
    console.log('==============================================================')
  } finally {
    if (browser) await browser.close().catch(() => {})
    server.close()
  }
}

main().catch((err) => {
  console.error('\nTerjadi kesalahan saat mengambil tangkapan layar Eva Counselor:', err)
  process.exit(1)
})
