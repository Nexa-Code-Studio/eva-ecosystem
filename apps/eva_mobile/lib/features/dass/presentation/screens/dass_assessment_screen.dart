import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_back_button.dart';
import '../../../../widgets/app_snack_bar.dart';
import '../../../../widgets/staggered_entrance.dart';
import '../providers/dass_provider.dart';
import '../widgets/dass_floating_save_bar.dart';
import '../widgets/dass_question_card.dart';
import '../widgets/dass_skeleton_loader.dart';
import '../widgets/dass_subscale_info_sheet.dart';
import '../widgets/dass_subscales_card.dart';

/// Screen for displaying, reviewing, and verifying DASS-21 psychological self-assessments
/// with period filtering, explainable AI accordion insights, and 3-subscale evaluations.
class DASSAssessmentScreen extends ConsumerStatefulWidget {
  final String initialPeriod;

  const DASSAssessmentScreen({
    super.key,
    this.initialPeriod = 'today',
  });

  @override
  ConsumerState<DASSAssessmentScreen> createState() => _DASSAssessmentScreenState();
}

class _DASSAssessmentScreenState extends ConsumerState<DASSAssessmentScreen> {
  late String _currentPeriod;
  String _selectedFilter = 'all'; // 'all', 'stress', 'anxiety', 'depression'
  final Set<int> _expandedItemIds = {};

  static const String _whatsappEmergencyUrl =
      'https://api.whatsapp.com/send/?phone=6281380073120&text=halo%20kak%2C%20saya%20ingin%20bercerita%20mengenai...&type=phone_number&app_absent=0';

  @override
  void initState() {
    super.initState();
    _currentPeriod = widget.initialPeriod;
  }

