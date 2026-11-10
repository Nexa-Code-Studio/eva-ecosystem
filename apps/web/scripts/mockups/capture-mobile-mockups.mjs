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
const MOBILE_ROOT = path.join(MONOREPO_ROOT, 'apps/eva_mobile')
const FLUTTER_BUILD_WEB = path.join(MOBILE_ROOT, 'build/web')
const OUTPUT_DIR = path.join(WEB_ROOT, 'public/images/mockups')

const PORT = 8098
const BASE_URL = `http://127.0.0.1:${PORT}`

const ROUTES_TO_CAPTURE = [
  {
    id: 'home',
    route: '/#/home',
    title: 'Beranda Eva Mobile (Dashboard)',
    description: 'Header profil, kartu status emosi, quest harian & tombol curhat',
  },
  {
    id: 'voice',
    route: '/#/voice_call',
    title: 'Curhat Suara Interaktif (Voice Call)',
    description: 'Layar panggilan suara real-time dengan orb Luna & status mikrofon',
  },
  {
    id: 'diary',
    route: '/#/diary',
    title: 'Diari Emosi AI & Pola Pikir',
    description: 'Timeline catatan refleksi emosi, mood tracker & sintesis AI',
  },
  {
    id: 'screening',
    route: '/#/dass',
    title: 'Skrining Mandiri DASS-21 Klinis',
    description: 'Evaluasi psikometrik depresi, kecemasan, dan stres terstandar',
  },
  {
    id: 'safety',
    route: '/#/support',
    title: 'Protokol SafetyNet 24/7 (Bantuan Krisis)',
    description: 'Akses cepat hotline darurat, kontak pertolongan & faskes rujukan',
  },
  {
    id: 'quest',
    route: '/#/monitoring',
    title: 'Misi Ketahanan Emosi & Pemantauan (Quest)',
    description: 'Grafik tren emosi harian, konsistensi coping, dan target mingguan',
  },
  {
    id: 'avatar',
    route: '/#/settings',
    title: 'Personalisasi & Pengaturan Sahabat AI',
    description: 'Kustomisasi persona, preferensi suara, privasi & keamanan biometrik',
  },
]

function ensureFlutterWebBuild() {
  const needsRebuild = process.argv.includes('--rebuild') || !fs.existsSync(path.join(FLUTTER_BUILD_WEB, 'index.html'))

  if (!needsRebuild) {
    console.log(`✅ Build Flutter Web ditemukan di: ${FLUTTER_BUILD_WEB}`)
    return
  }

  console.log('🔨 Mengompilasi aplikasi Flutter eva_mobile untuk Web (USE_MOCK_DATA=true)...')
  const buildResult = spawnSync(
    'flutter',
    [
      'build',
      'web',
      '--dart-define=USE_MOCK_DATA=true',
      '--dart-define=MOCK=true',
    ],
    {
      cwd: MOBILE_ROOT,
      stdio: 'inherit',
    },
  )

  if (buildResult.status !== 0) {
    throw new Error('Gagal mengompilasi Flutter Web eva_mobile.')
  }
  console.log('✅ Kompilasi Flutter Web selesai.')
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
    let reqPath = req.url.split('?')[0].split('#')[0]
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
    // Fallback via Python PIL jika ffmpeg libwebp tidak tersedia
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
  console.log('📱 EVA Mobile Screenshot Capture Pipeline (Issue #39)')
  console.log('🎯 Target Output: apps/web/public/images/mockups/')
  console.log('==============================================================')

  ensureFlutterWebBuild()
  fs.mkdirSync(OUTPUT_DIR, { recursive: true })

  console.log(`🌐 Menjalankan server lokal Flutter di ${BASE_URL}...`)
  const server = await startStaticServer()

  let browser = null
  try {
    browser = await chromium.launch({
      headless: true,
      args: ['--disable-web-security', '--allow-running-insecure-content'],
    })

    // Konfigurasi viewport seluler modern (390 x 844 @2x Retina)
    const context = await browser.newContext({
      viewport: { width: 390, height: 844 },
      deviceScaleFactor: 2,
      isMobile: true,
      hasTouch: true,
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
      // Berikan jeda waktu agar animasi transisi dan font Flutter stabil
      await page.waitForTimeout(2000)

      // Menutup overlay tutorial interaktif di rute Beranda jika muncul
      if (item.id === 'home') {
        console.log('     👆 Menutup overlay tutorial di Beranda (klik Lewati pada 330, 545)...')
        await page.mouse.click(330, 545)
        // Beri jeda agar animasi fade-out selesai dan UI beranda bersih sempurna
        await page.waitForTimeout(600)
      } else {
        await page.waitForTimeout(500)
      }

      const pngPath = path.join(OUTPUT_DIR, `${item.id}.png`)
      const webpPath = path.join(OUTPUT_DIR, `${item.id}.webp`)

      await page.screenshot({ path: pngPath })

      const webpSuccess = convertPngToWebp(pngPath, webpPath)
      const finalFile = webpSuccess ? `${item.id}.webp` : `${item.id}.png`
      const fileSizeKb = (fs.statSync(path.join(OUTPUT_DIR, finalFile)).size / 1024).toFixed(1)

      console.log(`     ✅ Berhasil disimpan: ${finalFile} (${fileSizeKb} KB)`)

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
    console.log(`\n📋 Metadata screenshot tersimpan di: ${metaPath}`)

    console.log('==============================================================')
    console.log(`🎉 Berhasil memperbarui ${ROUTES_TO_CAPTURE.length} tangkapan layar di:`)
    console.log(`   ${OUTPUT_DIR}`)
    console.log('==============================================================')
  } finally {
    if (browser) await browser.close().catch(() => {})
    server.close()
  }
}

main().catch((err) => {
  console.error('\n❌ Terjadi kesalahan saat mengambil tangkapan layar:', err)
  process.exit(1)
})

