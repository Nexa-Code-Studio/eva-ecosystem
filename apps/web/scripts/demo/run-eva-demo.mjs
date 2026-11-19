#!/usr/bin/env node
import { spawn, execFileSync } from 'node:child_process'
import fs from 'node:fs'
import http from 'node:http'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium } from '@playwright/test'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const WEB_ROOT = path.resolve(__dirname, '../..')
const PLAN_PATH = path.join(__dirname, 'recording-plan.json')
const RECORDINGS_DIR = path.join(WEB_ROOT, 'recordings')
const RAW_DIR = path.join(RECORDINGS_DIR, 'raw')
const TIMESTAMPS_PATH = path.join(RECORDINGS_DIR, 'timestamps.json')
const SLICER_SCRIPT = path.join(__dirname, 'slice-recordings.mjs')

const BASE_URL = process.env.EVA_DEMO_URL || 'http://localhost:5173'
const IS_HEADLESS = process.argv.includes('--headless')
const PACE_MULTIPLIER = process.argv.includes('--fast') ? 0.35 : 1.0

function checkServerAlive(url) {
  return new Promise((resolve) => {
    const req = http.get(url, (res) => {
      res.resume()
      resolve(res.statusCode >= 200 && res.statusCode < 500)
    })
    req.on('error', () => resolve(false))
    req.setTimeout(1500, () => {
      req.destroy()
      resolve(false)
    })
  })
}

async function ensureDevServer() {
  if (await checkServerAlive(BASE_URL)) {
    console.log(`✅ Dev server sudah berjalan di ${BASE_URL}`)
    return null
  }

  console.log(`🚀 Menjalankan Vite dev server di ${BASE_URL}...`)
  const serverProc = spawn('npm', ['run', 'dev', '--', '--port', '5173', '--host'], {
    cwd: WEB_ROOT,
    stdio: 'ignore',
    detached: false,
  })

  for (let i = 0; i < 40; i++) {
    if (await checkServerAlive(BASE_URL)) {
      console.log(`✅ Vite dev server siap di ${BASE_URL}`)
      return serverProc
    }
    await new Promise((r) => setTimeout(r, 500))
  }

  serverProc.kill()
  throw new Error(`Gagal menjalankan dev server di ${BASE_URL}`)
}