  Future<void> _openWhatsappEmergency() async {
    final uri = Uri.parse(_whatsappEmergencyUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            'Tidak dapat membuka WhatsApp Konseling Krisis',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dassState = ref.watch(dassAssessmentNotifierProvider);
    final notifier = ref.read(dassAssessmentNotifierProvider.notifier);
    final isEditable = _currentPeriod == 'today';

    final currentAssessment = dassState.assessment.asData?.value;
    final staged = dassState.stagedScores;
    final bool hasChanges = isEditable &&
        currentAssessment != null &&
        currentAssessment.items.any((it) => (staged[it.itemId] ?? it.score) != it.score);
    final int changedCount = currentAssessment != null
        ? currentAssessment.items
            .where((it) => (staged[it.itemId] ?? it.score) != it.score)
            .length
        : 0;
    final bool isUnverified = currentAssessment != null && !currentAssessment.verifiedByUser;
    final bool showSaveBar =
        isEditable && currentAssessment != null && (hasChanges || isUnverified);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF6F8FF),
                  Color(0xFFEFF2FE),
                  Color(0xFFF8F9FE),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  StaggeredEntrance(
                    index: 0,
                    child: _buildTopBar(context, notifier),
                  ),
                  StaggeredEntrance(
                    index: 1,
                    child: _buildPeriodSelector(),
                  ),
                  Expanded(
                    child: dassState.assessment.when(
                      loading: () => const DassSkeletonLoader(),
                      error: (err, _) => RefreshIndicator(
                        onRefresh: () => notifier.loadTodayAssessment(),
                        color: AppColors.primary,
                        backgroundColor: Colors.white,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Colors.redAccent, size: 44),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Gagal memuat asesmen DASS-21',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E1B4B),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$err',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12, color: Colors.redAccent),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => notifier.loadTodayAssessment(),
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Coba Lagi'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      data: (assessment) {
                        final filteredItems = assessment.items.where((it) {
                          if (_selectedFilter == 'all') return true;
                          return it.scale.toLowerCase() == _selectedFilter.toLowerCase();
                        }).toList();

                        return RefreshIndicator(
                          onRefresh: () => notifier.loadTodayAssessment(),
                          color: AppColors.primary,
                          backgroundColor: Colors.white,
                          displacement: 24,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            children: [
                              StaggeredEntrance(
                                index: 2,
                                child: _buildModeBanner(isEditable),
                              ),
                              const SizedBox(height: 16),
                              StaggeredEntrance(
                                index: 3,
                                child: DassSubscalesCard(
                                  assessment: assessment,
                                  stagedScores: staged,
                                  onInfoTap: () => DassSubscaleInfoSheet.showGuideDialog(context),
                                  onSubscaleTap: (label, score, severityIndo, scaleType) {
                                    DassSubscaleInfoSheet.show(
                                      context: context,
                                      label: label,
                                      score: score,
                                      severityIndo: severityIndo,
                                      scaleType: scaleType,
                                      scoreColor: DassSubscalesCard.getScoreColor(severityIndo),
                                    );
                                  },
                                  onExtremelySevereTap: (label, score, scaleType) {
                                    DassSubscaleInfoSheet.showPsychologistReferral(
                                      context: context,
                                      label: label,
                                      score: score,
                                      scaleType: scaleType,
                                      onOpenWhatsapp: _openWhatsappEmergency,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              StaggeredEntrance(
                                index: 4,
                                child: _buildFilterChips(assessment.items.length),
                              ),
                              const SizedBox(height: 16),
                              StaggeredEntrance(
                                index: 5,
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredItems.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = filteredItems[index];
                                    final currentScore = staged[item.itemId] ?? item.score;
                                    return DassQuestionCard(
                                      item: item,
                                      currentScore: currentScore,
                                      isEditable: isEditable,
                                      isExpanded: _expandedItemIds.contains(item.itemId),
                                      onToggleExpand: () {
                                        setState(() {
                                          if (_expandedItemIds.contains(item.itemId)) {
                                            _expandedItemIds.remove(item.itemId);
                                          } else {
                                            _expandedItemIds.add(item.itemId);
                                          }
                                        });
                                      },
                                      onScoreChanged: (newScore) =>
                                          notifier.updateScore(item.itemId, newScore),
                                      onUndoAI: () => notifier.updateScore(item.itemId, item.score),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          DassFloatingSaveBar(
            showSaveBar: showSaveBar,
            hasChanges: hasChanges,
            isUnverified: isUnverified,
            changedCount: changedCount,
            isSaving: dassState.isSaving,
            onSave: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final success = await notifier.saveAssessment();
              if (!mounted) return;
              if (success) {
                AppSnackBar.showWithMessenger(
                  scaffoldMessenger,
                  message: 'Asesmen DASS-21 hari ini berhasil diverifikasi dan disimpan!',
                  variant: SnackBarVariant.success,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, DASSAssessmentNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lembar Evaluasi DASS-21',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E1B4B),
                  ),
                ),
                Text(
                  'Depression Anxiety Stress Scale (21 Butir)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Konfirmasi Ekstraksi AI',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E1B4B),
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'Apakah Anda yakin ingin memicu analisis AI untuk mengekstrak 21 butir DASS-21 dari riwayat percakapan hari ini?\n\n'
                    'Proses ini akan menganalisis transkrip percakapan terbaru untuk mendeteksi indikator emosi Anda.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF4B5563),
                      height: 1.45,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: Text(
                        'Ekstrak Sekarang',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm != true || !mounted) return;

              AppSnackBar.showPrimary(
                this.context,
                'Menganalisis dan mengekstrak DASS-21 dari riwayat dialog hari ini...',
                duration: const Duration(seconds: 4),
                leading: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              );
              await notifier.extractTodayAssessment();
            },
            icon: const Icon(Icons.auto_awesome, size: 20, color: Color(0xFF7C3AED)),
            tooltip: 'Ekstrak AI dari Percakapan Hari Ini',
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = [
      {'key': 'today', 'label': 'Hari Ini'},
      {'key': 'week', 'label': 'Minggu Ini'},
      {'key': 'month', 'label': 'Bulan Ini'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: periods.map((p) {
          final isSelected = p['key'] == _currentPeriod;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentPeriod = p['key']!;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    p['label']!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModeBanner(bool isEditable) {
    if (isEditable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mode Koreksi Mandiri: Anda dapat menyesuaikan skor DASS-21 hasil sintesis AI hari ini.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E40AF),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Color(0xFF64748B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Arsip Historis: Data asesmen hari sebelumnya tersimpan secara permanen untuk evaluasi klinis.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(int totalCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('all', 'Semua ($totalCount)'),
          const SizedBox(width: 8),
          _buildChip('stress', 'Stres (7)'),
          const SizedBox(width: 8),
          _buildChip('anxiety', 'Kecemasan (7)'),
          const SizedBox(width: 8),
          _buildChip('depression', 'Depresi (7)'),
        ],
      ),
    );
  }

  Widget _buildChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1B4B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
