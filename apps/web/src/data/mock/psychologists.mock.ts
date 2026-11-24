import { generateCertificateSvgUri } from './certificateSvgTemplates'
import type { SimulateMobilePsychologistInput } from '@/types/api/contracts'
import type { Psychologist, PsychologistCertificate } from '@/types/domain/portal'

function isRenderableImageUrl(url?: string | null): url is string {
  if (!url) return false
  const trimmed = url.trim()
  if (trimmed.startsWith('data:image/')) return true
  if (!/^https?:\/\/|^\//i.test(trimmed)) return false
  return /\.(png|jpe?g|webp|gif|svg)(\?.*)?$/i.test(trimmed) || trimmed.startsWith('https://') || trimmed.startsWith('http://')
}

export function buildPsychologistCertificates(params: {
  fullName: string
  strNumber?: string | null
  strIssuedBy?: string | null
  strValidUntil?: string | null
  strDocUrl?: string | null
  strVerified?: boolean
  strDocId?: string
  sipNumber?: string | null
  sipIssuedBy?: string | null
  sipValidUntil?: string | null
  sipDocUrl?: string | null
  sipVerified?: boolean
  sipDocId?: string
  association: string
  education?: string | null
  verified?: boolean
}): PsychologistCertificate[] {
  const slug = params.fullName
    .trim()
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .slice(0, 24)
  const fallbackVerified = Boolean(params.verified)
  const docs: PsychologistCertificate[] = []

  if (params.strNumber?.trim()) {
    const strNum = params.strNumber.trim().toUpperCase()
    const strIssuer = params.strIssuedBy?.trim() || `${params.association} / Kemenkes RI`
    const strValid = params.strValidUntil?.trim() || 'Seumur Hidup (UU Kesehatan No. 17/2023)'
    const strPreviewUrl = isRenderableImageUrl(params.strDocUrl)
      ? params.strDocUrl.trim()
      : generateCertificateSvgUri({
          docType: 'STR HIMPSI',
          title: 'Surat Tanda Registrasi Psikolog Klinis (STR-PK)',
          documentNumber: strNum,
          issuedBy: strIssuer,
          holderName: params.fullName,
          validUntil: strValid,
        })
    docs.push({
      id: params.strDocId ?? `doc-str-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      docType: 'STR HIMPSI',
      title: 'Surat Tanda Registrasi Psikolog Klinis (STR-PK)',
      documentNumber: strNum,
      issuedBy: strIssuer,
      issuedYear: '2024',
      validUntil: strValid,
      fileName: params.strDocUrl?.trim() || `STR_PK_${slug}.pdf`,
      fileSize: '980 KB',
      verified: params.strVerified ?? fallbackVerified,
      imageUrl: strPreviewUrl,
    })
  }

  if (params.sipNumber?.trim()) {
    const sipNum = params.sipNumber.trim().toUpperCase()
    const sipIssuer = params.sipIssuedBy?.trim() || 'Dinas Kesehatan Kabupaten / Kota'
    const sipValid = params.sipValidUntil?.trim() || '2029-12-31'
    const sipPreviewUrl = isRenderableImageUrl(params.sipDocUrl)
      ? params.sipDocUrl.trim()
      : generateCertificateSvgUri({
          docType: 'SIPP',
          title: 'Surat Izin Praktik Psikologi (SIPP)',
          documentNumber: sipNum,
          issuedBy: sipIssuer,
          holderName: params.fullName,
          validUntil: sipValid,
        })
    docs.push({
      id: params.sipDocId ?? `doc-sipp-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      docType: 'SIPP',
      title: 'Surat Izin Praktik Psikologi (SIPP)',
      documentNumber: sipNum,
      issuedBy: sipIssuer,
      issuedYear: '2024',
      validUntil: sipValid,
      fileName: params.sipDocUrl?.trim() || `SIPP_${slug}.pdf`,
      fileSize: '1.3 MB',
      verified: params.sipVerified ?? fallbackVerified,
      imageUrl: sipPreviewUrl,
    })
  }

  return docs
}

const RAW_PSYCHOLOGISTS: Psychologist[] = [
  {
    id: 'psy-mandiri-1',
    fullName: 'Larasati Kusumawardhani',
    titleDegree: 'M.Psi., Psikolog',
    email: 'larasati.psi@praktikmandiri.id',
    education: 'S2 Magister Psikologi Profesi (Psikolog Klinis)',
    strNumber: 'STR-PK-2022-884120',
    sipNumber: '20220618-2027-01-1402',
    association: 'Himpunan Psikologi Indonesia (HIMPSI)',
    specializations: ['Kecemasan Dewasa', 'Trauma & Regulasi Emosi', 'Quarter-life Crisis'],
    yearsOfExperience: 5,
    verificationStatus: 'pending',
    isOnline: false,
    bufferTimeMinutes: 10,
    status: 'inactive',
    submittedAt: '2026-11-17',
    documents: [
      {
        id: 'doc-101',
        docType: 'STR HIMPSI',
        title: 'Surat Tanda Registrasi Psikolog Klinis (STR-PK)',
        documentNumber: 'STR-PK-2022-884120',
        issuedBy: 'Kemenkes RI / KTKI (Konsil Tenaga Kesehatan Indonesia)',
        issuedYear: '2022',
        validUntil: 'Seumur Hidup (UU Kesehatan No. 17/2023)',
        fileName: 'STR_PK_Larasati_Kusumawardhani.pdf',
        fileSize: '980 KB',
        verified: true,
      },
      {
        id: 'doc-102',
        docType: 'SIPP',
        title: 'Surat Izin Praktik Psikologi (SIPP)',
        documentNumber: '20220618-2027-01-1402',
        issuedBy: 'Dinas Kesehatan Kabupaten / Kota',
        issuedYear: '2022',
        validUntil: '2027-06-18',
        fileName: 'SIPP_Larasati_Kusumawardhani_2027.pdf',
        fileSize: '1.4 MB',
        verified: true,
      },
    ],
  },
  {
    id: 'psy-mandiri-2',
    fullName: 'Farhan Syahputra',
    titleDegree: 'M.Psi., Psikolog',
    email: 'farhan.psi@konselingmandiri.id',
    education: 'S2 Magister Psikologi Profesi (Psikolog Klinis)',
    strNumber: 'STR-PK-2018-441092',
    sipNumber: '20180522-2028-01-0312',
    association: 'Himpunan Psikologi Indonesia (HIMPSI)',
    specializations: ['Konseling Remaja & Akademik', 'Hubungan & Komunikasi', 'Kecemasan Dewasa'],
    yearsOfExperience: 7,
    verificationStatus: 'verified',
    verificationNotes: 'STR-PK dan SIPP aktif diverifikasi melalui direktori resmi HIMPSI.',
    verifiedAt: '2026-11-12T09:15:00Z',
    isOnline: true,
    bufferTimeMinutes: 10,
    status: 'active',
    submittedAt: '2026-11-10',
    reviewedAt: '2026-11-12',
    documents: [
      {
        id: 'doc-201',
        docType: 'STR HIMPSI',
        title: 'Surat Tanda Registrasi Psikolog Klinis',
        documentNumber: 'STR-PK-2018-441092',
        issuedBy: 'Kemenkes RI / KTKI (Konsil Tenaga Kesehatan Indonesia)',
        issuedYear: '2023',
        validUntil: 'Seumur Hidup (UU Kesehatan No. 17/2023)',
        fileName: 'STR_Farhan_Syahputra.pdf',
        fileSize: '920 KB',
        verified: true,
      },
      {
        id: 'doc-202',
        docType: 'SIPP',
        title: 'Surat Izin Praktik Psikologi (SIPP)',
        documentNumber: '20180522-2028-01-0312',
        issuedBy: 'DPMPTSP (Dinas Penanaman Modal & Pelayanan Terpadu Satu Pintu)',
        issuedYear: '2023',
        validUntil: '2028-05-22',
        fileName: 'SIPP_Farhan_Syahputra_2028.pdf',
        fileSize: '1.5 MB',
        verified: true,
      },
    ],
  },
  {
    id: 'psy-mandiri-3',
    fullName: 'Nadia Pramesti',
    titleDegree: 'M.Psi., Psikolog',
    email: 'nadia.pramesti@klinikmind.id',
    education: 'S2 Magister Psikologi Profesi (Psikolog Klinis)',
    strNumber: 'STR-PK-2020-310844',
    sipNumber: '20201104-2025-02-0774',
    association: 'Ikatan Psikolog Klinis (IPK) Indonesia',
    specializations: ['Depresi & Suasana Hati', 'Trauma & Regulasi Emosi', 'Manajemen Stres & Burnout'],
    yearsOfExperience: 6,
    verificationStatus: 'verified',
    verificationNotes: 'Kredensial lengkap dan terverifikasi.',
    verifiedAt: '2026-11-14T11:30:00Z',
    isOnline: true,
    bufferTimeMinutes: 15,
    status: 'active',
    submittedAt: '2026-11-11',
    reviewedAt: '2026-11-14',
    documents: [
      {
        id: 'doc-301',
        docType: 'STR HIMPSI',
        title: 'Surat Tanda Registrasi Psikolog Klinis',
        documentNumber: 'STR-PK-2020-310844',
        issuedBy: 'Kemenkes RI / KTKI (Konsil Tenaga Kesehatan Indonesia)',
        issuedYear: '2024',
        validUntil: '2029-11-04',
        fileName: 'STR_Nadia_Pramesti.pdf',
        fileSize: '1.1 MB',
        verified: true,
      },
      {
        id: 'doc-302',
        docType: 'SIPP',
        title: 'Surat Izin Praktik Psikologi (SIPP)',
        documentNumber: '20201104-2029-02-0774',
        issuedBy: 'Dinas Kesehatan Kabupaten / Kota',
        issuedYear: '2024',
        validUntil: '2029-11-04',
        fileName: 'SIPP_Nadia_Pramesti.pdf',
        fileSize: '1.3 MB',
        verified: true,
      },
    ],
  },
  {
    id: 'psy-mandiri-4',
    fullName: 'Dimas Wicaksono',
    titleDegree: 'M.Psi., Psikolog',
    email: 'dimas.wicaksono@psikolog.id',
    education: 'S2 Magister Psikologi Profesi (Psikolog Klinis)',
    strNumber: 'STR-PK-2023-112940',
    sipNumber: '20230214-2028-01-0941',
    association: 'Himpunan Psikologi Indonesia (HIMPSI)',
    specializations: ['Depresi & Suasana Hati', 'Manajemen Stres & Burnout'],
    yearsOfExperience: 3,
    verificationStatus: 'rejected',
    verificationNotes:
      'Scan dokumen SIPP tidak jelas dan nomor registrasi tidak valid saat dicek pada pangkalan data HIMPSI.',
    isOnline: false,
    bufferTimeMinutes: 10,
    status: 'inactive',
    submittedAt: '2026-11-15',
    reviewedAt: '2026-11-16',
    documents: [
      {
        id: 'doc-401',
        docType: 'STR HIMPSI',
        title: 'Surat Tanda Registrasi Psikolog Klinis',
        documentNumber: 'STR-PK-2023-112940',
        issuedBy: 'Kemenkes RI / KTKI (Konsil Tenaga Kesehatan Indonesia)',
        issuedYear: '2023',
        validUntil: '2028-02-14',
        fileName: 'STR_Dimas_Wicaksono.pdf',
        fileSize: '960 KB',
        verified: true,
      },
      {
        id: 'doc-402',
        docType: 'SIPP',
        title: 'Surat Izin Praktik Psikologi (SIPP)',
        documentNumber: '20230214-2028-01-0941',
        issuedBy: 'Dinas Kesehatan Kabupaten / Kota',
        issuedYear: '2023',
        validUntil: '2028-02-14',
        fileName: 'SIPP_Dimas_Scan_Buram.pdf',
        fileSize: '840 KB',
        verified: false,
      },
    ],
  },
  {
    id: 'psy-mandiri-5',
    fullName: 'Raka Santoso',
    titleDegree: 'M.Psi., Psikolog',
    email: 'raka.santoso@konselor.id',
    education: 'S2 Magister Psikologi Terapan',
    strNumber: 'STR-PK-2017-004192',
    sipNumber: null,
    association: 'Himpunan Psikologi Indonesia (HIMPSI)',
    specializations: ['Hubungan & Komunikasi'],
    yearsOfExperience: 3,
    verificationStatus: 'rejected',
    verificationNotes:
      'Masa berlaku STR telah kedaluwarsa per Desember 2024 dan belum melampirkan pembaruan STR aktif dari KTKI/HIMPSI.',
    isOnline: false,
    bufferTimeMinutes: 10,
    status: 'inactive',
    submittedAt: '2026-11-13',
    reviewedAt: '2026-11-14',
    documents: [
      {
        id: 'doc-501',
        docType: 'STR HIMPSI',
        title: 'Surat Tanda Registrasi Psikolog Klinis (Kedaluwarsa)',
        documentNumber: 'STR-PK-2017-004192',
        issuedBy: 'Kementerian Kesehatan RI',
        issuedYear: '2019',
        validUntil: '2024-12-31',
        fileName: 'STR_Raka_Santoso_2019.pdf',
        fileSize: '890 KB',
        verified: false,
      },
    ],
  },
]

export const INITIAL_PSYCHOLOGISTS: Psychologist[] = RAW_PSYCHOLOGISTS.map((psy) => ({
  ...psy,
  documents: psy.documents?.map((doc) => ({
    ...doc,
    imageUrl:
      doc.imageUrl ||
      generateCertificateSvgUri({
        docType: doc.docType,
        title: doc.title,
        documentNumber: doc.documentNumber,
        issuedBy: doc.issuedBy,
        holderName: `${psy.fullName}, ${psy.titleDegree}`,
        validUntil: doc.validUntil,
      }),
  })),
}))

export function buildSimulatedMobilePsychologist(
  input: SimulateMobilePsychologistInput,
): Psychologist {
  const today = new Date().toISOString().slice(0, 10)
  const fullName = input.fullName.trim()
  const titleDegree = input.titleDegree?.trim() || 'M.Psi., Psikolog'
  const docType = input.documentType ?? 'both'
  const includeStr = docType === 'both' || docType === 'str'
  const includeSip = docType === 'both' || docType === 'sip'

  const strNumber = includeStr ? (input.strNumber?.trim().toUpperCase() ?? '') : ''
  const sipNumber = includeSip ? input.sippNumber?.trim().toUpperCase() || null : null
  const association = input.association?.trim() || 'Himpunan Psikologi Indonesia (HIMPSI)'

  const documents = buildPsychologistCertificates({
    fullName: `${fullName}, ${titleDegree}`,
    strNumber: strNumber || null,
    strIssuedBy: input.strIssuedBy,
    strValidUntil: input.strValidUntil,
    sipNumber,
    sipIssuedBy: input.sipIssuedBy,
    sipValidUntil: input.sipValidUntil,
    association,
    education: input.education,
    verified: false,
  })

  return {
    id: `psy-mandiri-${Date.now()}`,
    fullName,
    titleDegree,
    email: input.email.trim(),
    education: input.education.trim(),
    strNumber,
    sipNumber,
    association,
    specializations: input.specializations,
    yearsOfExperience: input.yearsOfExperience ?? 3,
    certificateDocUrl: documents[0]?.fileName ?? null,
    verificationStatus: 'pending',
    isOnline: false,
    bufferTimeMinutes: 10,
    status: 'inactive',
    submittedAt: today,
    documents,
  }
}