async function main() {
  fs.mkdirSync(RAW_DIR, { recursive: true })
  const plan = JSON.parse(fs.readFileSync(PLAN_PATH, 'utf8'))
  const serverProc = await ensureDevServer()

  let browser = null
  try {
    console.log('==============================================================')
    console.log('🎥 Memulai Sesi Demo Otomatis Web EVA (Playwright 1080p)')
    console.log(`🖥️  Mode Layar : ${IS_HEADLESS ? 'Headless' : 'Headed (Muncul di Layar Laptop)'}`)
    console.log(`⏱️  Pacing     : ${PACE_MULTIPLIER === 1 ? '100% Sesuai Plan (~5m 20s)' : 'Fast Preview Mode'}`)
    console.log('==============================================================')

    browser = await chromium.launch({
      headless: IS_HEADLESS,
      args: [
        '--window-size=1920,1080',
        '--start-maximized',
        '--disable-infobars',
      ],
    })

    const videoCreatedAtMs = Date.now()
    const context = await browser.newContext({
      viewport: { width: 1920, height: 1080 },
      recordVideo: {
        dir: RAW_DIR,
        size: { width: 1920, height: 1080 },
      },
    })

    // Injeksi Kursor Visual, Efek Ripple Klik, & Banner Chapter di Setiap Halaman
    await context.addInitScript(() => {
      window.addEventListener('DOMContentLoaded', () => {
        if (document.getElementById('eva-demo-cursor')) return

        const style = document.createElement('style')
        style.textContent = `
          #eva-demo-cursor {
            position: fixed;
            top: 0;
            left: 0;
            width: 26px;
            height: 26px;
            margin-left: -13px;
            margin-top: -13px;
            border-radius: 9999px;
            background: rgba(88, 96, 227, 0.28);
            border: 2.5px solid #5860E3;
            box-shadow: 0 0 0 2px rgba(255,255,255,0.9), 0 4px 14px rgba(88,96,227,0.45);
            pointer-events: none;
            z-index: 2147483647;
            transition: transform 0.08s ease-out, background 0.12s ease;
          }
          #eva-demo-cursor::after {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            width: 6px;
            height: 6px;
            margin-left: -3px;
            margin-top: -3px;
            border-radius: 9999px;
            background: #EF4444;
          }
          .eva-demo-ripple {
            position: fixed;
            width: 36px;
            height: 36px;
            margin-left: -18px;
            margin-top: -18px;
            border-radius: 9999px;
            border: 2.5px solid #EF4444;
            background: rgba(239, 68, 68, 0.18);
            pointer-events: none;
            z-index: 2147483646;
            animation: evaRippleAnim 0.55s ease-out forwards;
          }
          @keyframes evaRippleAnim {
            0% { transform: scale(0.5); opacity: 1; }
            100% { transform: scale(2.1); opacity: 0; }
          }
          #eva-demo-chapter-badge {
            position: fixed;
            bottom: 18px;
            left: 18px;
            z-index: 2147483645;
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 8px 14px;
            border-radius: 9999px;
            background: rgba(15, 23, 42, 0.86);
            backdrop-filter: blur(8px);
            color: #F8FAFC;
            font-family: system-ui, -apple-system, sans-serif;
            font-size: 12px;
            font-weight: 600;
            letter-spacing: 0.01em;
            box-shadow: 0 8px 24px rgba(15, 23, 42, 0.22);
            border: 1px solid rgba(255, 255, 255, 0.15);
            pointer-events: none;
            transition: opacity 0.2s ease;
          }
          #eva-demo-chapter-badge .eva-rec-dot {
            width: 8px;
            height: 8px;
            border-radius: 9999px;
            background: #EF4444;
            box-shadow: 0 0 8px #EF4444;
          }
        `
        document.head.appendChild(style)

        const cursor = document.createElement('div')
        cursor.id = 'eva-demo-cursor'
        document.body.appendChild(cursor)

        const badge = document.createElement('div')
        badge.id = 'eva-demo-chapter-badge'
        badge.innerHTML = '<span class="eva-rec-dot"></span><span id="eva-demo-chapter-text">Menyiapkan Demo EVA...</span>'
        document.body.appendChild(badge)

        const savedChapter = sessionStorage.getItem('__eva_demo_chapter')
        if (savedChapter) {
          const textEl = document.getElementById('eva-demo-chapter-text')
          if (textEl) textEl.textContent = savedChapter
        }

        window.addEventListener(
          'mousemove',
          (e) => {
            cursor.style.transform = `translate(${e.clientX}px, ${e.clientY}px)`
          },
          { passive: true },
        )

        window.addEventListener(
          'mousedown',
          (e) => {
            const ripple = document.createElement('div')
            ripple.className = 'eva-demo-ripple'
            ripple.style.left = `${e.clientX}px`
            ripple.style.top = `${e.clientY}px`
            document.body.appendChild(ripple)
            setTimeout(() => ripple.remove(), 600)
          },
          { passive: true },
        )
      })

      window.__setEvaChapter = (text) => {
        sessionStorage.setItem('__eva_demo_chapter', text)
        const el = document.getElementById('eva-demo-chapter-text')
        if (el) el.textContent = text
      }
    })

    const page = await context.newPage()
    const videoObj = page.video()

    const waitMs = async (ms) => {
      await page.waitForTimeout(Math.max(150, Math.round(ms * PACE_MULTIPLIER)))
    }

    const moveAndClick = async (locator, pauseAfterMs = 900) => {
      try {
        const target = locator.first()
        await target.waitFor({ state: 'visible', timeout: 5000 })
        await target.scrollIntoViewIfNeeded()
        const box = await target.boundingBox()
        if (box) {
          await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps: 14 })
          await page.waitForTimeout(120)
        }
        await target.click({ delay: 60 })
        await waitMs(pauseAfterMs)
        return true
      } catch {
        return false
      }
    }

    const moveAndType = async (locator, text, pauseAfterMs = 700) => {
      try {
        const target = locator.first()
        await target.waitFor({ state: 'visible', timeout: 5000 })
        await target.scrollIntoViewIfNeeded()
        const box = await target.boundingBox()
        if (box) {
          await page.mouse.move(box.x + Math.min(80, box.width / 2), box.y + box.height / 2, {
            steps: 10,
          })
        }
        await target.click()
        await target.fill('')
        await target.pressSequentially(text, {
          delay: Math.max(12, Math.round(28 * PACE_MULTIPLIER)),
        })
        await waitMs(pauseAfterMs)
        return true
      } catch {
        return false
      }
    }

    const smoothScrollTo = async (yOffset, durationMs = 1200) => {
      await page.evaluate(
        async ({ targetY, dur }) => {
          const startY = window.scrollY
          const diff = targetY - startY
          const steps = 24
          const stepWait = dur / steps
          for (let i = 1; i <= steps; i++) {
            const progress = i / steps
            const ease = 0.5 - Math.cos(progress * Math.PI) / 2
            window.scrollTo(0, startY + diff * ease)
            await new Promise((r) => setTimeout(r, stepWait))
          }
        },
        { targetY: yOffset, dur: Math.max(250, Math.round(durationMs * PACE_MULTIPLIER)) },
      )
      await waitMs(500)
    }

    // Buka halaman utama & reset localStorage agar demo selalu bersih
    await page.goto(BASE_URL, { waitUntil: 'networkidle' })
    await page.evaluate(() => {
      localStorage.clear()
      sessionStorage.clear()
    })
    await page.reload({ waitUntil: 'networkidle' })

    // 00. Countdown 5 Detik untuk Spectacle
    const countdownSec = plan.countdownSeconds || 5
    console.log(`\n⏳ Menampilkan Countdown ${countdownSec} detik di layar (Siapkan Spectacle)...`)
    await page.evaluate(async (seconds) => {
      const overlay = document.createElement('div')
      overlay.id = 'eva-spectacle-countdown'
      overlay.style.cssText = `
        position: fixed; inset: 0; z-index: 2147483646;
        display: flex; flex-direction: column; align-items: center; justify-content: center;
        background: rgba(15, 23, 42, 0.88); backdrop-filter: blur(10px);
        color: white; font-family: system-ui, -apple-system, sans-serif;
        text-align: center;
      `
      overlay.innerHTML = `
        <div style="font-size:14px; font-weight:700; letter-spacing:0.12em; text-transform:uppercase; color:#A5B4FC; margin-bottom:12px;">
          Perekaman Otomatis Web EVA (Playwright + Spectacle)
        </div>
        <div id="eva-cd-num" style="font-size:88px; font-weight:800; line-height:1; color:#FFFFFF; margin-bottom:16px;">
          ${seconds}
        </div>
        <div style="font-size:16px; color:#CBD5E1; max-width:520px; line-height:1.5;">
          Nyalakan perekaman layar <strong>Spectacle</strong> sekarang.<br/>
          Seluruh 12 segmen fitur juga direkam &amp; dipotong otomatis di background.
        </div>
      `
      document.body.appendChild(overlay)
      const numEl = document.getElementById('eva-cd-num')
      for (let s = seconds; s >= 1; s--) {
        if (numEl) numEl.textContent = String(s)
        await new Promise((r) => setTimeout(r, 1000))
      }
      overlay.remove()
    }, countdownSec)

    const recordedSegments = []
    const getElapsedSec = () => Number(((Date.now() - videoCreatedAtMs) / 1000).toFixed(2))

    const runSegment = async (segId, actionFn) => {
      const segPlan = plan.segments.find((s) => s.id === segId)
      const startSec = getElapsedSec()
      const label = `[${segPlan.id}/12] ${segPlan.title}`
      console.log(`\n▶️  ${label} (Mulai: ${startSec}s | Target: ${segPlan.targetDurationSeconds}s)`)

      await page.evaluate((txt) => {
        if (window.__setEvaChapter) window.__setEvaChapter(txt)
      }, label)

      const segStartMs = Date.now()
      await actionFn(segPlan)

      const targetMs = Math.round(segPlan.targetDurationSeconds * 1000 * PACE_MULTIPLIER)
      const spentMs = Date.now() - segStartMs
      if (spentMs < targetMs) {
        await page.waitForTimeout(targetMs - spentMs)
      }

      const endSec = getElapsedSec()
      console.log(`   ✅ Selesai ${segPlan.filename} (${startSec}s -> ${endSec}s | Durasi: ${(endSec - startSec).toFixed(1)}s)`)
      recordedSegments.push({
        ...segPlan,
        startSec,
        endSec,
        actualDurationSec: Number((endSec - startSec).toFixed(2)),
      })
    }

    // =========================================================================
    // SEGMEN 01: Public Landing Page (/)
    // =========================================================================
    await runSegment('01', async () => {
      const splash = page.locator('#welcome-splash')
      const enterBtn = page.locator('#welcome-enter-btn')
      await Promise.race([
        splash.waitFor({ state: 'hidden', timeout: 8500 }).catch(() => {}),
        enterBtn.waitFor({ state: 'visible', timeout: 8500 }).catch(() => {}),
      ])
      if (await enterBtn.isVisible().catch(() => false)) {
        await moveAndClick(enterBtn, 400)
      }
      await splash.waitFor({ state: 'hidden', timeout: 8000 }).catch(() => {})

      await page.mouse.move(960, 380, { steps: 15 })
      await waitMs(2500)

      // Scroll ke Features & klik tab fitur
      await smoothScrollTo(820, 1400)
      await waitMs(1500)
      const featureButtons = page.locator('#fitur button, section button').filter({
        hasText: /Konseling|Jurnal|DASS|Koping|Krisis|Suara/i,
      })
      const count = await featureButtons.count()
      for (let i = 0; i < Math.min(3, count); i++) {
        await moveAndClick(featureButtons.nth(i), 1500)
      }

      // Scroll ke Cara Kerja & Keunggulan (USP)
      await smoothScrollTo(1750, 1400)
      await waitMs(2200)
      await smoothScrollTo(2600, 1400)
      await waitMs(2200)

      // Scroll ke FAQ & klik 2 pertanyaan
      await smoothScrollTo(3400, 1400)
      const faqButtons = page.locator('#faq button, button[aria-expanded]')
      const faqCount = await faqButtons.count()
      for (let i = 0; i < Math.min(2, faqCount); i++) {
        await moveAndClick(faqButtons.nth(i), 1400)
      }

      // Scroll ke CTA bawah lalu kembali ke atas untuk klik Portal / Pengajuan Mitra
      await smoothScrollTo(4100, 1200)
      await waitMs(1800)
      await smoothScrollTo(0, 1000)
      await waitMs(1000)
    })

    // =========================================================================
    // SEGMEN 02: Pendaftaran Psikolog Profesional Mandiri (/daftar-psikolog)
    // =========================================================================
    await runSegment('02', async () => {
      await page.goto(`${BASE_URL}/daftar-psikolog`, { waitUntil: 'networkidle' })
      await waitMs(1200)

      // Step 1: Profil Klinis
      await moveAndType(page.locator('#psy-fullName'), 'Nadia Kusumawardhani', 600)
      await moveAndType(page.locator('#psy-city'), 'YOGYAKARTA', 500)
      await moveAndType(
        page.locator('#psy-education'),
        'Magister Profesi Psikologi Klinis Universitas Gadjah Mada',
        600,
      )
      await moveAndClick(page.getByRole('button', { name: /Lanjutkan/i }), 1200)

      // Step 2: STR & SIP
      await moveAndType(page.locator('#psy-strNumber'), 'STR-PK-2026-771204', 600)
      await moveAndType(page.locator('#psy-sipNumber'), '20260512-2031-01-0881', 600)
      await moveAndClick(page.getByRole('button', { name: /Lanjutkan/i }), 1200)

      // Step 3: Akun & Kirim
      await moveAndType(page.locator('#apply-email'), 'nadia.kusuma@psikologmandiri.id', 600)
      await moveAndType(page.locator('#apply-phone'), '081234567899', 500)
      await moveAndType(page.locator('#apply-password'), 'psikolog12345', 600)
      await moveAndClick(page.getByRole('button', { name: /Kirim Pendaftaran Psikolog/i }), 2200)
      await moveAndClick(page.getByRole('link', { name: /Cek Status di Halaman Masuk/i }), 1200)
    })

    // =========================================================================
    // SEGMEN 03: Login & Cek Status Psikolog (/login)
    // =========================================================================
    await runSegment('03', async () => {
      if (!page.url().includes('/login')) {
        await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle' })
      }
      await waitMs(1000)

      // 1. Cek Akun Psikolog Pending
      await moveAndClick(page.getByRole('button', { name: /Buka daftar akun demo|Akun Demo/i }), 900)
      await moveAndClick(page.getByRole('button', { name: /Psikolog Mandiri \(Pending\)/i }), 800)
      await moveAndClick(page.getByRole('button', { name: /^Masuk$/i }), 2200)
      await page.keyboard.press('Escape')
      await waitMs(800)

      // 2. Cek Akun Psikolog Revisi / Ditolak
      await moveAndClick(page.getByRole('button', { name: /Buka daftar akun demo|Akun Demo/i }), 900)
      await moveAndClick(
        page.getByRole('button', { name: /Psikolog \(Revisi \/ Ditolak\)/i }),
        800,
      )
      await moveAndClick(page.getByRole('button', { name: /^Masuk$/i }), 2400)
      await page.keyboard.press('Escape')
      await waitMs(800)

      // 3. Masuk sebagai Admin Website EVA
      await moveAndClick(page.getByRole('button', { name: /Buka daftar akun demo|Akun Demo/i }), 900)
      await moveAndClick(page.getByRole('button', { name: /Admin Website EVA/i }), 800)
      await moveAndClick(page.getByRole('button', { name: /^Masuk$/i }), 1800)
    })

    // =========================================================================
    // SEGMEN 04: Admin Dashboard Overview (/admin/dashboard)
    // =========================================================================
    await runSegment('04', async () => {
      await page.waitForURL('**/admin/dashboard**', { timeout: 5000 }).catch(() => {})
      await waitMs(1800)

      await page.mouse.move(650, 220, { steps: 12 })
      await waitMs(1200)
      await page.mouse.move(1100, 220, { steps: 12 })
      await waitMs(1200)
      await page.mouse.move(850, 480, { steps: 14 })
      await waitMs(1800)

      await smoothScrollTo(480, 1200)
      await page.mouse.move(1250, 480, { steps: 14 })
      await waitMs(2200)
      await smoothScrollTo(0, 900)
    })

    // =========================================================================
    // SEGMEN 05: Admin Pengaturan Tarif Platform, Kurs & Paket Koin (/admin/settings)
    // =========================================================================
    await runSegment('05', async () => {
      await moveAndClick(
        page.locator('aside a, nav a').filter({ hasText: /Pengaturan Platform/i }),
        1400,
      )
      if (!page.url().includes('/admin/settings')) {
        await page.goto(`${BASE_URL}/admin/settings`, { waitUntil: 'networkidle' })
      }
      await waitMs(1200)

      await moveAndType(page.locator('#pricing-base'), '175', 800)
      await moveAndType(page.locator('#pricing-ext'), '175', 700)
      await moveAndType(page.locator('#share-counselor'), '80', 600)
      await moveAndClick(
        page.getByRole('button', { name: /Simpan & Terapkan Tarif Platform/i }),
        1800,
      )

      await moveAndClick(page.getByRole('button', { name: /Kurs & Paket Koin/i }), 2000)
      await smoothScrollTo(240, 900)
      await waitMs(1200)
      await smoothScrollTo(0, 700)
    })

    // =========================================================================
    // SEGMEN 06: Admin Verifikasi STR/SIP Psikolog (/admin/psychologists)
    // =========================================================================
    await runSegment('06', async () => {
      await moveAndClick(
        page.locator('aside a, nav a').filter({ hasText: /Verifikasi Psikolog/i }),
        1400,
      )
      if (!page.url().includes('/admin/psychologists')) {
        await page.goto(`${BASE_URL}/admin/psychologists`, { waitUntil: 'networkidle' })
      }
      await waitMs(1200)

      // Buka modal Simulasi Pendaftaran Mobile
      await moveAndClick(
        page.getByRole('button', { name: /Simulasi Pendaftaran Mobile/i }),
        1400,
      )
      await moveAndType(page.locator('#sim-name'), 'Rania Putri Maharani', 600)
      await moveAndType(page.locator('#sim-str'), 'STR-PK-2026-991023', 500)
      await moveAndType(page.locator('#sim-city'), 'BANDUNG', 500)
      await moveAndClick(
        page.getByRole('button', { name: /Kirim Pendaftaran Simulasi/i }),
        1800,
      )

      const pendingTab = page.locator('button').filter({ hasText: /Antrean \(/i })
      if ((await pendingTab.count()) > 0) {
        await moveAndClick(pendingTab.first(), 1400)
      }

      const detailBtn = page.getByRole('button', { name: /Tinjau Berkas/i }).first()
      await moveAndClick(detailBtn, 1800)

      const approvePsyBtn = page.getByRole('button', {
        name: /Approve & Aktifkan/i,
      })
      if ((await approvePsyBtn.count()) > 0) {
        await moveAndClick(approvePsyBtn.first(), 2200)
      } else {
        await page.keyboard.press('Escape')
        await waitMs(1000)
      }
    })

    // =========================================================================
    // SEGMEN 07: Admin Monitoring Jadwal & Sesi Online (/admin/monitoring)
    // =========================================================================
    await runSegment('07', async () => {
      await moveAndClick(
        page.locator('aside a, nav a').filter({ hasText: /Monitoring Sesi/i }),
        1400,
      )
      if (!page.url().includes('/admin/monitoring')) {
        await page.goto(`${BASE_URL}/admin/monitoring`, { waitUntil: 'networkidle' })
      }
      await waitMs(1400)

      const durationSelect = page.getByLabel('Filter Durasi Sesi')
      await durationSelect.selectOption('60')
      await waitMs(1500)
      await durationSelect.selectOption('all')
      await waitMs(1400)
    })

    // =========================================================================
    // SEGMEN 08: Admin Pengguna & Transaksi Koin (/admin/users-coins)
    // =========================================================================
    await runSegment('08', async () => {
      await moveAndClick(
        page.locator('aside a, nav a').filter({ hasText: /Pengguna & Koin/i }),
        1400,
      )
      if (!page.url().includes('/admin/users-coins')) {
        await page.goto(`${BASE_URL}/admin/users-coins`, { waitUntil: 'networkidle' })
      }
      await waitMs(1400)

      const searchInput = page.locator('input[type="search"], input[placeholder*="Cari"]').first()
      await moveAndType(searchInput, 'EVA', 1400)
      await searchInput.fill('')
      await waitMs(1000)

      await moveAndClick(
        page.getByRole('button', { name: /Riwayat Transaksi Koin/i }),
        2200,
      )
      await smoothScrollTo(280, 1000)
      await waitMs(1800)
      await smoothScrollTo(0, 800)
    })

    // =========================================================================
    // SEGMEN 09: Admin CMS Konten Mobile & Website (/admin/content-config)
    // =========================================================================
    await runSegment('09', async () => {
      await moveAndClick(
        page.locator('aside a, nav a').filter({ hasText: /Konten|Konfigurasi/i }),
        1400,
      )
      if (!page.url().includes('/admin/content-config')) {
        await page.goto(`${BASE_URL}/admin/content-config`, { waitUntil: 'networkidle' })
      }
      await waitMs(1500)

      await smoothScrollTo(250, 900)
      await waitMs(1500)
      await smoothScrollTo(0, 700)

      await moveAndClick(page.getByRole('button', { name: /Waitlist & FAQ/i }), 2200)
      await smoothScrollTo(260, 900)
      await waitMs(1400)
      await smoothScrollTo(0, 700)

      await moveAndClick(page.getByRole('button', { name: /Keluar/i }), 1500)
    })

    // Tutup halaman & context agar file video .webm selesai ditulis ke disk
    await page.close()
    await context.close()
    const rawVideoPath = videoObj ? await videoObj.path() : null
    await browser.close()
    browser = null

    const outputMetadata = {
      generatedAt: new Date().toISOString(),
      rawVideoPath,
      countdownSeconds: countdownSec,
      paceMultiplier: PACE_MULTIPLIER,
      segments: recordedSegments,
    }

    fs.writeFileSync(TIMESTAMPS_PATH, JSON.stringify(outputMetadata, null, 2), 'utf8')
    console.log(`\n📝 File timestamp tersimpan di: ${TIMESTAMPS_PATH}`)

    // Otomatis panggil pemotong video FFmpeg
    execFileSync('node', [SLICER_SCRIPT], { stdio: 'inherit' })
  } finally {
    if (browser) {
      await browser.close().catch(() => {})
    }
    if (serverProc) {
      serverProc.kill()
    }
  }
}

main().catch((err) => {
  console.error('\n❌ Terjadi kesalahan saat menjalankan demo:', err)
  process.exit(1)
})

