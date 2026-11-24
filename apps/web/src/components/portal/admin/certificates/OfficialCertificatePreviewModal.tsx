import { Award, Download, Loader2, X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'
import { downloadCertificatePdf, type IssuedPsychologistCertificate } from '@/lib/portalStore'

interface OfficialCertificatePreviewModalProps {
  certificate: IssuedPsychologistCertificate | null
  isOpen: boolean
  onClose: () => void
  onError: (message: string) => void
}

function escapeXml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;')
}

function wrapText(text: string, maxLen: number): string[] {
  const words = text.split(/\s+/)
  const lines: string[] = []
  let current = ''
  for (const word of words) {
    if (`${current} ${word}`.trim().length > maxLen) {
      if (current) lines.push(current)
      current = word
    } else {
      current = `${current} ${word}`.trim()
    }
  }
  if (current) lines.push(current)
  return lines.slice(0, 4)
}

function buildOfficialCertificateSvgUri(cert: IssuedPsychologistCertificate): string {
  const accent = cert.badgeColor || '#2563EB'
  const isRevoked = cert.status === 'revoked'
  const watermark = isRevoked ? 'DICABUT' : 'TERVERIFIKASI EVA'
  const descLines = wrapText(cert.description, 78)

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 880 600" width="880" height="600">
    <rect width="880" height="600" fill="#FCFDFE"/>
    <rect x="18" y="18" width="844" height="564" rx="16" fill="none" stroke="${escapeXml(accent)}" stroke-width="4"/>
    <rect x="28" y="28" width="824" height="544" rx="12" fill="none" stroke="#CBD5E1" stroke-width="1.2" stroke-dasharray="6 4"/>
    <text x="440" y="320" text-anchor="middle" font-family="Arial, sans-serif" font-size="64" font-weight="900" fill="${isRevoked ? '#FEE2E2' : '#F1F5F9'}" letter-spacing="6" transform="rotate(-14 440 320)">${escapeXml(watermark)}</text>
    <text x="440" y="72" text-anchor="middle" font-family="Georgia, serif" font-size="11" font-weight="bold" fill="#64748B" letter-spacing="4">EKOSISTEM PSIKOLOGI DIGITAL EVA INDONESIA</text>
    <text x="440" y="106" text-anchor="middle" font-family="Georgia, serif" font-size="20" font-weight="bold" fill="${escapeXml(accent)}">${escapeXml(cert.title.toUpperCase())}</text>
    <text x="440" y="130" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#475569">${escapeXml(cert.subtitle)}</text>
    <line x1="250" y1="148" x2="630" y2="148" stroke="${escapeXml(accent)}" stroke-width="2"/>
    <text x="440" y="176" text-anchor="middle" font-family="'Courier New', monospace" font-size="12.5" font-weight="bold" fill="#0F172A">No: ${escapeXml(cert.certificateNumber)}  |  STR: ${escapeXml(cert.strNumber)}</text>
    <text x="440" y="220" text-anchor="middle" font-family="Georgia, serif" font-size="13" fill="#475569">Dengan bangga diberikan kepada:</text>
    <text x="440" y="262" text-anchor="middle" font-family="Georgia, serif" font-size="26" font-weight="bold" fill="#0F172A">${escapeXml(cert.recipientName)}</text>
    <line x1="220" y1="278" x2="660" y2="278" stroke="#94A3B8" stroke-width="1"/>
    <rect x="190" y="298" width="500" height="36" rx="8" fill="#EEF2FF" stroke="${escapeXml(accent)}" stroke-width="1.2"/>
    <text x="440" y="321" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" font-weight="bold" fill="${escapeXml(accent)}">Pencapaian: ${escapeXml(cert.milestoneCriteria)}</text>
    ${descLines
      .map(
        (line, i) =>
          `<text x="440" y="${368 + i * 20}" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#334155">${escapeXml(line)}</text>`,
      )
      .join('')}
    <text x="90" y="492" font-family="Arial, sans-serif" font-size="11.5" font-weight="bold" fill="#0F172A">Diterbitkan di Jakarta, ${escapeXml(cert.issueDateLabel)}</text>
    <text x="90" y="512" font-family="Arial, sans-serif" font-size="11" fill="#475569">Kategori: ${escapeXml(cert.categoryLabel)}</text>
    <text x="90" y="532" font-family="Arial, sans-serif" font-size="11" font-weight="bold" fill="${isRevoked ? '#B91C1C' : escapeXml(accent)}">Status: ${isRevoked ? 'DICABUT' : 'SAH &amp; TERVERIFIKASI'}</text>
    <circle cx="440" cy="505" r="40" fill="none" stroke="${escapeXml(accent)}" stroke-width="2.5"/>
    <circle cx="440" cy="505" r="33" fill="none" stroke="${escapeXml(accent)}" stroke-width="1"/>
    <text x="440" y="502" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" font-weight="bold" fill="${escapeXml(accent)}">EVA</text>
    <text x="440" y="518" text-anchor="middle" font-family="Arial, sans-serif" font-size="8" font-weight="bold" fill="${escapeXml(accent)}">OFFICIAL SEAL</text>
    <text x="690" y="478" text-anchor="middle" font-family="Arial, sans-serif" font-size="10.5" fill="#64748B">Ditandatangani secara elektronik:</text>
    <line x1="600" y1="514" x2="780" y2="514" stroke="#0F172A" stroke-width="1.2"/>
    <text x="690" y="530" text-anchor="middle" font-family="Arial, sans-serif" font-size="11.5" font-weight="bold" fill="#0F172A">Komite Kredensial Klinis EVA</text>
  </svg>`

  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`
}

