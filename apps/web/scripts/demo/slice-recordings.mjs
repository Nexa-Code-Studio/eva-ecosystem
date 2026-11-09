#!/usr/bin/env node
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const WEB_ROOT = path.resolve(__dirname, '../..')
const RECORDINGS_DIR = path.join(WEB_ROOT, 'recordings')
const RAW_DIR = path.join(RECORDINGS_DIR, 'raw')
const CLIPS_DIR = path.join(RECORDINGS_DIR, 'clips')
const TIMESTAMPS_PATH = path.join(RECORDINGS_DIR, 'timestamps.json')

function parseArgs(argv) {
  let inputPath = null
  let offsetSec = 0
  let outputSubdir = null

  for (const arg of argv.slice(2)) {
    if (arg.startsWith('--input=')) {
      inputPath = arg.slice('--input='.length)
    } else if (arg.startsWith('--offset=')) {
      offsetSec = Number.parseFloat(arg.slice('--offset='.length)) || 0
    } else if (arg.startsWith('--out=')) {
      outputSubdir = arg.slice('--out='.length)
    } else if (!arg.startsWith('-')) {
      inputPath = arg
    }
  }

  return { inputPath, offsetSec, outputSubdir }
}

function findLatestRawVideo() {
  if (!fs.existsSync(RAW_DIR)) return null
  const files = fs
    .readdirSync(RAW_DIR)
    .filter((f) => f.endsWith('.webm') || f.endsWith('.mp4') || f.endsWith('.mkv'))
    .map((f) => {
      const fullPath = path.join(RAW_DIR, f)
      return { fullPath, mtimeMs: fs.statSync(fullPath).mtimeMs }
    })
    .sort((a, b) => b.mtimeMs - a.mtimeMs)

  return files[0]?.fullPath ?? null
}

function formatSeconds(sec) {
  const clamped = Math.max(0, sec)
  const hrs = Math.floor(clamped / 3600)
  const mins = Math.floor((clamped % 3600) / 60)
  const secs = (clamped % 60).toFixed(2)
  return `${String(hrs).padStart(2, '0')}:${String(mins).padStart(2, '0')}:${String(secs).padStart(5, '0')}`
}

function main() {
  const { inputPath: cliInput, offsetSec, outputSubdir } = parseArgs(process.argv)

  if (!fs.existsSync(TIMESTAMPS_PATH)) {
    console.error(`[ERROR] File timestamp tidak ditemukan di: ${TIMESTAMPS_PATH}`)
    console.error('Jalankan "npm run demo:record" terlebih dahulu untuk menghasilkan rekaman & timestamps.json.')
    process.exit(1)
  }

  const timestampsData = JSON.parse(fs.readFileSync(TIMESTAMPS_PATH, 'utf8'))
  const sourceVideo = cliInput
    ? path.resolve(process.cwd(), cliInput)
    : timestampsData.rawVideoPath && fs.existsSync(timestampsData.rawVideoPath)
      ? timestampsData.rawVideoPath
      : findLatestRawVideo()

  if (!sourceVideo || !fs.existsSync(sourceVideo)) {
    console.error('[ERROR] Video sumber tidak ditemukan.')
    console.error('Gunakan: npm run demo:slice -- /path/ke/rekaman-spectacle.mp4')
    process.exit(1)
  }

  const targetClipsDir = outputSubdir
    ? path.join(RECORDINGS_DIR, outputSubdir)
    : CLIPS_DIR

  fs.mkdirSync(targetClipsDir, { recursive: true })

  console.log('==============================================================')
  console.log('🎬 EVA Web Video Slicer (FFmpeg)')
  console.log(`📂 Sumber Video : ${sourceVideo}`)
  console.log(`📂 Folder Output: ${targetClipsDir}`)
  if (offsetSec !== 0) {
    console.log(`⏱️  Offset Waktu : ${offsetSec > 0 ? `+${offsetSec}` : offsetSec} detik`)
  }
  console.log('==============================================================')

  // Simpan juga full video MP4 jika sumbernya .webm dari Playwright
  const fullMp4Path = path.join(RECORDINGS_DIR, '00-full-eva-web-demo.mp4')
  if (!cliInput && sourceVideo.endsWith('.webm')) {
    console.log('\n[00/12] Mengonversi video utuh ke 00-full-eva-web-demo.mp4...')
    execFileSync(
      'ffmpeg',
      [
        '-y',
        '-i',
        sourceVideo,
        '-c:v',
        'libx264',
        '-preset',
        'fast',
        '-crf',
        '22',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        fullMp4Path,
      ],
      { stdio: 'ignore' },
    )
    console.log(`   ✅ Tersimpan: ${fullMp4Path}`)
  }

  const segments = timestampsData.segments ?? []
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i]
    const startSec = Math.max(0, Number(seg.startSec) + offsetSec)
    const endSec = Math.max(startSec + 1, Number(seg.endSec) + offsetSec)
    const durationSec = (endSec - startSec).toFixed(1)
    const outFile = path.join(targetClipsDir, seg.filename)

    console.log(
      `\n[${String(i + 1).padStart(2, '0')}/${String(segments.length).padStart(2, '0')}] Memotong ${seg.filename} (${formatSeconds(startSec)} -> ${formatSeconds(endSec)} | ${durationSec}s)...`,
    )

    execFileSync(
      'ffmpeg',
      [
        '-y',
        '-ss',
        startSec.toFixed(2),
        '-to',
        endSec.toFixed(2),
        '-i',
        sourceVideo,
        '-c:v',
        'libx264',
        '-preset',
        'fast',
        '-crf',
        '22',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        outFile,
      ],
      { stdio: 'ignore' },
    )

    console.log(`   ✅ Selesai: ${outFile}`)
  }

  console.log('\n==============================================================')
  console.log(`🎉 Seluruh ${segments.length} klip fitur berhasil dipotong ke:`)
  console.log(`   ${targetClipsDir}`)
  console.log('==============================================================')
}

main()

