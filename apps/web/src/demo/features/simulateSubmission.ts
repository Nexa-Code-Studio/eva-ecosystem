import { generateCertificateSvgUri } from '@/demo/data/certificateSvgTemplates'
import { loadPortalDb, savePortalDb } from '@/services/portal/storage'
import type { Psychologist, PsychologistCertificate, PsychologistRole } from '@/types/portal'

export interface SimulateMobilePsychologistInput {
  role?: 'relawan_biasa' | 'relawan_profesional'
  fullName: string
  sippNumber?: string
  strNumber?: string
  city: string
  education: string
  email: string
  phone: string
  practiceSchedule: string
  specializations: string[]
  sippValidUntil?: string
}

export function simulateMobilePsychologistSubmission(
  input: SimulateMobilePsychologistInput,
): Psychologist {
  const db = loadPortalDb()
  const today = new Date().toISOString().slice(0, 10)
  const slug = input.fullName
    .trim()
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .slice(0, 24)

  const role: PsychologistRole = input.role || 'relawan_profesional'
  const isBiasa = role === 'relawan_biasa'
  const sippNumber = isBiasa
    ? (input.sippNumber?.trim().toUpperCase() || 'NON-SIPP (Relawan Sebaya)')
    : (input.sippNumber?.trim().toUpperCase() || '20240812-2029-01-0992')
  const strNumber = isBiasa ? undefined : input.strNumber?.trim().toUpperCase()
  const city = input.city.trim().toUpperCase()
  const validUntil = input.sippValidUntil || '2029-12-31'

  const documents: PsychologistCertificate[] = isBiasa
    ? [
        {
          id: `doc-train-${Date.now()}`,
          docType: 'Sertifikat Pelatihan',
          title: `Sertifikat Pelatihan Konselor Sebaya : ${input.education.trim() || 'Fakultas Psikologi'}`,
          documentNumber: `CERT-VOL-${Math.floor(1000 + Math.random() * 9000)}`,
          issuedBy: input.education.trim() || 'Komunitas Peduli Kesehatan Mental',
          issuedYear: '2025',
          validUntil: '2028-12-31',
          fileName: `Sertifikat_Pelatihan_${slug}.pdf`,
          fileSize: '1.1 MB',
          verified: false,
          imageUrl: generateCertificateSvgUri({
            docType: 'Sertifikat Pelatihan',
            title: `Sertifikat Pelatihan Konselor Sebaya : ${input.education.trim() || 'Fakultas Psikologi'}`,
            documentNumber: `CERT-VOL-${Math.floor(1000 + Math.random() * 9000)}`,
            issuedBy: input.education.trim() || 'Komunitas Peduli Kesehatan Mental',
            holderName: input.fullName.trim(),
            validUntil: '2028-12-31',
          }),
        },
      ]
    : [
        {
          id: `doc-sipp-${Date.now()}`,
          docType: 'SIPP',
          title: `Surat Izin Praktik Psikologi (SIPP) : ${city}`,
          documentNumber: sippNumber,
          issuedBy: `HIMPSI Wilayah ${city}`,
          issuedYear: '2024',
          validUntil,
          fileName: `SIPP_${slug}.pdf`,
          fileSize: '1.3 MB',
          verified: false,
          imageUrl: generateCertificateSvgUri({
            docType: 'SIPP',
            title: `Surat Izin Praktik Psikologi (SIPP) : ${city}`,
            documentNumber: sippNumber,
            issuedBy: `HIMPSI Wilayah ${city}`,
            holderName: input.fullName.trim(),
            validUntil,
          }),
        },
        {
          id: `doc-str-${Date.now() + 1}`,
          docType: 'STR HIMPSI',
          title: 'Surat Tanda Registrasi Psikolog Klinis (STR-PK)',
          documentNumber: strNumber || 'STR-PK-2024-991023',
          issuedBy: 'Ikatan Psikolog Klinis (IPK) Indonesia / Kemenkes RI',
          issuedYear: '2024',
          validUntil,
          fileName: `STR_PK_${slug}.pdf`,
          fileSize: '940 KB',
          verified: false,
          imageUrl: generateCertificateSvgUri({
            docType: 'STR HIMPSI',
            title: 'Surat Tanda Registrasi Psikolog Klinis (STR-PK)',
            documentNumber: strNumber || 'STR-PK-2024-991023',
            issuedBy: 'Ikatan Psikolog Klinis (IPK) Indonesia / Kemenkes RI',
            holderName: input.fullName.trim(),
            validUntil,
          }),
        },
        {
          id: `doc-ijz-${Date.now() + 2}`,
          docType: 'Ijazah Profesi',
          title: `Ijazah & Sertifikat Profesi : ${input.education.trim()}`,
          documentNumber: `IJZ-PSI-${Math.floor(1000 + Math.random() * 9000)}`,
          issuedBy: input.education.trim(),
          issuedYear: '2021',
          validUntil: 'Seumur Hidup',
          fileName: `Ijazah_Profesi_${slug}.pdf`,
          fileSize: '1.8 MB',
          verified: false,
          imageUrl: generateCertificateSvgUri({
            docType: 'Ijazah Profesi',
            title: `Ijazah & Sertifikat Profesi : ${input.education.trim()}`,
            documentNumber: `IJZ-PSI-${Math.floor(1000 + Math.random() * 9000)}`,
            issuedBy: input.education.trim(),
            holderName: input.fullName.trim(),
            validUntil: 'Seumur Hidup',
          }),
        },
      ]

  const created: Psychologist = {
    id: `psy-relawan-${Date.now()}`,
    partnerId: null,
    practiceType: 'mandiri',
    role,
    isPriorityMobile: false,
    verificationStatus: 'pending',
    fullName: input.fullName.trim(),
    sippNumber,
    strNumber,
    city,
    education: input.education.trim(),
    email: input.email.trim(),
    phone: input.phone.trim(),
    practiceSchedule: input.practiceSchedule.trim(),
    specializations: input.specializations,
    status: 'inactive',
    weeklyQuota: isBiasa ? 8 : 12,
    yearsExperience: isBiasa ? 1 : 5,
    submittedAt: today,
    documents,
  }

  db.psychologists.unshift(created)
  savePortalDb(db)
  return created
}