export function OfficialCertificatePreviewModal({
  certificate,
  isOpen,
  onClose,
  onError,
}: OfficialCertificatePreviewModalProps) {
  const [downloading, setDownloading] = useState(false)
  useBodyScrollLock(isOpen && Boolean(certificate))

  useEffect(() => {
    if (!isOpen || !certificate) return
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [certificate, isOpen, onClose])

  if (!isOpen || !certificate) return null

  const svgUri = buildOfficialCertificateSvgUri(certificate)

  const handleDownload = async () => {
    if (downloading) return
    setDownloading(true)
    try {
      const { blob, filename } = await downloadCertificatePdf(certificate.id)
      const url = URL.createObjectURL(blob)
      const anchor = document.createElement('a')
      anchor.href = url
      anchor.download = filename
      document.body.appendChild(anchor)
      anchor.click()
      anchor.remove()
      URL.revokeObjectURL(url)
    } catch (err) {
      onError(err instanceof Error ? err.message : 'Gagal mengunduh file sertifikat resmi.')
    } finally {
      setDownloading(false)
    }
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={`Pratinjau Sertifikat ${certificate.certificateNumber}`}
      className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/75 p-4 backdrop-blur-xs"
      onClick={onClose}
    >
      <div
        className="relative flex max-h-[92dvh] w-full max-w-4xl flex-col overflow-hidden rounded-[16px] border border-[#E2E8F0] bg-white shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[#E2E8F0] px-5 py-3.5">
          <div className="flex min-w-0 items-center gap-2.5">
            <span
              aria-hidden="true"
              className="flex size-9 shrink-0 items-center justify-center rounded-[10px] bg-[#EEF0FF] text-primary"
            >
              <Award className="size-4.5" aria-hidden="true" />
            </span>
            <div className="min-w-0">
              <p className="truncate font-mono text-xs font-bold text-primary">
                {certificate.certificateNumber}
              </p>
              <h3 className="truncate text-sm font-bold text-ink">{certificate.recipientName}</h3>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              disabled={downloading}
              onClick={() => void handleDownload()}
              className="inline-flex min-h-11 cursor-pointer items-center gap-1.5 rounded-[8px] bg-primary px-3.5 text-xs font-semibold text-white hover:bg-primary-hover disabled:cursor-not-allowed disabled:opacity-60 sm:min-h-9"
            >
              {downloading ? (
                <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />
              ) : (
                <Download className="size-3.5" aria-hidden="true" />
              )}
              <span>Unduh PDF Resmi</span>
            </button>
            <button
              type="button"
              onClick={onClose}
              aria-label="Tutup pratinjau sertifikat"
              className="inline-flex min-h-11 min-w-11 cursor-pointer items-center justify-center rounded-[8px] border border-[#768396] text-ink-soft hover:bg-slate-50 hover:text-ink sm:size-9 sm:min-h-0 sm:min-w-0"
            >
              <X className="size-4" aria-hidden="true" />
            </button>
          </div>
        </div>

        <div className="overflow-auto bg-[#F1F5F9] p-4 sm:p-6">
          <img
            src={svgUri}
            width={880}
            height={600}
            alt={`Pratinjau sertifikat ${certificate.certificateNumber}`}
            className="mx-auto h-auto w-full max-w-3xl rounded-[10px] border border-[#768396] bg-white shadow-md"
          />
        </div>
      </div>
    </div>
  )
}
