import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../providers/patient_provider.dart';

class PatientDetailConsentScreen extends ConsumerStatefulWidget {
  final String patientId;

  const PatientDetailConsentScreen({super.key, required this.patientId});

  @override
  ConsumerState<PatientDetailConsentScreen> createState() =>
      _PatientDetailConsentScreenState();
}

class _PatientDetailConsentScreenState
    extends ConsumerState<PatientDetailConsentScreen> {
  int _activeTabIndex = 0; // 0 = Rekam Emosional, 1 = Catatan SOAP
  bool _isRequestingConsent = false;
  bool _sessionUnlocked = false;

  // SOAP Note Form
  final _subjCtrl = TextEditingController();
  final _objCtrl = TextEditingController();
  final _assessCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  bool _isSavingNote = false;

  void _populateLunaTranscriptDraft(dynamic patient) {
    setState(() {
      _sessionUnlocked = true;
      _subjCtrl.text =
          'Pasien (${patient.name}) mengeluhkan kecemasan performansi akademik yang memuncak menjelang evaluasi akhir. Mengalami insomnia dan palpitasi ringan saat membuka tugas di malam hari.';
      _objCtrl.text =
          'Afek cemas dengan modulasi intonasi suara agak tegang di 10 menit awal. Kontak mata terjaga baik lewat video call, nafas lebih teratur setelah relaksasi pacer napas.';
      _assessCtrl.text =
          'Kecemasan situasional tingkat sedang (DASS-21 selaras). Belum ditemukan indikasi risiko melukai diri, responsif terhadap psikoedukasi.';
      _planCtrl.text =
          '1. Praktik teknik pernapasan diafragma 4-7-8 setiap malam.\n2. CBT Thought Record di jurnal Luna.\n3. Evaluasi sesi lanjutan 1 minggu ke depan.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ Draf SOAP dari transkrip percakapan AI Luna berhasil dimuat. Anda dapat mengeditnya.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _handleRequestConsent() async {
    setState(() => _isRequestingConsent = true);
    final repo = ref.read(patientRepositoryProvider);
    await repo.requestPatientConsent(widget.patientId);
    ref.invalidate(patientDetailProvider(widget.patientId));
    ref.invalidate(patientsListProvider);
    if (!mounted) return;
    setState(() => _isRequestingConsent = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Permintaan persetujuan akses rekam emosional telah dikirim ke pasien.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _handleSaveSoapNote() async {
    if (_subjCtrl.text.isEmpty || _assessCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi kolom Subjective dan Assessment.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSavingNote = true);
    final repo = ref.read(patientRepositoryProvider);
    await repo.saveClinicalNote(
      patientId: widget.patientId,
      sessionId: 'session-manual-${DateTime.now().millisecondsSinceEpoch}',
      subjective: _subjCtrl.text,
      objective: _objCtrl.text.isNotEmpty ? _objCtrl.text : 'Afek tenang dan kooperatif.',
      assessment: _assessCtrl.text,
      plan: _planCtrl.text.isNotEmpty ? _planCtrl.text : 'Latihan relaksasi mandiri.',
      recommendedTasks: ['Pernapasan diafragma harian', 'Journaling emosi malam'],
    );

    ref.invalidate(patientNotesProvider(widget.patientId));
    if (!mounted) return;
    setState(() {
      _isSavingNote = false;
      _subjCtrl.clear();
      _objCtrl.clear();
      _assessCtrl.clear();
      _planCtrl.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Catatan klinis SOAP berhasil disimpan.'),
        backgroundColor: AppColors.verifiedGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(patientDetailProvider(widget.patientId));
    final notesAsync = ref.watch(patientNotesProvider(widget.patientId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Rekam Medis Pasien',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: patientAsync.when(
        data: (patient) {
          return SafeArea(
            child: Column(
              children: [
                // Soft Patient Header Card (No harsh borders)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFECEFF8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: patient.isHighRisk
                                ? AppColors.highRiskBg
                                : AppColors.primaryContainer,
                            child: Text(
                              patient.name.substring(0, 1),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: patient.isHighRisk
                                    ? AppColors.highRiskRed
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patient.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${patient.age} tahun • ${patient.gender}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    patient.hasConsent
                                        ? StatusBadge.consentGranted('Akses Emosional Terbuka')
                                        : StatusBadge.consentLocked('Akses Terkunci'),
                                    if (patient.upcomingSchedule != null)
                                      patient.upcomingSchedule!.isLiveNow
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF16A34A),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Live: ${patient.upcomingSchedule!.timeRange}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF15803D),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF2563EB)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    patient.upcomingSchedule!.formattedTime,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1D4ED8),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Belum Ada Jadwal',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Keluhan Utama:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              patient.chiefComplaint,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Modern Pill-Segmented Switcher (Custom Soft Tab Bar)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBEFF7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTabIndex = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _activeTabIndex == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Rekam Emosional',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _activeTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                                color: _activeTabIndex == 0 ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTabIndex = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _activeTabIndex == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Catatan SOAP (Luna AI)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _activeTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                                color: _activeTabIndex == 1 ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Tab Content Area
                Expanded(
                  child: _activeTabIndex == 0
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: patient.hasConsent
                              ? _buildConsentGrantedContent(patient)
                              : _buildConsentLockedGuard(patient),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: _buildSoapTabContent(patient, notesAsync),
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  // TAB 1: LOCKED CONSENT VIEW
  Widget _buildConsentLockedGuard(dynamic patient) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECEFF8)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Rekam Emosional Terlindungi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Berdasarkan regulasi privasi kesehatan mental, riwayat skrining DASS-21 dan ringkasan jurnal emosional harian Luna AI hanya dapat diakses setelah pasien memberikan persetujuan (Consent).',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          CustomButton(
            label: patient.consentRequestedAt != null
                ? 'Permintaan Terkirim (Kirim Ulang)'
                : 'Minta Izin Akses Pasien',
            icon: Icons.send_rounded,
            isLoading: _isRequestingConsent,
            onPressed: _handleRequestConsent,
          ),
        ],
      ),
    );
  }

  // TAB 1: GRANTED CONSENT VIEW
  Widget _buildConsentGrantedContent(dynamic patient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.verifiedBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: const [
              Icon(Icons.verified_rounded, color: AppColors.verifiedGreen, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Persetujuan Aktif • Akses Rekam Terbuka Resmi',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.verifiedGreen),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Hasil Skrining Klinis (DASS-21)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        if (patient.dassHistory != null && patient.dassHistory!.isNotEmpty)
          ...patient.dassHistory!.map((dass) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECEFF8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Evaluasi: ${dass.date.day}/${dass.date.month}/${dass.date.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: StatusBadge.verified(dass.severityLabel),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildDassPill('Depresi', dass.depressionScore, AppColors.primary),
                      const SizedBox(width: 8),
                      _buildDassPill('Kecemasan', dass.anxietyScore, AppColors.warning),
                      const SizedBox(width: 8),
                      _buildDassPill('Stres', dass.stressScore, AppColors.error),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),

        const SizedBox(height: 16),
        const Text('Ringkasan Jurnal Emosi Luna AI (Dibagikan Pasien)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        if (patient.sharedDiarySummaries != null)
          ...patient.sharedDiarySummaries!.map((s) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECEFF8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  // TAB 2: SOAP TAB CONTENT
  Widget _buildSoapTabContent(dynamic patient, AsyncValue<List<dynamic>> notesAsync) {
    final schedule = patient.upcomingSchedule;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_sessionUnlocked) ...[
          _buildScheduleGatedSoapCard(patient, schedule),
        ] else ...[
          // UNLOCKED: LUNA DRAFT BANNER
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3FD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Draf Transkripsi Otomatis AI Luna',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Data di bawah telah disintesis dari percakapan sesi video. Anda dapat mengedit dan menyempurnakannya sebelum finalisasi.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // SOAP INPUTS (Soft, No Harsh Outlines)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFECEFF8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSoftInput('S (Subjective) - Keluhan Pasien', _subjCtrl),
                const SizedBox(height: 12),
                _buildSoftInput('O (Objective) - Observasi Afek & Intonasi', _objCtrl),
                const SizedBox(height: 12),
                _buildSoftInput('A (Assessment) - Analisis Klinis Psikolog', _assessCtrl),
                const SizedBox(height: 12),
                _buildSoftInput('P (Plan) - Rencana Terapi & PR Pasien', _planCtrl),
                const SizedBox(height: 16),
                CustomButton(
                  label: 'Simpan & Finalisasi Rekam Medis',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: _isSavingNote,
                  onPressed: _handleSaveSoapNote,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        const Text('Riwayat Catatan Konseling Lalu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        notesAsync.when(
          data: (notes) {
            if (notes.isEmpty) {
              return const Text('Belum ada catatan terdokumentasi.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
            }
            return Column(
              children: notes.map((note) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFECEFF8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sesi: ${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          StatusBadge.verified('Terdokumentasi'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildSoapSummaryItem('S', note.subjective),
                      _buildSoapSummaryItem('O', note.objective),
                      _buildSoapSummaryItem('A', note.assessment),
                      _buildSoapSummaryItem('P', note.plan),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Widget _buildSoftInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSoapSummaryItem(String tag, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDassPill(String label, int score, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 2),
            Text(
              '$score',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleGatedSoapCard(dynamic patient, dynamic schedule) {
    if (schedule != null && schedule.isLiveNow) {
      // 1. SESI AKTIF / SIAP DIMULAI (Ruang VC Dibuka)
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDCFCE7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_rounded, size: 36, color: Color(0xFF15803D)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Sesi Telekonsultasi Siap Dimulai',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Text(
                'Jadwal Sesi: ${schedule.formattedTime}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Waktu jadwal telekonsultasi telah aktif. Anda dapat langsung membuka ruang video call sekarang. AI Luna akan mentranskripsikan audio percakapan menjadi draf catatan SOAP secara otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 18),
            CustomButton(
              label: 'Masuk Ruang Video Call Sekarang',
              icon: Icons.videocam_rounded,
              onPressed: () async {
                final finished = await Navigator.of(context).pushNamed(
                  '/counselor-video-call',
                  arguments: schedule.sessionId ?? 'session-live-001',
                );
                if (finished == true && mounted) {
                  _populateLunaTranscriptDraft(patient);
                }
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD0D4E5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
              label: const Text(
                'Simulasikan Draf Transkrip AI Luna',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () => _populateLunaTranscriptDraft(patient),
            ),
          ],
        ),
      );
    } else if (schedule != null && !schedule.isLiveNow) {
      // 2. JADWAL MENDATANG (Ruang VC Belum Waktunya Dibuka)
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFECEFF8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.schedule_rounded, size: 36, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Catatan SOAP Klinis Terkunci',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_note_rounded, size: 15, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        schedule.formattedTime,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      '⏱️ ${schedule.statusText}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sesuai etika telekonsultasi klinis, ruang video call dan transkripsi SOAP baru dibuka 15 menit sebelum sesi (pukul ${schedule.roomOpensAt}). Pasien belum standby di ruang sesi saat ini.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Text(
                    'Ruang VC Dibuka Pukul ${schedule.roomOpensAt}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD0D4E5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.play_circle_outline_rounded, color: AppColors.textSecondary, size: 15),
                    label: const Text(
                      'Buka VC (Demo)',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    onPressed: () async {
                      final finished = await Navigator.of(context).pushNamed(
                        '/counselor-video-call',
                        arguments: schedule.sessionId ?? 'session-live-001',
                      );
                      if (finished == true && mounted) {
                        _populateLunaTranscriptDraft(patient);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD0D4E5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 15),
                    label: const Text(
                      'Draf AI (Demo)',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    onPressed: () => _populateLunaTranscriptDraft(patient),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // 3. BELUM ADA JADWAL AKTIF MENDATANG
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFECEFF8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy_rounded, size: 36, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum Ada Jadwal Konsultasi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Menunggu Reservasi Sesi Baru',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pasien ini belum memiliki jadwal telekonsultasi aktif. Formulir SOAP klinis baru akan terbuka setelah sesi telekonsultasi terkonfirmasi dan terlaksana.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            CustomButton(
              label: 'Tawarkan Jadwal Konseling',
              icon: Icons.calendar_month_rounded,
              onPressed: () => _showOfferScheduleSheet(context, patient),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD0D4E5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
              label: const Text(
                'Simulasikan Draf Transkrip AI Luna (Demo)',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () => _populateLunaTranscriptDraft(patient),
            ),
          ],
        ),
      );
    }
  }

  void _showOfferScheduleSheet(BuildContext context, dynamic patient) {
    int selectedSlot = 0;
    final slots = [
      'Besok Rabu, 12 Nov • 10:00 - 10:50 WIB',
      'Kamis, 13 Nov • 14:00 - 14:50 WIB',
      'Jumat, 14 Nov • 16:00 - 16:50 WIB',
      'Senin, 17 Nov • 11:00 - 11:50 WIB',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tawarkan Jadwal Konseling',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Pilih slot praktik untuk diajukan ke ${patient.name}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Pilihan Slot Tersedia:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(slots.length, (idx) {
                    final isSel = selectedSlot == idx;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedSlot = idx),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primaryContainer.withValues(alpha: 0.3) : const Color(0xFFF8F9FE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? AppColors.primary : const Color(0xFFECEFF8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              size: 18,
                              color: isSel ? AppColors.primary : AppColors.textLight,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              slots[idx],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                color: isSel ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  CustomButton(
                    label: 'Kirim Tawaran Jadwal ke Pasien',
                    icon: Icons.send_rounded,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✨ Tawaran jadwal ${slots[selectedSlot]} berhasil dikirim ke ${patient.name}.'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
