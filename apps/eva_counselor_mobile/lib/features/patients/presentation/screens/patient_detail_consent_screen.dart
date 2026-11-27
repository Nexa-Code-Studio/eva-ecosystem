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

  // Clinical Note Form (Manual Observational Notes - NOT Hospital SOAP)
  final _newPointCtrl = TextEditingController();
  final _narrativeCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  final List<String> _clinicalPoints = [];
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
    _newPointCtrl.dispose();
    _narrativeCtrl.dispose();
    _planCtrl.dispose();
    super.dispose();
  }

  void _addClinicalPoint() {
    final text = _newPointCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _clinicalPoints.add(text);
        _newPointCtrl.clear();
      });
    }
  }

  void _removeClinicalPoint(int index) {
    setState(() {
      _clinicalPoints.removeAt(index);
    });
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
    if (_clinicalPoints.isEmpty && _narrativeCtrl.text.trim().isEmpty) {
      TopToast.show(
        context,
        title: 'Form Belum Lengkap',
        message: 'Harap tambahkan minimal 1 poin observasi klinis atau narasi evaluasi.',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isSavingNote = true);
    final repo = ref.read(patientRepositoryProvider);
    final patient = ref.read(patientDetailProvider(widget.patientId)).value;
    final subjFormatted = _clinicalPoints.isNotEmpty
        ? _clinicalPoints.map((p) => '• $p').join('\n')
        : _narrativeCtrl.text.trim();
    final assessFormatted = _narrativeCtrl.text.trim().isNotEmpty
        ? _narrativeCtrl.text.trim()
        : (_clinicalPoints.isNotEmpty ? _clinicalPoints.first : 'Observasi klinis tercatat.');

    final targetSessionId = widget.activeSessionId ??
        patient?.upcomingSchedule?.sessionId ??
        'session-manual-${DateTime.now().millisecondsSinceEpoch}';

    late final dynamic savedNote;
    try {
      savedNote = await repo.saveClinicalNote(
        patientId: widget.patientId,
        sessionId: targetSessionId,
        subjective: subjFormatted,
        objective: 'Observasi klinis langsung psikolog via telekonseling.',
        assessment: assessFormatted,
        plan: _planCtrl.text.trim().isNotEmpty ? _planCtrl.text.trim() : 'Latihan relaksasi & psikoedukasi berkala.',
        recommendedTasks: ['Pernapasan diafragma mandiri', 'Journaling emosi malam'],
        points: List.from(_clinicalPoints),
        narrative: _narrativeCtrl.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingNote = false);
      TopToast.show(
        context,
        title: 'Gagal Menyimpan Catatan',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
      );
      return;
    }

    ref.invalidate(patientNotesProvider(widget.patientId));
    ref.invalidate(patientsListProvider);
    ref.invalidate(patientDetailProvider(widget.patientId));
    if (!mounted) return;
    setState(() {
      _isSavingNote = false;
      _sessionUnlocked = false;
      _clinicalPoints.clear();
      _newPointCtrl.clear();
      _narrativeCtrl.clear();
      _planCtrl.clear();
    });

    final authUser = ref.read(authStateProvider).value;
    final int awarded = (savedNote.coinsAwarded as int?) ?? 0;
    final int? syncedBalance = savedNote.coinBalance as int?;
    if (syncedBalance != null) {
      ref.read(authStateProvider.notifier).syncCoinBalance(syncedBalance);
    } else if (authUser?.isProfessional == true && awarded > 0) {
      ref.read(authStateProvider.notifier).addCoins(awarded);
    }

    final String rewardMessage = awarded > 0
        ? '\n\n+$awarded Koin honorarium sesi telah dikreditkan ke dompet Anda.'
        : (authUser?.isProfessional == true
            ? '\n\nCatatan diperbarui (honorarium sesi sudah dikreditkan sebelumnya).'
            : '');

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
          'Rekam medis SOAP telah berhasil difinalisasi dan tersimpan ke riwayat pasien.$rewardMessage',
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

  // TAB 1: GRANTED CONSENT VIEW (GATED BY PATIENT STATUS OR ACTIVE SCHEDULE)
  Widget _buildConsentGrantedContent(dynamic patient) {
    // Sesuai kode etik & etika klinis: jika pengguna sudah menjadi pasien (memiliki consent aktif,
    // riwayat sesi sebelumnya, atau jadwal aktif), rekam medis tidak dikunci dan selalu dapat diakses.
    final bool isPatient = patient.hasConsent ||
        patient.totalCompletedSessions > 0 ||
        patient.upcomingSchedule != null;
    final bool isAccessAllowed = isPatient || _sessionUnlocked;

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
            Icon(Icons.psychology_rounded, size: 18, color: AppColors.primary),
            SizedBox(width: 6),
            Text(
              'Riwayat Pemicu & Keluhan Klinis (Clinical Triggers)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Daftar keluhan klinis dan pemicu emosional esensial yang dievaluasi untuk proses konseling.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),

        // ETHICAL PRIVACY BADGE (Kode Etik HIMPSI)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kode Etik HIMPSI (Pasal 24 Kerahasiaan Rekam Psikologi): Data dibatasi pada pemicu klinis esensial & keluhan utama demi menjaga kerahasiaan penuh privasi pasien.',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF1D4ED8), height: 1.4),
                ),
              ),
            ],
          ),
        ),

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
                      'Keluhan Utama Pasien:',
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

        // DAFTAR PEMICU & STRESOR KLINIS
        if (patient.triggers != null && patient.triggers!.isNotEmpty)
          ...patient.triggers!.map((t) {
            final cat = t['category']?.toString() ?? 'Pemicu Klinis';
            final desc = t['description']?.toString() ?? '';
            final sev = t['severity']?.toString() ?? 'Sedang';
            final src = t['source']?.toString() ?? 'Observasi Klinis';
            final isHigh = sev == 'Tinggi' || sev == 'Parah';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECEFF8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cat,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isHigh ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isHigh ? const Color(0xFFFECACA) : const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          sev,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isHigh ? AppColors.highRiskRed : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sumber: $src',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }).toList()
        else if (patient.sharedDiarySummaries != null)
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
                    child: const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 16),
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

  // TAB 2: CLINICAL OBSERVATIONAL NOTES (MANUAL - NOT HOSPITAL SOAP)
  Widget _buildSoapTabContent(dynamic patient, AsyncValue<List<dynamic>> notesAsync) {
    final schedule = patient.upcomingSchedule;
    final bool isExistingPatient = patient.hasConsent ||
        patient.totalCompletedSessions > 0 ||
        schedule != null;
    bool isSoapWindowExpired = false;
    if (!_sessionUnlocked && schedule == null && patient.lastSessionDate != null) {
      final parsedLast = DateTime.tryParse(patient.lastSessionDate.toString());
      if (parsedLast != null) {
        final wibRef = parsedLast.toUtc().add(const Duration(hours: 7));
        final deadlineWib = DateTime.utc(wibRef.year, wibRef.month, wibRef.day + 1, 23, 59, 59);
        final deadlineUtc = deadlineWib.subtract(const Duration(hours: 7));
        isSoapWindowExpired = DateTime.now().toUtc().isAfter(deadlineUtc);
      }
    }
    final bool canEditNotes = (isExistingPatient || _sessionUnlocked) && !isSoapWindowExpired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. VIDEO CALL STATUS / ENTRY CARD (IF ACTIVE SCHEDULE)
        if (schedule != null) ...[
          _buildScheduleGatedSoapCard(patient, schedule),
          const SizedBox(height: 14),
        ],

        if (isSoapWindowExpired) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_clock_rounded, color: Color(0xFF475569), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batas Waktu Edit SOAP Berakhir (H+1 23:59 WIB)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: Color(0xFF334155),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Sesuai kebijakan klinis, pengisian dan penyuntingan catatan medis SOAP hanya dibuka hingga H+1 pukul 23:59 WIB setelah sesi konsultasi.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // 2. UNLOCKED / EDITABLE CLINICAL NOTE FORM
        if (canEditNotes) ...[
          // WARNING BANNER: Sesi telah selesai namun catatan klinis belum disimpan
          if (_sessionUnlocked || patient.totalCompletedSessions > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Perhatian: Catatan Medis Sesi Belum Disimpan!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Sesuai kode etik klinis & ketentuan honorarium, koin honorarium sesi (150 Koin) akan otomatis dikreditkan ke saldo dompet Anda setelah Anda menyimpan catatan observasi ini.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // INFO HEADER CARD
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
                            'Catatan Observasi Klinis Psikolog (Manual)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sesuai Kode Etik Psikologi Indonesia (HIMPSI), psikolog mencatat poin observasi esensial, riwayat trauma, dan narasi evaluasi secara manual. Data tersimpan aman dengan enkripsi database (AES-256).',
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

          // IN-CALL QUICK NOTES IMPORT (Catatan Singkat Selama Sesi Video Call)
          Builder(builder: (context) {
            final sessionId = schedule?.sessionId;
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
                          setState(() {
                            for (final n in liveNotes) {
                              if (!_clinicalPoints.contains(n)) {
                                _clinicalPoints.add(n);
                              }
                            }
                          });
                          TopToast.show(
                            context,
                            message: 'Semua catatan video call telah diimpor ke poin observasi.',
                            type: ToastType.success,
                          );
                        },
                        child: const Text('Impor ke Poin Observasi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

          // FORM CATATAN OBSERVASI KLINIS (Poin Real-Time + Narasi Manual)
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
                // POIN-POIN OBSERVASI KLINIS (REAL-TIME BUILDER)
                const Text(
                  'Poin-Poin Observasi Klinis (Real-Time)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Catat poin penting (misal: riwayat trauma masa kecil, pemicu emosi utama, dinamika keluarga) lalu klik tombol "+".',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),

                // Input + Tombol Tambah Poin
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _newPointCtrl,
                          style: const TextStyle(fontSize: 12.5),
                          onSubmitted: (_) => _addClinicalPoint(),
                          decoration: const InputDecoration(
                            hintText: 'Ketik poin observasi klinis...',
                            hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: _addClinicalPoint,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 4),
                          Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Daftar Poin yang Telah Ditambahkan
                if (_clinicalPoints.isNotEmpty) ...[
                  ..._clinicalPoints.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final pt = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lens, size: 7, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pt,
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.35),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _removeClinicalPoint(idx),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // NARASI CATATAN OBSERVASI MANUAL
                _buildSoftInput(
                  'Narasi Observasi & Dinamika Masalah (Manual)',
                  _narrativeCtrl,
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 12),

                // RENCANA TINDAK LANJUT / EDUKASI
                _buildSoftInput(
                  'Rencana Intervensi & Tindak Lanjut Pasien (PR/Edukasi)',
                  _planCtrl,
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

                CustomButton(
                  label: 'Simpan Catatan Medis Observasi',
                  icon: Icons.save_rounded,
                  isLoading: _isSavingNote,
                  onPressed: _handleSaveSoapNote,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 3. RIWAYAT CATATAN MEDIS LALU (PAST RECORDS)
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
                const Text('Riwayat Catatan Medis Observasi Terdahulu',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                        if (note.points != null && note.points.isNotEmpty) ...[
                          const Text('Poin Observasi Klinis:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                          const SizedBox(height: 4),
                          ...note.points.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                Expanded(child: Text(p, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                              ],
                            ),
                          )),
                          const SizedBox(height: 6),
                        ],
                        if (note.narrative != null && note.narrative.isNotEmpty) ...[
                          const Text('Narasi Observasi:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(note.narrative, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                          const SizedBox(height: 6),
                        ] else if (note.subjective.isNotEmpty) ...[
                          _buildSoapSummaryItem('Observasi', note.subjective),
                        ],
                        if (note.assessment.isNotEmpty && note.assessment != note.narrative)
                          _buildSoapSummaryItem('Evaluasi', note.assessment),
                        if (note.plan.isNotEmpty)
                          _buildSoapSummaryItem('Tindak Lanjut', note.plan),
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

  Widget _buildSoftInput(
    String label,
    TextEditingController controller, {
    int minLines = 3,
    int maxLines = 6,
  }) {
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
            minLines: minLines,
            maxLines: maxLines,
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
                    for (final n in liveNotes) {
                      if (!_clinicalPoints.contains(n)) {
                        _clinicalPoints.add(n);
                      }
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
                    for (final n in liveNotes) {
                      if (!_clinicalPoints.contains(n)) {
                        _clinicalPoints.add(n);
                      }
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
