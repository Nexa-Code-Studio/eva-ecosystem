/**
 * Generator Salinan Dokumen & Sertifikat Digital SVG Realistis
 * Menghasilkan data URI gambar vektor resolusi tinggi dengan bingkai ornamen,
 * lambang resmi, stempel digital, nomor registrasi, dan QR verifikasi.
 */

interface CertSvgOptions {
  docType:
    | 'SIPP'
    | 'STR HIMPSI'
    | 'Ijazah Profesi'
    | 'Sertifikat Klinis'
    | 'Sertifikat Pelatihan'
    | 'Bukti Kinerja Relawan'
  title: string
  documentNumber: string
  holderName: string
  issuedBy: string
  validUntil: string
  issuedYear?: string
}

export function generateCertificateSvgUri({
  docType,
  title,
  documentNumber,
  holderName,
  issuedBy,
  validUntil,
}: CertSvgOptions): string {
  const primaryColor =
    docType === 'SIPP'
      ? '#1E3A8A'
      : docType === 'STR HIMPSI'
        ? '#047857'
        : docType === 'Ijazah Profesi'
          ? '#831843'
          : docType === 'Bukti Kinerja Relawan'
            ? '#D97706'
            : '#4338CA'

  const sealColor =
    docType === 'SIPP'
      ? '#2563EB'
      : docType === 'STR HIMPSI'
        ? '#10B981'
        : docType === 'Bukti Kinerja Relawan'
          ? '#F59E0B'
          : '#BE185D'

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 560" width="800" height="560">
    <defs>
      <pattern id="certGrid" width="40" height="40" patternUnits="userSpaceOnUse">
        <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#E2E8F0" stroke-width="0.5" opacity="0.4"/>
      </pattern>
      <linearGradient id="headerGrad" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="${primaryColor}" stop-opacity="0.95" />
        <stop offset="100%" stop-color="#0F172A" stop-opacity="0.95" />
      </linearGradient>
    </defs>

    <!-- Background Canvas -->
    <rect width="800" height="560" fill="#FCFDFE"/>
    <rect width="800" height="560" fill="url(#certGrid)"/>

    <!-- Ornate Double Borders -->
    <rect x="20" y="20" width="760" height="520" fill="none" stroke="${primaryColor}" stroke-width="4" rx="12"/>
    <rect x="28" y="28" width="744" height="504" fill="none" stroke="${primaryColor}" stroke-dasharray="8 4" stroke-width="1.5" rx="8"/>
    <rect x="36" y="36" width="728" height="488" fill="none" stroke="#CBD5E1" stroke-width="0.8" rx="6"/>

    <!-- Corner Ornaments -->
    <g fill="${primaryColor}">
      <circle cx="28" cy="28" r="6"/>
      <circle cx="772" cy="28" r="6"/>
      <circle cx="28" cy="532" r="6"/>
      <circle cx="772" cy="532" r="6"/>
    </g>

    <!-- Watermark Logo Text in Background -->
    <text x="400" y="310" text-anchor="middle" font-family="Arial, sans-serif" font-size="64" font-weight="900" fill="#F1F5F9" letter-spacing="8" transform="rotate(-15 400 310)">TERVERIFIKASI</text>

    <!-- Header Section -->
    <text x="400" y="75" text-anchor="middle" font-family="Georgia, serif" font-size="12" font-weight="bold" fill="#64748B" letter-spacing="4">REPUBLIK INDONESIA</text>
    <text x="400" y="105" text-anchor="middle" font-family="Georgia, serif" font-size="20" font-weight="bold" fill="url(#headerGrad)" letter-spacing="1.5">${title.toUpperCase()}</text>
    <line x1="250" y1="120" x2="550" y2="120" stroke="${primaryColor}" stroke-width="2"/>
    <circle cx="400" cy="120" r="4" fill="${primaryColor}"/>

    <text x="400" y="142" text-anchor="middle" font-family="'Courier New', monospace" font-size="13" font-weight="bold" fill="#0F172A">Nomor Registrasi: ${documentNumber}</text>

    <!-- Main Content -->
    <text x="400" y="185" text-anchor="middle" font-family="Georgia, serif" font-size="13" fill="#475569">Diberikan secara sah kepada:</text>
    <text x="400" y="222" text-anchor="middle" font-family="Georgia, serif" font-size="22" font-weight="bold" fill="#0F172A">${holderName}</text>
    <line x1="220" y1="234" x2="580" y2="234" stroke="#94A3B8" stroke-width="1"/>

    <text x="400" y="265" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#334155" max-width="500">
      Sebagai bukti kualifikasi resmi ${docType} dalam menyelenggarakan pelayanan praktik psikologi klinis
    </text>
    <text x="400" y="286" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#334155">
      sesuai ketentuan hukum dan kode etik profesi psikologi yang berlaku di Indonesia.
    </text>

    <!-- Certificate Details Box -->
    <rect x="180" y="315" width="440" height="60" rx="8" fill="#F8FAFC" stroke="#E2E8F0" stroke-width="1.2"/>
    <text x="200" y="340" font-family="Arial, sans-serif" font-size="11" font-weight="bold" fill="#64748B">INSTANSI PENERBIT:</text>
    <text x="340" y="340" font-family="Arial, sans-serif" font-size="11" font-weight="bold" fill="#0F172A">${issuedBy}</text>
    <text x="200" y="360" font-family="Arial, sans-serif" font-size="11" font-weight="bold" fill="#64748B">MASA BERLAKU:</text>
    <text x="340" y="360" font-family="Arial, sans-serif" font-size="11" font-weight="bold" fill="#0F172A">Sampai ${validUntil}</text>

    <!-- Official Seal Stamp (SVG circular stamp) -->
    <g transform="translate(180, 410) rotate(-10)">
      <circle cx="45" cy="45" r="42" fill="none" stroke="${sealColor}" stroke-width="2.5" opacity="0.85"/>
      <circle cx="45" cy="45" r="37" fill="none" stroke="${sealColor}" stroke-dasharray="3 2" stroke-width="1.2" opacity="0.85"/>
      <path id="stampTextPath" d="M 12 45 A 33 33 0 1 1 78 45" fill="none"/>
      <text font-family="Arial, sans-serif" font-size="8.5" font-weight="bold" fill="${sealColor}" letter-spacing="1.5">
        <textPath href="#stampTextPath" startOffset="50%" text-anchor="middle">ORGANISASI PROFESI RESMI</textPath>
      </text>
      <text x="45" y="47" text-anchor="middle" font-family="Georgia, serif" font-size="13" font-weight="bold" fill="${sealColor}">VALID</text>
      <text x="45" y="60" text-anchor="middle" font-family="Arial, sans-serif" font-size="7.5" font-weight="bold" fill="${sealColor}">TERVERIFIKASI</text>
    </g>

    <!-- Digital QR Code Placeholder -->
    <rect x="575" y="405" width="75" height="75" rx="6" fill="#FFFFFF" stroke="#CBD5E1" stroke-width="1.2"/>
    <rect x="585" y="415" width="20" height="20" fill="#0F172A"/>
    <rect x="620" y="415" width="20" height="20" fill="#0F172A"/>
    <rect x="585" y="450" width="20" height="20" fill="#0F172A"/>
    <rect x="612" y="442" width="10" height="10" fill="#0F172A"/>
    <rect x="628" y="455" width="12" height="12" fill="#0F172A"/>
    <text x="612" y="493" text-anchor="middle" font-family="'Courier New', monospace" font-size="7" fill="#64748B">SCAN VERIFIKASI</text>

    <!-- Signatures Section -->
    <text x="400" y="430" text-anchor="middle" font-family="Georgia, serif" font-style="italic" font-size="15" fill="#1E293B">Dr. H. Bambang Soeprapto, M.Psi.</text>
    <line x1="310" y1="440" x2="490" y2="440" stroke="#0F172A" stroke-width="1"/>
    <text x="400" y="455" text-anchor="middle" font-family="Arial, sans-serif" font-size="10" font-weight="bold" fill="#475569">Ketua Majelis Psikologi Indonesia</text>
    <text x="400" y="470" text-anchor="middle" font-family="Arial, sans-serif" font-size="9" fill="#94A3B8">Dokumen Resmi Ditandatangani Secara Elektronik</text>
  </svg>`

  return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`
}

