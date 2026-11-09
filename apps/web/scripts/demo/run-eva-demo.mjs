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
    // SEGMEN 02: Pengajuan Mitra Faskes (/pengajuan-mitra)
    // =========================================================================
    await runSegment('02', async () => {
      await page.goto(`${BASE_URL}/pengajuan-mitra`, { waitUntil: 'networkidle' })
      await waitMs(1200)

      // Step 1: Data Faskes
      await moveAndType(page.locator('#facilityName'), 'KLINIK UTAMA SEHAT JIWA NUSANTARA', 600)
      await moveAndType(page.locator('#city'), 'YOGYAKARTA', 500)
      await moveAndType(page.locator('#licenseNumber'), '3471099/KEMENKES/KL-U/2026', 600)
      await moveAndType(
        page.locator('#address'),
        'Jl. Kaliurang Km 6.5 No. 48, Depok, Sleman, DIY 55281',
        700,
      )
      await moveAndClick(page.getByRole('button', { name: /Lanjutkan/i }), 1200)

      // Step 2: PIC & Layanan
      await moveAndType(page.locator('#picName'), 'dr. Nadia Kusumawardhani, Sp.KJ', 600)
      await moveAndType(page.locator('#picRole'), 'Kepala Instalasi Kesehatan Jiwa', 500)
      await moveAndType(page.locator('#phone'), '081234567899', 500)
      await moveAndType(page.locator('#estimatedPsychologists'), '6', 400)
      await moveAndType(page.locator('#operatingHours'), 'Senin - Sabtu, 08.00 - 17.00 WIB', 600)
      await moveAndClick(page.getByRole('button', { name: /Lanjutkan/i }), 1200)

      // Step 3: Akun & Kirim
      await moveAndType(page.locator('#apply-email'), 'mitra@sehatjiwanusantara.co.id', 600)
      await moveAndType(page.locator('#apply-password'), 'mitra12345', 600)
      await moveAndType(
        page.locator('#notes'),
        'Siap menerima rujukan pasien skrining DASS-21 tingkat sedang hingga berat.',
        700,
      )
      await moveAndClick(page.getByRole('button', { name: /Kirim Pengajuan Mitra/i }), 2200)
      await moveAndClick(page.getByRole('link', { name: /Ke Halaman Masuk/i }), 1200)
    })

    // =========================================================================
    // SEGMEN 03: Login & Cek Status Mitra (/login)
    // =========================================================================
    await runSegment('03', async () => {
      if (!page.url().includes('/login')) {
        await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle' })
      }
      await waitMs(1000)

      // 1. Cek Akun Mitra Pending
      await moveAndClick(page.getByRole('button', { name: /Buka daftar akun demo|Akun Demo/i }), 900)
      await moveAndClick(page.getByRole('button', { name: /Mitra Faskes \(Pending\)/i }), 800)
      await moveAndClick(page.getByRole('button', { name: /^Masuk$/i }), 2500)
      await page.keyboard.press('Escape')
      await waitMs(800)

      // 2. Cek Akun Mitra Ditolak / Revisi
      await moveAndClick(page.getByRole('button', { name: /Buka daftar akun demo|Akun Demo/i }), 900)
      await moveAndClick(
        page.getByRole('button', { name: /Mitra Faskes \(Ditolak \/ Revisi\)/i }),
        800,
      )
      await moveAndClick(page.getByRole('button', { name: /^Masuk$/i }), 2800)
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

      // Hover di beberapa kartu KPI & Chart
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
    // SEGMEN 05: Admin Verifikasi Mitra Faskes (/admin/partners)
    // =========================================================================
    await runSegment('05', async () => {
      await moveAndClick(
        page.locator('aside button, nav button').filter({ hasText: /Mitra Faskes/i }),
        1400,
      )
      if (!page.url().includes('/admin/partners')) {
        await page.goto(`${BASE_URL}/admin/partners`, { waitUntil: 'networkidle' })
      }
      await waitMs(1200)

      // Klik filter Pending
      await moveAndClick(page.getByRole('button', { name: /Pending \(/i }), 1500)

      // Pilih faskes pertama di list antrean kiri
      const partnerCards = page.locator('.divide-y > button, .divide-y > div button').first()
      await moveAndClick(partnerCards, 1500)

      // Scroll sedikit melihat detail izin operasional lalu klik Setujui
      await smoothScrollTo(220, 900)
      await waitMs(1500)
      await moveAndClick(
        page.getByRole('button', { name: /Setujui & Aktifkan Akun Mitra/i }),
        2500,
      )
      await smoothScrollTo(0, 800)
    })

    // =========================================================================
    // SEGMEN 06: Admin Verifikasi & Simulasi Psikolog (/admin/psychologists)
    // =========================================================================
    await runSegment('06', async () => {
      await moveAndClick(
        page.locator('aside button, nav button').filter({ hasText: /Psikolog/i }),
        1400,
      )
      if (!page.url().includes('/admin/psychologists')) {
        await page.goto(`${BASE_URL}/admin/psychologists`, { waitUntil: 'networkidle' })
      }
      await waitMs(1200)

      // Buka modal Simulasi Pendaftaran & Upgrade Mobile
      await moveAndClick(
        page.getByRole('button', { name: /Simulasi Pendaftaran & Upgrade/i }),
        1400,
      )
      const nameInput = page.locator('input[placeholder*="Rania"], input[placeholder*="Dika"]').first()
      await moveAndType(nameInput, 'Rania Putri Maharani, M.Psi., Psikolog', 600)
      const cityInput = page.locator('input[placeholder="SEMARANG"]').first()
      await moveAndType(cityInput, 'BANDUNG', 500)
      await moveAndClick(
        page.getByRole('button', { name: /Kirim Pendaftaran Relawan/i }),
        1800,
      )

      // Klik tab/filter Antrean Tindakan jika ada
      const pendingTab = page.locator('button').filter({ hasText: /Antrean Tindakan|Perlu Tindakan|Pending/i })
      if ((await pendingTab.count()) > 0) {
        await moveAndClick(pendingTab.first(), 1400)
      }

      // Buka detail psikolog
      const detailBtn = page
        .getByRole('button', { name: /Tinjau Berkas|Detail|Periksa|Verifikasi/i })
        .first()
      if (!(await moveAndClick(detailBtn, 1800))) {
        const tableRowBtn = page.locator('table tbody tr button').first()
        await moveAndClick(tableRowBtn, 1800)
      }

      // Setujui atau tutup modal detail psikolog
      const approvePsyBtn = page.getByRole('button', {
        name: /Setujui & Aktifkan Akun|Setujui Upgrade/i,
      })
      if ((await approvePsyBtn.count()) > 0) {
        await moveAndClick(approvePsyBtn.first(), 2200)
      } else {
        await page.keyboard.press('Escape')
        await waitMs(1000)
      }
    })

    // =========================================================================
    // SEGMEN 07: Admin Triage Rujukan Klinis (/admin/referrals)
    // =========================================================================
    await runSegment('07', async () => {
      await moveAndClick(
        page.locator('aside button, nav button').filter({ hasText: /Rujukan/i }),
        1400,
      )
      if (!page.url().includes('/admin/referrals')) {
        await page.goto(`${BASE_URL}/admin/referrals`, { waitUntil: 'networkidle' })
      }
      await waitMs(1400)

      // Filter Belum Ditugaskan
      const unassignedTab = page.locator('button').filter({ hasText: /Belum Ditugaskan/i })
      if ((await unassignedTab.count()) > 0) {
        await moveAndClick(unassignedTab.first(), 1200)
      }

      // Klik tombol Pilih / Tugaskan Psikolog pada kartu rujukan
      const openDrawerBtn = page
        .getByRole('button', { name: /Pilih Psikolog|Tugaskan|Ubah Penugasan/i })
        .first()
      await moveAndClick(openDrawerBtn, 1800)

      // Di dalam ReferralAssignmentDrawer, klik Tugaskan Psikolog
      const assignBtn = page.getByRole('button', { name: /Tugaskan Psikolog/i }).first()
      await moveAndClick(assignBtn, 2400)
    })

    // =========================================================================
    // SEGMEN 08: Admin Pengguna & Transaksi Koin (/admin/users-coins)
    // =========================================================================
    await runSegment('08', async () => {
      await moveAndClick(
        page.locator('aside button, nav button').filter({ hasText: /Pengguna & Koin/i }),
        1400,
      )
      if (!page.url().includes('/admin/users-coins')) {
        await page.goto(`${BASE_URL}/admin/users-coins`, { waitUntil: 'networkidle' })
      }
      await waitMs(1400)

      // Cari pengguna di sub-tab Pengguna Aplikasi
      const searchInput = page.locator('input[type="search"], input[placeholder*="Cari"]').first()
      await moveAndType(searchInput, 'EVA', 1400)
      await searchInput.fill('')
      await waitMs(1000)

      // Pindah ke sub-tab Riwayat Transaksi Koin
      await moveAndClick(
        page.getByRole('button', { name: /Riwayat Transaksi Koin/i }),
        2200,
      )
      await smoothScrollTo(280, 1000)
      await waitMs(1800)
      await smoothScrollTo(0, 800)
    })

    // =========================================================================
    // SEGMEN 09: Admin CMS Konten & Katalog Koin (/admin/content-config)
    // =========================================================================
    await runSegment('09', async () => {
      await moveAndClick(
        page.locator('aside button, nav button').filter({ hasText: /Konten|Konfigurasi/i }),
        1400,
      )
      if (!page.url().includes('/admin/content-config')) {
        await page.goto(`${BASE_URL}/admin/content-config`, { waitUntil: 'networkidle' })
      }
      await waitMs(1500)

      // Sub-tab 1: Misi Koping & Krisis (Mobile)
      await smoothScrollTo(250, 900)
      await waitMs(1500)
      await smoothScrollTo(0, 700)

      // Sub-tab 2: Kurs & Paket Koin
      await moveAndClick(page.getByRole('button', { name: /Kurs & Paket Koin/i }), 2200)
      await smoothScrollTo(240, 900)
      await waitMs(1400)
      await smoothScrollTo(0, 700)

      // Sub-tab 3: Waitlist & FAQ (Website)
      await moveAndClick(page.getByRole('button', { name: /Waitlist & FAQ/i }), 2200)
      await smoothScrollTo(260, 900)
      await waitMs(1400)
      await smoothScrollTo(0, 700)

      // Logout Admin
      await moveAndClick(page.getByRole('button', { name: /Keluar/i }), 1500)
    })

    // =========================================================================
    // SEGMEN 10: Portal Mitra Faskes — Triage Rujukan Pasien (/mitra/referrals)
    // =========================================================================
    await runSegment('10', async () => {
      if (!page.url().includes('/login')) {
        await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle' })
      }
      await moveAndClick(page.getByRole('button', { name: /Buka daftar akun demo|Akun Demo/i }), 800)
      await moveAndClick(
        page.getByRole('button', { name: /Mitra Faskes \(Terverifikasi\)/i }),
        800,
      )
      await moveAndClick(page.getByRole('button', { name: /^Masuk$/i }), 1800)

      // Toggle status menerima rujukan pasien2x agar terlihat interaktif
      const toggleAcceptBtn = page.getByRole('button', {
        name: /Menerima Rujukan Pasien|Penerimaan Rujukan Dijeda/i,
      })
      await moveAndClick(toggleAcceptBtn, 1200)
      await moveAndClick(toggleAcceptBtn, 1200)

      // Buka drawer penugasan rujukan pasien di sisi Mitra
      const assignPartnerBtn = page
        .getByRole('button', { name: /Pilih Psikolog|Tugaskan|Ubah Penugasan/i })
        .first()
      if (await moveAndClick(assignPartnerBtn, 1800)) {
        const confirmPsyBtn = page.getByRole('button', { name: /Tugaskan Psikolog/i }).first()
        if ((await confirmPsyBtn.count()) > 0) {
          await moveAndClick(confirmPsyBtn, 2200)
        } else {
          await page.keyboard.press('Escape')
          await waitMs(1000)
        }
      }
    })

    // =========================================================================
    // SEGMEN 11: Portal Mitra Faskes — Manajemen Psikolog (/mitra/psychologists)
    // =========================================================================
    await runSegment('11', async () => {
      await moveAndClick(page.getByRole('link', { name: /Manajemen Psikolog/i }), 1500)
      if (!page.url().includes('/mitra/psychologists')) {
        await page.goto(`${BASE_URL}/mitra/psychologists`, { waitUntil: 'networkidle' })
      }
      await waitMs(1200)

      // Klik Tambah Psikolog
      await moveAndClick(page.getByRole('button', { name: /Tambah Psikolog/i }), 1400)

      await moveAndType(
        page.locator('input[placeholder*="Ayu Kartika"]'),
        'drg. Sinta Maharani, M.Psi., Psikolog',
        600,
      )
      await moveAndType(
        page.locator('input[placeholder*="20190412"]'),
        '20220915-2027-02-1108',
        500,
      )
      await moveAndType(
        page.locator('input[placeholder*="Senin, Rabu"]'),
        'Selasa, Kamis, Sabtu (09.00 - 15.00 WIB)',
        600,
      )

      // Pilih 2 spesialisasi
      const specChip = page.locator('[role="dialog"] button').filter({
        hasText: /Kecemasan|Depresi|Trauma|Keluarga/i,
      })
      if ((await specChip.count()) > 0) {
        await moveAndClick(specChip.first(), 600)
      }

      // Isi tarif koin sesi
      const feeInput = page.locator('input[placeholder*="Contoh: 50"]')
      if ((await feeInput.count()) > 0) {
        await moveAndType(feeInput, '60', 500)
      }

      await moveAndClick(page.getByRole('button', { name: /Simpan Data Psikolog/i }), 2200)
    })

    // =========================================================================
    // SEGMEN 12: Portal Mitra Faskes — Profil Faskes (/mitra/profile)
    // =========================================================================
    await runSegment('12', async () => {
      await moveAndClick(page.getByRole('link', { name: /Profil Faskes/i }), 1500)
      if (!page.url().includes('/mitra/profile')) {
        await page.goto(`${BASE_URL}/mitra/profile`, { waitUntil: 'networkidle' })
      }
      await waitMs(1500)
      await smoothScrollTo(260, 1000)
      await waitMs(1800)
      await smoothScrollTo(0, 900)

      const saveProfileBtn = page.getByRole('button', { name: /Simpan Perubahan|Simpan Profil/i })
      if ((await saveProfileBtn.count()) > 0) {
        await moveAndClick(saveProfileBtn.first(), 1600)
      }

      await moveAndClick(page.getByRole('button', { name: /Keluar/i }), 1400)
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