export function simulateVolunteerUpgradeSubmission(
  psychologistId: string,
  targetRole: 'relawan_utama' | 'relawan_profesional' | 'relawan_pro',
  notes: string,
): Psychologist | null {
  const db = loadPortalDb()
  const idx = db.psychologists.findIndex((p) => p.id === psychologistId)
  if (idx === -1) return null

  const psy = db.psychologists[idx]
  const today = new Date().toISOString().slice(0, 10)
  const slug = psy.fullName.replace(/[^a-zA-Z0-9]+/g, '_').slice(0, 20)
  const isTargetUtama = targetRole === 'relawan_utama' || targetRole === 'relawan_pro'
  const normalizedTargetRole = isTargetUtama ? 'relawan_utama' : 'relawan_profesional'

  const upgradeDocs: PsychologistCertificate[] =
    isTargetUtama
      ? [
          {
            id: `doc-upg-utama-${Date.now()}`,
            docType: 'Bukti Kinerja Relawan',
            title: 'Laporan Rekap Kinerja & Rekomendasi Promosi Relawan Utama',
            documentNumber: `EV-UTAMA-REC-${Math.floor(1000 + Math.random() * 9000)}`,
            issuedBy: 'Komite Supervisi Relawan & Evaluasi EVA',
            issuedYear: '2026',
            validUntil: '2027-12-31',
            fileName: `Rekomendasi_Relawan_Utama_${slug}.pdf`,
            fileSize: '1.2 MB',
            verified: false,
            imageUrl: generateCertificateSvgUri({
              docType: 'Bukti Kinerja Relawan',
              title: 'Laporan Rekap Kinerja & Rekomendasi Promosi Relawan Utama',
              documentNumber: `EV-UTAMA-REC-${Math.floor(1000 + Math.random() * 9000)}`,
              issuedBy: 'Komite Supervisi Relawan & Evaluasi EVA',
              holderName: psy.fullName,
              validUntil: '2027-12-31',
            }),
          },
        ]
      : [
          {
            id: `doc-upg-ijz-${Date.now()}`,
            docType: 'Ijazah Profesi',
            title: 'Ijazah & Sumpah Magister Profesi Psikologi',
            documentNumber: `IJZ-S2-PROF-${Math.floor(1000 + Math.random() * 9000)}`,
            issuedBy: 'Fakultas Psikologi Universitas Terakreditasi',
            issuedYear: '2026',
            validUntil: 'Seumur Hidup',
            fileName: `Ijazah_Profesi_Baru_${slug}.pdf`,
            fileSize: '2.1 MB',
            verified: false,
            imageUrl: generateCertificateSvgUri({
              docType: 'Ijazah Profesi',
              title: 'Ijazah & Sumpah Magister Profesi Psikologi',
              documentNumber: `IJZ-S2-PROF-${Math.floor(1000 + Math.random() * 9000)}`,
              issuedBy: 'Fakultas Psikologi Universitas Terakreditasi',
              holderName: psy.fullName,
              validUntil: 'Seumur Hidup',
            }),
          },
          {
            id: `doc-upg-sipp-${Date.now() + 1}`,
            docType: 'SIPP',
            title: 'Surat Izin Praktik Psikologi (SIPP) Terbaru',
            documentNumber: `20260901-2031-01-${Math.floor(1000 + Math.random() * 9000)}`,
            issuedBy: `HIMPSI Wilayah ${psy.city ?? 'INDONESIA'}`,
            issuedYear: '2026',
            validUntil: '2031-09-01',
            fileName: `SIPP_Baru_${slug}.pdf`,
            fileSize: '1.4 MB',
            verified: false,
            imageUrl: generateCertificateSvgUri({
              docType: 'SIPP',
              title: 'Surat Izin Praktik Psikologi (SIPP) Terbaru',
              documentNumber: `20260901-2031-01-${Math.floor(1000 + Math.random() * 9000)}`,
              issuedBy: `HIMPSI Wilayah ${psy.city ?? 'INDONESIA'}`,
              holderName: psy.fullName,
              validUntil: '2031-09-01',
            }),
          },
          {
            id: `doc-upg-str-${Date.now() + 2}`,
            docType: 'STR HIMPSI',
            title: 'Surat Tanda Registrasi Psikolog Klinis (STR-PK)',
            documentNumber: `STR-PK-2026-${Math.floor(100000 + Math.random() * 900000)}`,
            issuedBy: 'Konsil Tenaga Kesehatan Indonesia / IPK Indonesia',
            issuedYear: '2026',
            validUntil: '2031-09-01',
            fileName: `STR_PK_Baru_${slug}.pdf`,
            fileSize: '920 KB',
            verified: false,
            imageUrl: generateCertificateSvgUri({
              docType: 'STR HIMPSI',
              title: 'Surat Tanda Registrasi Psikolog Klinis (STR-PK)',
              documentNumber: `STR-PK-2026-${Math.floor(100000 + Math.random() * 900000)}`,
              issuedBy: 'Konsil Tenaga Kesehatan Indonesia / IPK Indonesia',
              holderName: psy.fullName,
              validUntil: '2031-09-01',
            }),
          },
        ]

  db.psychologists[idx] = {
    ...psy,
    rejectionReason: undefined,
    upgradeRequest: {
      targetRole: normalizedTargetRole,
      requestedAt: today,
      notes,
      documents: upgradeDocs,
    },
  }

  savePortalDb(db)
  return db.psychologists[idx]
}
