import { generateCertificateSvgUri } from './certificateSvgTemplates'
import type { SimulateMobilePsychologistInput } from '@/types/api/contracts'
import type { Psychologist, PsychologistCertificate } from '@/types/domain/portal'

export function buildPsychologistCertificates(params: {
  fullName: string
  strNumber: string
  sipNumber?: string | null
  association: string
  city?: string
  education?: string
  verified?: boolean
}): PsychologistCertificate[] {
  const slug = params.fullName
    .trim()
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .slice(0, 24)
  const region = params.city?.trim() || 'INDONESIA'
  const verified = Boolean(params.verified)

  const docs: PsychologistCertificate[] = [
    {
      id: `doc-str-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      docType: 'STR HIMPSI',
      title: 'Surat Tanda Registrasi Psikolog Klinis (STR-PK)',
      documentNumber: params.strNumber,
      issuedBy: `${params.association} / Kemenkes RI`,
      issuedYear: '2024',
      validUntil: '2029-12-31',
      fileName: `STR_PK_${slug}.pdf`,
      fileSize: '980 KB',
      verified,
      imageUrl: generateCertificateSvgUri({
        docType: 'STR HIMPSI',
        title: 'Surat Tanda Registrasi Psikolog Klinis (STR-PK)',
        documentNumber: params.strNumber,
        issuedBy: `${params.association} / Kemenkes RI`,
        holderName: params.fullName,
        validUntil: '2029-12-31',
      }),
    },
  ]

  if (params.sipNumber?.trim()) {
    docs.push({
      id: `doc-sipp-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      docType: 'SIPP',
      title: `Surat Izin Praktik Psikologi (SIPP) : ${region}`,
      documentNumber: params.sipNumber.trim(),
      issuedBy: `HIMPSI Wilayah ${region}`,
      issuedYear: '2024',
      validUntil: '2029-12-31',
      fileName: `SIPP_${slug}.pdf`,
      fileSize: '1.3 MB',
      verified,
      imageUrl: generateCertificateSvgUri({
        docType: 'SIPP',
        title: `Surat Izin Praktik Psikologi (SIPP) : ${region}`,
        documentNumber: params.sipNumber.trim(),
        issuedBy: `HIMPSI Wilayah ${region}`,
        holderName: params.fullName,
        validUntil: '2029-12-31',
      }),
    })
  }

  if (params.education?.trim()) {
    docs.push({
      id: `doc-ijz-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      docType: 'Ijazah Profesi',
      title: `Ijazah Profesi Psikolog : ${params.education.trim()}`,
      documentNumber: `IJZ-PSI-${Math.floor(1000 + Math.random() * 9000)}`,
      issuedBy: params.education.trim(),
      issuedYear: '2020',
      validUntil: 'Seumur Hidup',
      fileName: `Ijazah_Profesi_${slug}.pdf`,
      fileSize: '1.8 MB',
      verified,
      imageUrl: generateCertificateSvgUri({
        docType: 'Ijazah Profesi',
        title: `Ijazah Profesi Psikolog : ${params.education.trim()}`,
        documentNumber: `IJZ-PSI-${Math.floor(1000 + Math.random() * 9000)}`,
        issuedBy: params.education.trim(),
        holderName: params.fullName,
        validUntil: 'Seumur Hidup',
      }),
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
    phone: '081294810234',
    city: 'JAKARTA SELATAN',
    education: 'Magister Profesi Psikologi Klinis Universitas Indonesia',
    strNumber: 'STR-PK-2022-884120',
    sipNumber: '20220618-2027-01-1402',
    association: 'Himpunan Psikologi Indonesia (HIMPSI)',
    specializations: ['Kecemasan & Panik', 'Regulasi Emosi & Stres Akademik', 'Remaja & Mahasiswa'],
    yearsOfExperience: 5,
    bio: 'Psikolog klinis berfokus pada penanganan kecemasan akademik, quarter-life crisis, dan regulasi emosi dewasa muda melalui telekonsultasi berbasis CBT.',
    verificationStatus: 'pending',
    isOnline: false,
    bufferTimeMinutes: 10,
    practiceSchedule: 'Senin - Jumat (16.00 - 21.00 WIB)',
    status: 'inactive',
    submittedAt: '2026-11-17',
    documents: [
      {
        id: 'doc-101',
        docType: 'STR HIMPSI',
        title: 'Surat Tanda Registrasi Psikolog Klinis (STR-PK)',
        documentNumber: 'STR-PK-2022-884120',
        issuedBy: 'Ikatan Psikolog Klinis (IPK) Indonesia / Kemenkes',
        issuedYear: '2022',
        validUntil: '2027-06-18',
        fileName: 'STR_PK_Larasati_Kusumawardhani.pdf',
        fileSize: '980 KB',
        verified: true,
      },
      {
        id: 'doc-102',
        docType: 'SIPP',
        title: 'Surat Izin Praktik Psikologi (SIPP) HIMPSI Jaya',
        documentNumber: '20220618-2027-01-1402',
        issuedBy: 'HIMPSI Wilayah DKI Jakarta',
        issuedYear: '2022',
        validUntil: '2027-06-18',
        fileName: 'SIPP_Larasati_Kusumawardhani_2027.pdf',
        fileSize: '1.4 MB',
        verified: true,
      },
      {
        id: 'doc-103',
        docType: 'Ijazah Profesi',
        title: 'Ijazah & Sumpah Profesi Magister Psikologi Klinis',
        documentNumber: 'IJZ-UI-PSI-2021-0094',
        issuedBy: 'Fakultas Psikologi Universitas Indonesia',
        issuedYear: '2021',
        validUntil: 'Seumur Hidup',
        fileName: 'Ijazah_Profesi_UI_Larasati.pdf',
        fileSize: '2.1 MB',
        verified: false,
      },
    ],
  },
  {
    id: 'psy-mandiri-2',
    fullName: 'Farhan Syahputra',
    titleDegree: 'M.Psi., Psikolog',
    email: 'farhan.psi@konselingmandiri.id',
    phone: '081227891033',
    city: 'YOGYAKARTA',
    education: 'Magister Profesi Psikologi Klinis Universitas Gadjah Mada',
    strNumber: 'STR-PK-2018-441092',
    sipNumber: '20180522-2028-01-0312',
    association: 'Himpunan Psikologi Indonesia (HIMPSI)',
    specializations: ['Remaja & Mahasiswa', 'Relasi & Keluarga', 'Kecemasan & Panik'],
    yearsOfExperience: 8,
    bio: 'Praktisi telekonseling psikologi klinis dengan pendekatan Acceptance and Commitment Therapy (ACT) untuk dewasa muda dan mahasiswa.',
    verificationStatus: 'verified',
    verificationNotes: 'STR-PK dan SIPP aktif diverifikasi melalui direktori resmi HIMPSI.',
    verifiedAt: '2026-11-12T09:15:00Z',
    isOnline: true,
    bufferTimeMinutes: 10,
    practiceSchedule: 'Senin - Sabtu (18.00 - 21.30 WIB)',
    status: 'active',
    submittedAt: '2026-11-10',
    reviewedAt: '2026-11-12',
    documents: [
      {
        id: 'doc-201',
        docType: 'STR HIMPSI',
        title: 'Surat Tanda Registrasi Psikolog Klinis',
        documentNumber: 'STR-PK-2018-441092',
        issuedBy: 'IPK Indonesia / Kemenkes RI',
        issuedYear: '2023',
        validUntil: '2028-05-22',
        fileName: 'STR_Farhan_Syahputra.pdf',
        fileSize: '920 KB',
        verified: true,
      },
      {
        id: 'doc-202',
        docType: 'SIPP',
        title: 'Surat Izin Praktik Psikologi (SIPP) DIY',
        documentNumber: '20180522-2028-01-0312',
        issuedBy: 'HIMPSI Wilayah DI Yogyakarta',
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
    phone: '081320189400',
    city: 'BANDUNG',
    education: 'Magister Profesi Psikologi Klinis Universitas Padjadjaran',
    strNumber: 'STR-PK-2020-310844',
    sipNumber: '20201104-2025-02-0774',
    association: 'Ikatan Psikolog Klinis (IPK) Indonesia',
    specializations: ['Depresi & Mood', 'Trauma & Krisis', 'Kecemasan & Panik'],
    yearsOfExperience: 6,
    bio: 'Berpengalaman mendampingi klien dengan gangguan mood, burnout kerja, serta pemulihan trauma emosional.',
    verificationStatus: 'verified',
    verificationNotes: 'Kredensial lengkap dan terverifikasi.',
    verifiedAt: '2026-11-14T11:30:00Z',
    isOnline: true,
    bufferTimeMinutes: 15,
    practiceSchedule: 'Selasa - Minggu (09.00 - 15.00 WIB)',
    status: 'active',
    submittedAt: '2026-11-11',
    reviewedAt: '2026-11-14',
    documents: [
      {
        id: 'doc-301',
        docType: 'STR HIMPSI',
        title: 'Surat Tanda Registrasi Psikolog Klinis',
        documentNumber: 'STR-PK-2020-310844',
        issuedBy: 'IPK Indonesia / Kemenkes RI',
        issuedYear: '2024',
        validUntil: '2029-11-04',
        fileName: 'STR_Nadia_Pramesti.pdf',
        fileSize: '1.1 MB',
        verified: true,
      },
      {
        id: 'doc-302',
        docType: 'SIPP',
        title: 'Surat Izin Praktik Psikologi (SIPP) Jawa Barat',
        documentNumber: '20201104-2029-02-0774',
        issuedBy: 'HIMPSI Wilayah Jawa Barat',
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
    phone: '081331094821',
    city: 'SURABAYA',
    education: 'Magister Profesi Psikologi Universitas Airlangga',
    strNumber: 'STR-PK-2023-112940',
    sipNumber: '20230214-2028-01-0941',
    association: 'Himpunan Psikologi Indonesia (HIMPSI)',
    specializations: ['Depresi & Mood', 'Regulasi Emosi & Stres Akademik'],
    yearsOfExperience: 3,
    bio: 'Fokus layanan konseling daring untuk manajemen stres pekerja muda dan regulasi emosi.',
    verificationStatus: 'need_revision',
    verificationNotes:
      'Scan halaman belakang SIPP belum terbaca jelas dan nomor registrasi belum sinkron dengan lampiran PDF.',
    isOnline: false,
    bufferTimeMinutes: 10,
    practiceSchedule: 'Senin, Rabu, Jumat (19.00 - 21.00 WIB)',
    status: 'inactive',
    submittedAt: '2026-11-15',
    reviewedAt: '2026-11-16',
    documents: [
      {
        id: 'doc-401',
        docType: 'STR HIMPSI',
        title: 'Surat Tanda Registrasi Psikolog Klinis',
        documentNumber: 'STR-PK-2023-112940',
        issuedBy: 'IPK Indonesia / Kemenkes RI',
        issuedYear: '2023',
        validUntil: '2028-02-14',
        fileName: 'STR_Dimas_Wicaksono.pdf',
        fileSize: '960 KB',
        verified: true,
      },
      {
        id: 'doc-402',
        docType: 'SIPP',
        title: 'Surat Izin Praktik Psikologi (SIPP) Jawa Timur',
        documentNumber: '20230214-2028-01-0941',
        issuedBy: 'HIMPSI Wilayah Jawa Timur',
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
    phone: '081588990011',
    city: 'SEMARANG',
    education: 'Magister Profesi Psikologi Universitas Diponegoro',
    strNumber: 'STR-PK-2017-004192',
    sipNumber: null,
    association: 'Himpunan Psikologi Indonesia (HIMPSI)',
    specializations: ['Relasi & Keluarga'],
    yearsOfExperience: 4,
    verificationStatus: 'rejected',
    verificationNotes:
      'Masa berlaku STR telah kedaluwarsa per Desember 2024 dan belum melampirkan pembaruan STR aktif dari KTKI/HIMPSI.',
    isOnline: false,
    bufferTimeMinutes: 10,
    practiceSchedule: 'Sabtu - Minggu (09.00 - 14.00 WIB)',
    status: 'inactive',
    submittedAt: '2026-11-13',
    reviewedAt: '2026-11-14',
    documents: [
      {
        id: 'doc-501',
        docType: 'STR HIMPSI',
        title: 'Surat Tanda Registrasi Psikolog Klinis (Kedaluwarsa)',
        documentNumber: 'STR-PK-2017-004192',
        issuedBy: 'HIMPSI / Kemenkes RI',
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
  const strNumber = input.strNumber.trim().toUpperCase()
  const sipNumber = input.sippNumber?.trim().toUpperCase() || null
  const association = input.association?.trim() || 'Himpunan Psikologi Indonesia (HIMPSI)'
  const city = input.city.trim().toUpperCase()

  const documents = buildPsychologistCertificates({
    fullName: `${fullName}, ${titleDegree}`,
    strNumber,
    sipNumber,
    association,
    city,
    education: input.education,
    verified: false,
  })

  return {
    id: `psy-mandiri-${Date.now()}`,
    fullName,
    titleDegree,
    email: input.email.trim(),
    phone: input.phone.trim(),
    city,
    education: input.education.trim(),
    strNumber,
    sipNumber,
    association,
    specializations: input.specializations,
    yearsOfExperience: input.yearsOfExperience ?? 3,
    bio: input.bio?.trim() || 'Psikolog profesional mandiri siap melayani sesi telekonsultasi online 30 menit.',
    certificateDocUrl: documents[0]?.fileName ?? null,
    verificationStatus: 'pending',
    isOnline: false,
    bufferTimeMinutes: 10,
    practiceSchedule: input.practiceSchedule.trim(),
    status: 'inactive',
    submittedAt: today,
    documents,
  }
}
