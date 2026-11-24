import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/screen_security_helper.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../video_call/presentation/providers/video_call_provider.dart';
import '../providers/patient_provider.dart';

class PatientDetailConsentScreen extends ConsumerStatefulWidget {
  final String patientId;
  final bool initialSessionUnlocked;
  final String? activeSessionId;

  const PatientDetailConsentScreen({
    super.key,
    required this.patientId,
    this.initialSessionUnlocked = false,
    this.activeSessionId,
  });

  @override
  ConsumerState<PatientDetailConsentScreen> createState() =>
      _PatientDetailConsentScreenState();
}

class _PatientDetailConsentScreenState
    extends ConsumerState<PatientDetailConsentScreen> {
  int _activeTabIndex = 0; // 0 = Memori Klinis & DASS, 1 = Catatan Medis & Diagnosa
  bool _isRequestingConsent = false;
  late bool _sessionUnlocked;

  // Clinical Note Form (Manual - Encrypted in DB)
  final _subjCtrl = TextEditingController();
  final _objCtrl = TextEditingController();
  final _assessCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  bool _isSavingNote = false;

  @override
  void initState() {
    super.initState();
    ScreenSecurityHelper.enableSecureScreen();
    _sessionUnlocked = widget.initialSessionUnlocked;
    if (widget.initialSessionUnlocked) {
      _activeTabIndex = 1; // Direct to note form
    }
  }

  @override
  void dispose() {
    ScreenSecurityHelper.disableSecureScreen();
    _subjCtrl.dispose();
    _objCtrl.dispose();
    _assessCtrl.dispose();
    _planCtrl.dispose();
    super.dispose();
  }

  void _handleRequestConsent() async {
    setState(() => _isRequestingConsent = true);
    final repo = ref.read(patientRepositoryProvider);
    await repo.requestPatientConsent(widget.patientId);
    ref.invalidate(patientDetailProvider(widget.patientId));
    ref.invalidate(patientsListProvider);
    if (!mounted) return;
    setState(() => _isRequestingConsent = false);

    TopToast.show(
      context,
      title: 'Permintaan Dikirim',
      message: 'Permintaan persetujuan akses rekam emosional telah dikirim ke pasien.',
      type: ToastType.success,
    );
  }

  void _handleSaveSoapNote() async {
    if (_subjCtrl.text.isEmpty || _assessCtrl.text.isEmpty) {
      TopToast.show(
        context,
        title: 'Form Belum Lengkap',
        message: 'Harap lengkapi kolom Subjective dan Assessment.',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isSavingNote = true);
    final repo = ref.read(patientRepositoryProvider);
    await repo.saveClinicalNote(
      patientId: widget.patientId,
      sessionId: widget.activeSessionId ?? 'session-manual-${DateTime.now().millisecondsSinceEpoch}',
      subjective: _subjCtrl.text,
      objective: _objCtrl.text.isNotEmpty ? _objCtrl.text : 'Afek tenang dan kooperatif.',
      assessment: _assessCtrl.text,
      plan: _planCtrl.text.isNotEmpty ? _planCtrl.text : 'Latihan relaksasi mandiri.',
      recommendedTasks: ['Pernapasan diafragma harian', 'Journaling emosi malam'],
    );

    ref.invalidate(patientNotesProvider(widget.patientId));
    ref.invalidate(patientsListProvider);
    ref.invalidate(patientDetailProvider(widget.patientId));
    if (!mounted) return;
    setState(() {
      _isSavingNote = false;
      _sessionUnlocked = false;
      _subjCtrl.clear();
      _objCtrl.clear();
      _assessCtrl.clear();
      _planCtrl.clear();
    });

    final authUser = ref.read(authStateProvider).value;
    if (authUser?.isProfessional == true) {
      final reward = authUser?.coinsPerSession ?? 150;
      ref.read(authStateProvider.notifier).addCoins(reward);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.verifiedGreen, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Catatan Disimpan! 🌟',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Rekam medis SOAP telah berhasil difinalisasi dan tersimpan ke riwayat pasien.${authUser?.isProfessional == true ? '\n\n+${authUser?.coinsPerSession ?? 150} Koin honorarium sesi telah dikreditkan ke dompet Anda.' : ''}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verifiedGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                              'Memori Klinis & DASS',
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
                              'Catatan SOAP & Transkrip',
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

                // Tab Content Area (Scrolls naturally with the page)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: _activeTabIndex == 0
                      ? (patient.hasConsent
                          ? _buildConsentGrantedContent(patient)
                          : _buildConsentLockedGuard(patient))
                      : _buildSoapTabContent(patient, notesAsync),
                ),
                const SizedBox(height: 32),
              ],
            ),
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
            'Memori Klinis Pasien Terlindungi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Berdasarkan regulasi privasi rekam medis psikologi, data skrining DASS-21 serta memori riwayat keluhan klinis pasien hanya dapat diakses setelah pasien memberikan persetujuan (Consent Gate).',
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

  // TAB 1: GRANTED CONSENT VIEW (GATED BY ACTIVE/UPCOMING SCHEDULE)
  Widget _buildConsentGrantedContent(dynamic patient) {
    final bool hasActiveSchedule = patient.upcomingSchedule != null;
    final bool isAccessAllowed = hasActiveSchedule || _sessionUnlocked;

    if (!isAccessAllowed) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFECEFF8)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, size: 32, color: AppColors.highRiskRed),
            ),
            const SizedBox(height: 12),
            const Text(
              'Akses Rekam Medis Terkunci 🔒',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sesuai etika kerahasiaan pasien, detail rekam emosional hanya dapat diakses saat ada jadwal konsultasi aktif (booking mendatang atau sesi terjadwal). Setelah sesi selesai difinalisasi, akses tertutup kembali secara otomatis demi privasi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.45),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.verifiedBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
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
        const Row(
          children: [
            Icon(Icons.auto_stories_rounded, size: 18, color: AppColors.primary),
            SizedBox(width: 6),
            Text(
              'Riwayat Pemicu & Keluhan yang Dirangkum Eva',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Rangkuman pemicu dan keluhan pasien yang dicatat serta disintesis oleh Eva dari jurnal mandiri pasien.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        // Keluhan Awal Pasien
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flag_outlined, color: Color(0xFF2563EB), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keluhan Awal Pasien:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.textPrimary),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 16),
                  ),
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

  // TAB 2: SOAP TAB CONTENT (PSIKOLOG MANDIRI: FORM SOAP LENGKAP + TRANSKRIP)
  Widget _buildSoapTabContent(dynamic patient, AsyncValue<List<dynamic>> notesAsync) {
    final schedule = patient.upcomingSchedule;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_sessionUnlocked) ...[
          _buildScheduleGatedSoapCard(patient, schedule),
        ] else ...[
          // UNLOCKED: MANUAL CLINICAL NOTE & DIAGNOSIS (NO AI TRANSCRIPT DEPENDENCY)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catatan Medis & Diagnosa Klinis (Manual)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Dicatat langsung secara manual oleh psikolog pemeriksa. Data tersimpan aman dengan enkripsi database (AES-256) tanpa bergantung pada transkrip AI.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 12, color: Color(0xFF059669)),
                      SizedBox(width: 6),
                      Text(
                        'Enkripsi Database Aktif (E2EE/AES-256)',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // IN-CALL QUICK NOTES (Catatan Singkat Selama Sesi Video Call)
          Builder(builder: (context) {
            final sessionId = patient.upcomingSchedule?.sessionId;
            if (sessionId == null || sessionId.isEmpty) return const SizedBox.shrink();
            final liveNotes = ref.watch(videoCallControllerProvider(sessionId)).realTimeNotes;
            if (liveNotes.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.edit_note_rounded, color: AppColors.verifiedGreen, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Catatan Singkat Sesi Video Call',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.verifiedGreen,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          final joined = liveNotes.join('\n• ');
                          if (_subjCtrl.text.isEmpty) {
                            _subjCtrl.text = 'Catatan observasi sesi:\n• $joined';
                          } else {
                            _subjCtrl.text += '\n• $joined';
                          }
                          TopToast.show(
                            context,
                            message: 'Catatan disalin ke kolom S (Subjective).',
                            type: ToastType.success,
                          );
                        },
                        child: const Text('Salin ke S (Subjective)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...liveNotes.map((note) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppColors.verifiedGreen, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(note, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                      ],
                    ),
                  )),
                ],
              ),
            );
          }),

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
                _buildSoftInput('S (Subjective) - Keluhan & Riwayat Penting Pasien', _subjCtrl),
                const SizedBox(height: 12),
                _buildSoftInput('O (Objective) - Pemeriksaan Status Mental & Afek', _objCtrl),
                const SizedBox(height: 12),
                _buildSoftInput('A (Assessment) - Diagnosa Klinis & Dinamika Masalah', _assessCtrl),
                const SizedBox(height: 12),
                _buildSoftInput('P (Plan) - Rencana Intervensi & Tindak Lanjut', _planCtrl),
                const SizedBox(height: 16),
                CustomButton(
                  label: 'Simpan & Enkripsi Catatan Medis',
                  icon: Icons.lock_outline_rounded,
                  isLoading: _isSavingNote,
                  onPressed: _handleSaveSoapNote,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        notesAsync.when(
          data: (notes) {
            final validNotes = notes.where((note) {
              final s = note.subjective?.toString().trim() ?? '';
              final a = note.assessment?.toString().trim() ?? '';
              return s.isNotEmpty || a.isNotEmpty;
            }).toList();

            if (validNotes.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text('Riwayat Catatan Konseling Lalu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                ...validNotes.map((note) {
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
                            StatusBadge.verified('Terdokumentasi & Valid'),
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
                }),
              ],
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
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontSize: 12.5, height: 1.45),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
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
              'Waktu jadwal telekonsultasi telah aktif. Anda dapat langsung membuka ruang video call sekarang. Eva AI akan mentranskripsikan audio percakapan menjadi draf catatan SOAP secara otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 18),
            CustomButton(
              label: 'Masuk Ruang Video Call Sekarang',
              icon: Icons.videocam_rounded,
              onPressed: () async {
                final sessionId = schedule.sessionId;
                if (sessionId == null || sessionId.isEmpty) {
                  TopToast.show(
                    context,
                    title: 'Jadwal Belum Aktif',
                    message: 'ID sesi konsultasi belum tersedia untuk panggilan video.',
                    type: ToastType.warning,
                  );
                  return;
                }
                final finished = await Navigator.of(context).pushNamed(
                  '/counselor-video-call',
                  arguments: {
                    'sessionId': sessionId,
                    'patientName': patient.name,
                    'scheduledTime': schedule.timeRange,
                    'isLiveNow': schedule.isLiveNow,
                    'roomOpensAt': schedule.roomOpensAt,
                  },
                );
                if (finished == true && mounted) {
                  setState(() {
                    _sessionUnlocked = true;
                    final liveNotes = ref.read(videoCallControllerProvider(sessionId)).realTimeNotes;
                    if (liveNotes.isNotEmpty) {
                      _subjCtrl.text = 'Catatan observasi sesi:\n• ${liveNotes.join('\n• ')}';
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_clock_rounded, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Formulir catatan medis klinis baru aktif setelah sesi Video Call selesai terlaksana.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
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
            CustomButton(
              label: 'Masuk / Standby Ruang Video Call',
              icon: Icons.videocam_rounded,
              onPressed: () async {
                final sessionId = schedule.sessionId;
                if (sessionId == null || sessionId.isEmpty) {
                  TopToast.show(
                    context,
                    title: 'Jadwal Belum Aktif',
                    message: 'ID sesi konsultasi belum tersedia untuk panggilan video.',
                    type: ToastType.warning,
                  );
                  return;
                }
                final finished = await Navigator.of(context).pushNamed(
                  '/counselor-video-call',
                  arguments: {
                    'sessionId': sessionId,
                    'patientName': patient.name,
                    'scheduledTime': schedule.timeRange,
                    'isLiveNow': schedule.isLiveNow,
                    'roomOpensAt': schedule.roomOpensAt,
                  },
                );
                if (finished == true && mounted) {
                  setState(() {
                    _sessionUnlocked = true;
                    final liveNotes = ref.read(videoCallControllerProvider(sessionId)).realTimeNotes;
                    if (liveNotes.isNotEmpty) {
                      _subjCtrl.text = 'Catatan observasi sesi:\n• ${liveNotes.join('\n• ')}';
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_clock_rounded, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Formulir catatan medis klinis baru aktif setelah sesi Video Call selesai terlaksana.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
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
              'Pasien belum melakukan booking sesi telekonsultasi baru. Formulir SOAP klinis akan aktif otomatis setelah sesi telekonsultasi terlaksana.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_edu_rounded, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Riwayat catatan klinis sesi lampau dapat dilihat pada riwayat di bawah.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
}
