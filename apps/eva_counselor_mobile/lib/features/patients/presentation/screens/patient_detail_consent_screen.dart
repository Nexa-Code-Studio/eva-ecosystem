import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
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
    extends ConsumerState<PatientDetailConsentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRequestingConsent = false;

  // SOAP Note Form
  final _subjCtrl = TextEditingController();
  final _objCtrl = TextEditingController();
  final _assessCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  bool _isSavingNote = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      appBar: AppBar(
        title: Text('Rekam Pasien', style: AppTypography.headingMedium),
      ),
      body: patientAsync.when(
        data: (patient) {
          return SafeArea(
            child: Column(
              children: [
                // Patient Summary Header Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
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
                                    style: AppTypography.headingSmall.copyWith(fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${patient.age} Tahun • ${patient.gender}',
                                    style: AppTypography.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  patient.hasConsent
                                      ? StatusBadge.consentGranted('Akses Emosional Terbuka')
                                      : StatusBadge.consentLocked('Akses Terkunci'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Keluhan Utama:',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(patient.chiefComplaint, style: AppTypography.bodyMedium),
                      ],
                    ),
                  ),
                ),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: AppTypography.headingSmall.copyWith(fontSize: 13),
                  tabs: const [
                    Tab(text: 'Rekam Emosional (Consent)'),
                    Tab(text: 'Catatan Klinis (SOAP)'),
                  ],
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: EMOTIONAL RECORD (CONSENT-GATED)
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: patient.hasConsent
                            ? _buildConsentGrantedContent(patient)
                            : _buildConsentLockedGuard(patient),
                      ),

                      // TAB 2: SOAP NOTES
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tulis Catatan Konseling (SOAP)', style: AppTypography.headingSmall),
                            const SizedBox(height: 12),
                            GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  CustomTextField(
                                    label: 'S (Subjective) - Keluhan & Cerita Pasien',
                                    hint: 'Apa yang dirasakan dan diutarakan pasien selama sesi...',
                                    controller: _subjCtrl,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 12),
                                  CustomTextField(
                                    label: 'O (Objective) - Observasi Afek & Perilaku',
                                    hint: 'Bahasa tubuh, ekspresi emosi, kontak mata...',
                                    controller: _objCtrl,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 12),
                                  CustomTextField(
                                    label: 'A (Assessment) - Analisis Klinis Psikolog',
                                    hint: 'Penilaian klinis dinamika emosi...',
                                    controller: _assessCtrl,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 12),
                                  CustomTextField(
                                    label: 'P (Plan) - Rencana Terapi & Tugas Mandiri',
                                    hint: 'Tugas relaksasi / rencana sesi lanjutan...',
                                    controller: _planCtrl,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 16),
                                  CustomButton(
                                    label: 'Simpan Catatan SOAP',
                                    icon: Icons.save_outlined,
                                    isLoading: _isSavingNote,
                                    onPressed: _handleSaveSoapNote,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text('Riwayat Catatan Klinis Sebelumnya', style: AppTypography.headingSmall),
                            const SizedBox(height: 12),
                            notesAsync.when(
                              data: (notes) {
                                if (notes.isEmpty) {
                                  return const Text('Belum ada catatan klinis terdokumentasi.');
                                }
                                return Column(
                                  children: notes.map((note) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: GlassCard(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Sesi: ${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year}',
                                                  style: AppTypography.headingSmall.copyWith(fontSize: 13),
                                                ),
                                                StatusBadge.verified('Terdokumentasi'),
                                              ],
                                            ),
                                            const Divider(height: 18),
                                            _buildSoapField('Subjective', note.subjective),
                                            _buildSoapField('Objective', note.objective),
                                            _buildSoapField('Assessment', note.assessment),
                                            _buildSoapField('Plan', note.plan),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                              loading: () => const CircularProgressIndicator(),
                              error: (e, _) => Text('Error: $e'),
                            ),
                          ],
                        ),
                      ),
                    ],
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

  Widget _buildSoapField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  // CONSENT LOCKED GUARD WIDGET
  Widget _buildConsentLockedGuard(dynamic patient) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Akses Rekam Emosional Terkunci',
              style: AppTypography.headingSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Untuk mematuhi etika kerahasiaan medis dan regulasi privasi pasien, riwayat DASS-21 dan ringkasan jurnal emosi EVA hanya dapat diakses setelah pasien memberikan persetujuan (Consent).',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              label: patient.consentRequestedAt != null
                  ? 'Permintaan Terkirim (Kirim Ulang)'
                  : 'Kirim Permintaan Izin Akses',
              icon: Icons.send_rounded,
              isLoading: _isRequestingConsent,
              onPressed: _handleRequestConsent,
            ),
          ],
        ),
      ),
    );
  }

  // CONSENT GRANTED CONTENT WIDGET
  Widget _buildConsentGrantedContent(dynamic patient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.verifiedGreen, size: 20),
            const SizedBox(width: 6),
            Text(
              'Persetujuan Pasien Aktif • Akses Rekam Terbuka',
              style: AppTypography.labelMedium.copyWith(color: AppColors.verifiedGreen),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // DASS-21 History Cards
        Text('Hasil Skrining DASS-21 Pasien', style: AppTypography.headingSmall),
        const SizedBox(height: 10),
        if (patient.dassHistory != null && patient.dassHistory!.isNotEmpty)
          ...patient.dassHistory!.map((dass) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Evaluasi: ${dass.date.day}/${dass.date.month}/${dass.date.year}',
                          style: AppTypography.headingSmall.copyWith(fontSize: 13),
                        ),
                        StatusBadge.verified(dass.severityLabel),
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
              ),
            );
          }).toList(),

        const SizedBox(height: 20),
        Text('Ringkasan Jurnal Emosi AI (Dibagikan Pasien)', style: AppTypography.headingSmall),
        const SizedBox(height: 10),
        if (patient.sharedDiarySummaries != null)
          ...patient.sharedDiarySummaries!.map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s, style: AppTypography.bodySmall.copyWith(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildDassPill(String label, int score, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: AppTypography.bodySmall.copyWith(fontSize: 10, color: color)),
            const SizedBox(height: 2),
            Text(
              '$score',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
