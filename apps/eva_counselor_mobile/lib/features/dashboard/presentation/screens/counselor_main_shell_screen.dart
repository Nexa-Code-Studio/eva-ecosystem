import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finances/presentation/screens/transaction_history_screen.dart';
import '../../../patients/presentation/screens/patient_list_screen.dart';
import '../providers/counselor_nav_provider.dart';
import '../widgets/counselor_spotlight_tour.dart';
import 'counselor_home_screen.dart';

class CounselorMainShellScreen extends ConsumerStatefulWidget {
  const CounselorMainShellScreen({super.key});

  @override
  ConsumerState<CounselorMainShellScreen> createState() =>
      _CounselorMainShellScreenState();
}

class _CounselorMainShellScreenState
    extends ConsumerState<CounselorMainShellScreen> {
  final List<Widget> _pages = const [
    CounselorHomeScreen(),
    PatientListScreen(),
    TransactionHistoryScreen(),
    _CounselorProfileTab(),
  ];

  final List<GlobalKey> _navKeys = List.generate(4, (_) => GlobalKey());
  bool _showSpotlight = false;
  int _spotlightStep = 0;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeTour();
  }

  Future<void> _checkFirstTimeTour() async {
    final hasSeen = await CounselorSpotlightTourOverlay.hasSeenTour();
    if (!hasSeen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showSpotlight = true;
            _spotlightStep = 0;
          });
          ref.read(counselorBottomNavIndexProvider.notifier).state = 0;
        }
      });
    }
  }

  Offset _getNavCenter(int index) {
    final key = _navKeys[index];
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final pos = renderBox.localToGlobal(Offset.zero);
      return Offset(pos.dx + renderBox.size.width / 2, pos.dy + renderBox.size.height / 2);
    }
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final itemWidth = (size.width - 40) / 4;
    final x = 20 + (index + 0.5) * itemWidth;
    final y = size.height - 20 - bottomPadding - 34;
    return Offset(x, y);
  }

  void _nextSpotlightStep() {
    if (_spotlightStep < CounselorSpotlightTourOverlay.steps.length - 1) {
      setState(() {
        _spotlightStep++;
      });
      ref.read(counselorBottomNavIndexProvider.notifier).state = _spotlightStep;
    } else {
      _finishSpotlight();
    }
  }

  Future<void> _finishSpotlight() async {
    await CounselorSpotlightTourOverlay.markTourSeen();
    if (mounted) {
      setState(() {
        _showSpotlight = false;
        _spotlightStep = 0;
      });
      ref.read(counselorBottomNavIndexProvider.notifier).state = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(counselorBottomNavIndexProvider);

    ref.listen(triggerCounselorSpotlightTourProvider, (previous, next) {
      if (next > 0 && mounted) {
        setState(() {
          _spotlightStep = 0;
          _showSpotlight = true;
        });
        ref.read(counselorBottomNavIndexProvider.notifier).state = 0;
      }
    });

    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: Container(
            margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.glassShadow,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.glassBorder, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildNavItem(0, currentIndex, Icons.home_rounded, Icons.home_outlined, 'Beranda')),
                      Expanded(child: _buildNavItem(1, currentIndex, Icons.people_alt_rounded, Icons.people_alt_outlined, 'Pasien')),
                      Expanded(child: _buildNavItem(2, currentIndex, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Keuangan')),
                      Expanded(child: _buildNavItem(3, currentIndex, Icons.person_rounded, Icons.person_outline, 'Profil')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_showSpotlight)
          CounselorSpotlightTourOverlay(
            currentStep: _spotlightStep,
            targetCenter: _getNavCenter(_spotlightStep),
            onNext: _nextSpotlightStep,
            onSkip: _finishSpotlight,
          ),
      ],
    );
  }

  Widget _buildNavItem(int index, int currentIndex, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      key: _navKeys[index],
      onTap: () => ref.read(counselorBottomNavIndexProvider.notifier).state = index,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class EvaCertificateEntity {
  final String id;
  final String title;
  final String subtitle;
  final String recipientName;
  final String milestoneCriteria;
  final String certificateNumber;
  final String issueDate;
  final String categoryLabel;
  final String description;
  final Color badgeColor;

  const EvaCertificateEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.recipientName,
    required this.milestoneCriteria,
    required this.certificateNumber,
    required this.issueDate,
    required this.categoryLabel,
    required this.description,
    this.badgeColor = const Color(0xFFD97706),
  });
}

class _CounselorProfileTab extends ConsumerStatefulWidget {
  const _CounselorProfileTab();

  @override
  ConsumerState<_CounselorProfileTab> createState() => _CounselorProfileTabState();
}

class _CounselorProfileTabState extends ConsumerState<_CounselorProfileTab> {
  final List<String> _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  final Set<String> _activeDays = {'Sen', 'Sel', 'Rab', 'Kam', 'Jum'};
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  String _workingHours = '09:00 - 17:00 WIB';
  bool _isVacationMode = false;
  int _sessionDuration = 50;
  int _bufferTime = 15;
  bool _isBackingUp = false;
  String _backupFrequency = 'Harian';
  bool _backupWifiOnly = true;

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // 1. MANUAL WORKING HOURS PICKER (DENGAN showTimePicker)
  Future<void> _showEditWorkingHoursModal() async {
    TimeOfDay tempStart = _startTime;
    TimeOfDay tempEnd = _endTime;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ubah Jam Operasional Praktik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih jam mulai dan jam selesai praktik secara manual dengan tombol di bawah:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),

              // Manual Time Picker Cards
              Row(
                children: [
                  // JAM MULAI
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: tempStart,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: AppColors.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() => tempStart = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFECEFF8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jam Mulai Praktik', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  '${_formatTimeOfDay(tempStart)} WIB',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, color: AppColors.textLight, size: 18),
                  ),
                  // JAM SELESAI
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: tempEnd,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: AppColors.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() => tempEnd = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFECEFF8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jam Selesai Praktik', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.access_time_filled_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  '${_formatTimeOfDay(tempEnd)} WIB',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick Presets
              const Text('Atau Pilih Preset Cepat:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPresetTimeChip('09:00 - 17:00 (Standar)', () {
                    setModalState(() {
                      tempStart = const TimeOfDay(hour: 9, minute: 0);
                      tempEnd = const TimeOfDay(hour: 17, minute: 0);
                    });
                  }),
                  _buildPresetTimeChip('08:00 - 16:00 (Pagi)', () {
                    setModalState(() {
                      tempStart = const TimeOfDay(hour: 8, minute: 0);
                      tempEnd = const TimeOfDay(hour: 16, minute: 0);
                    });
                  }),
                  _buildPresetTimeChip('13:00 - 21:00 (Sore)', () {
                    setModalState(() {
                      tempStart = const TimeOfDay(hour: 13, minute: 0);
                      tempEnd = const TimeOfDay(hour: 21, minute: 0);
                    });
                  }),
                  _buildPresetTimeChip('18:00 - 22:00 (Malam)', () {
                    setModalState(() {
                      tempStart = const TimeOfDay(hour: 18, minute: 0);
                      tempEnd = const TimeOfDay(hour: 22, minute: 0);
                    });
                  }),
                ],
              ),
              const SizedBox(height: 20),

              // Save Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  setState(() {
                    _startTime = tempStart;
                    _endTime = tempEnd;
                    _workingHours = '${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)} WIB';
                  });
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Jam Praktik Diperbarui',
                    message: 'Jam operasional berhasil disetel ke $_workingHours',
                    type: ToastType.success,
                  );
                },
                child: const Text('Simpan Jam Operasional', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetTimeChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F3FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
    );
  }

  // 2. PATIENT REVIEWS MODAL
  void _showPatientReviewsModal() {
    final reviews = [
      {
        'name': 'R**** P****',
        'topic': 'Konseling Kecemasan & Insomnia',
        'rating': 5,
        'date': '2 hari lalu',
        'comment': 'dr. Sarah sangat mendengarkan tanpa menghakimi. Teknik regulasi napas dan CBT yang diajarkan sangat membantu mengendalikan serangan panik saya. Terima kasih banyak!',
        'tag': 'Sangat Empatik',
      },
      {
        'name': 'M**** S****',
        'topic': 'Burnout Akademik & Skripsi',
        'rating': 5,
        'date': '5 hari lalu',
        'comment': 'Sesi konsultasi sangat terstruktur dan menenangkan. Saya mendapat sudut pandang baru dan langkah tindak lanjut yang sangat realistis untuk dijalankan.',
        'tag': 'Solutif & Tenang',
      },
      {
        'name': 'A**** N****',
        'topic': 'Regulasi Emosi & Hubungan',
        'rating': 5,
        'date': '1 minggu lalu',
        'comment': 'Dokter sangat ramah, hangat, dan memberikan insight mendalam tentang pola komunikasi saya dengan keluarga.',
        'tag': 'Insight Mendalam',
      },
      {
        'name': 'D**** K****',
        'topic': 'Stres Kerja & Manajemen Waktu',
        'rating': 4,
        'date': '2 minggu lalu',
        'comment': 'Sangat membantu memetakan prioritas hidup. Telekonsultasi tepat waktu dan rangkuman SOAP Luna sangat memudahkan saya mereview kembali.',
        'tag': 'Tepat Waktu',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E4EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ulasan & Penilaian Pasien', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),

              // Overall Score Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FD),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Row(
                  children: [
                    Column(
                      children: const [
                        Text('4.9', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                            Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                            Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                            Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                            Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text('140 Ulasan', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          _buildRatingBar('5 ⭐', 0.92, '130'),
                          const SizedBox(height: 4),
                          _buildRatingBar('4 ⭐', 0.06, '8'),
                          const SizedBox(height: 4),
                          _buildRatingBar('3 ⭐', 0.02, '2'),
                          const SizedBox(height: 4),
                          _buildRatingBar('2 ⭐', 0.0, '0'),
                          const SizedBox(height: 4),
                          _buildRatingBar('1 ⭐', 0.0, '0'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Highlight Tags (Wrap agar tidak overflow)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildReviewTagPill('❤️ Sangat Empatik (98%)'),
                  _buildReviewTagPill('💡 Solutif (95%)'),
                  _buildReviewTagPill('⏱️ Tepat Waktu (99%)'),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Testimoni Pasien (Anonim demi Privasi):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),

              ...reviews.map((r) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primaryContainer,
                                child: const Icon(Icons.person, size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(r['topic'] as String, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                          Text(r['date'] as String, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...List.generate(
                            r['rating'] as int,
                            (_) => const Icon(Icons.star_rounded, color: AppColors.warning, size: 14),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r['tag'] as String,
                              style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r['comment'] as String,
                        style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingBar(String label, double pct, String count) {
    return Row(
      children: [
        SizedBox(width: 26, child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFFE5E9F2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(width: 22, child: Text(count, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
      ],
    );
  }

  Widget _buildReviewTagPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }

  // 4. EDIT DURATION & BUFFER MODAL (DURASI & BUFFER BEBAS PILIH / MANUAL STEPPER)
  void _showEditDurationAndBufferModal() {
    int tempDuration = _sessionDuration;
    int tempBuffer = _bufferTime;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Durasi Sesi & Jeda Istirahat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Tentukan durasi panggilan konsultasi dan waktu istirahat antar pasien secara fleksibel:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // DURASI SESI DENGAN COUNTER STEPPER MANUAL & CHIPS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Durasi Konseling:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECEFF8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16, color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempDuration > 15) {
                              setModalState(() => tempDuration -= 5);
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$tempDuration Menit',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempDuration < 180) {
                              setModalState(() => tempDuration += 5);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [30, 45, 50, 60, 75, 90].map((dur) {
                  final isSelected = tempDuration == dur;
                  return GestureDetector(
                    onTap: () => setModalState(() => tempDuration = dur),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFF7F8FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFECEFF8),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        '$dur Mnt${dur == 50 ? " (Standar)" : ""}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // JEDA BUFFER DENGAN COUNTER STEPPER MANUAL & CHIPS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Jeda Istirahat (Buffer Time):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECEFF8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16, color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempBuffer > 0) {
                              setModalState(() => tempBuffer -= 5);
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$tempBuffer Menit',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempBuffer < 60) {
                              setModalState(() => tempBuffer += 5);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [0, 5, 10, 15, 20, 30].map((buf) {
                  final isSelected = tempBuffer == buf;
                  return GestureDetector(
                    onTap: () => setModalState(() => tempBuffer = buf),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFF7F8FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFECEFF8),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        buf == 0 ? 'Tanpa Jeda' : '$buf Mnt${buf == 15 ? " (Disarankan)" : ""}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total slot waktu: ${tempDuration + tempBuffer} menit ($tempDuration mnt telekonseling + $tempBuffer mnt review SOAP).',
                        style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  setState(() {
                    _sessionDuration = tempDuration;
                    _bufferTime = tempBuffer;
                  });
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Durasi Sesi Diperbarui',
                    message: 'Sesi ditetapkan ke $_sessionDuration menit dengan jeda istirahat $_bufferTime menit.',
                    type: ToastType.success,
                  );
                },
                child: const Text('Simpan Durasi Sesi', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 5. BANK ACCOUNT MODAL
  void _showBankAccountModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Rekening Bank Pencairan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Rekening terdaftar untuk pencairan otomatis honorarium praktik Anda:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Card Bank
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BCA (Bank Central Asia)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('UTAMA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '•••• •••• •••• 8192',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('dr. Sarah Jenkins, M.Psi', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('TERVERIFIKASI ✅', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFECEFF8)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.schedule_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pencairan dana otomatis diproses setiap hari Jumat pukul 15:00 WIB ke rekening di atas tanpa potongan biaya transfer.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD6D9E4)),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
              label: const Text('Ubah Rekening Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
              onPressed: () {
                Navigator.pop(ctx);
                TopToast.show(
                  context,
                  title: 'Verifikasi Rekening',
                  message: 'Permintaan perubahan rekening bank memerlukan verifikasi KTP & SIPP (1x24 jam).',
                  type: ToastType.info,
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // 6. STR & SIPP CREDENTIALS MODAL
  void _showStrCredentialsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kredensial SIPP & STR Psikolog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Kredensial klinis resmi Anda yang terverifikasi di Kementerian Kesehatan & HIMPSI:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.verifiedBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.verifiedGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Surat Tanda Registrasi (STR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.verifiedGreen)),
                      Icon(Icons.verified_rounded, color: AppColors.verifiedGreen, size: 18),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Nomor: 4192-PSI-2024', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  const Text('Penerbit: KTKI (Konsil Tenaga Kesehatan Indonesia)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  const Text('Masa Berlaku: 18 Oktober 2029 (Aktif)', style: TextStyle(fontSize: 11, color: AppColors.verifiedGreen, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECEFF8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Surat Izin Praktik Psikologi (SIPP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                  SizedBox(height: 6),
                  Text('Nomor: 503/SIPP/DKS/2023', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Wilayah Layanan: Nasional (Telekonsultasi)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  SizedBox(height: 2),
                  Text('Keanggotaan HIMPSI: Aktif (#HM-9214)', style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 18),

            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD6D9E4)),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                TopToast.show(
                  context,
                  title: 'Perpanjangan Kredensial',
                  message: 'Upload pembaruan STR/SIPP melalui portal web admin psikolog.',
                  type: ToastType.info,
                );
              },
              child: const Text('Perbarui Dokumen Kredensial', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // 7. SECURITY & PRIVACY MODAL
  void _showSecuritySettingsModal() {
    bool biometric = true;
    bool twoFactor = true;
    bool maskPatient = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Keamanan & Privasi Klinis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Perlindungan data pasien sesuai standar kerahasiaan medis & HIPAA:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),

              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kunci Biometrik (Face ID / Sidik Jari)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Wajib autentikasi sebelum membuka rekam medis pasien', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                value: biometric,
                activeColor: AppColors.primary,
                onChanged: (val) => setModalState(() => biometric = val),
              ),
              const Divider(height: 1, color: Color(0xFFF0F2F8)),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Verifikasi 2 Langkah (2FA)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Kode OTP saat login di perangkat baru', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                value: twoFactor,
                activeColor: AppColors.primary,
                onChanged: (val) => setModalState(() => twoFactor = val),
              ),
              const Divider(height: 1, color: Color(0xFFF0F2F8)),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Masking Nama Pasien di Notifikasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Sembunyikan nama terang pasien pada notifikasi layar kunci', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                value: maskPatient,
                activeColor: AppColors.primary,
                onChanged: (val) => setModalState(() => maskPatient = val),
              ),
              const SizedBox(height: 18),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Keamanan Diperbarui',
                    message: 'Pengaturan keamanan rekam medis berhasil disimpan.',
                    type: ToastType.success,
                  );
                },
                child: const Text('Simpan Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // 8. ETHICAL GUIDELINES MODAL
  void _showEthicalGuidelinesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Panduan Etik & SOP HIMPSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Standar Operasional Prosedur Layanan Telekonseling Luna:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            _buildEthicItem('1. Kerahasiaan & Batas Etik', 'Data rekam medis SOAP terenkripsi end-to-end dan hanya dapat diakses psikolog penanggung jawab.'),
            const SizedBox(height: 8),
            _buildEthicItem('2. Protokol De-eskalasi Krisis', 'Jika skor DASS-21 atau deteksi Luna AI menunjukkan risiko self-harm, psikolog wajib mengaktifkan hotline darurat.'),
            const SizedBox(height: 8),
            _buildEthicItem('3. Dokumentasi SOAP Tepat Waktu', 'Psikolog diharapkan mereview dan memverifikasi draft auto-SOAP Luna maksimal 24 jam setelah sesi selesai.'),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildEthicItem(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
        ],
      ),
    );
  }

  void _showPeerCounselorGuidelinesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: Color(0xFF0284C7), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Panduan Etika Teman Sebaya',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Pedoman Etik Pendampingan Non-Klinis & Batasan Peran Relawan Eva:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              _buildEthicItem(
                '1. Batasan Peran Sebaya (Non-Klinis)',
                'Relawan berperan murni sebagai teman curhat & pendengar aktif yang suportif. Tidak berwenang memberikan diagnosis klinis atau saran medis.',
              ),
              const SizedBox(height: 8),
              _buildEthicItem(
                '2. Tanpa Beban Rekam Medis SOAP',
                'Sesi pendampingan teman sebaya bebas dari kewajiban rekam SOAP klinis. Fokus utama Anda adalah hadir penuh bagi teman curhat.',
              ),
              const SizedBox(height: 8),
              _buildEthicItem(
                '3. Protokol Deteksi & Eskalasi Bahaya',
                'Apabila teman curhat menunjukkan indikasi melukai diri (self-harm) atau krisis berat, wajib segera arahkan atau eskalasi ke Psikolog Profesional.',
              ),
              const SizedBox(height: 8),
              _buildEthicItem(
                '4. Kerahasiaan Penuh & Tanpa Penghakiman',
                'Seluruh cerita dijaga kerahasiaannya dengan penerimaan tulus dan empati tanpa menghakimi latar belakang teman curhat.',
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Saya Mengerti & Sepakat', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showDriveBackupSettingsModal(PsychologistUserEntity? user) {
    String tempFreq = _backupFrequency;
    bool tempWifi = _backupWifiOnly;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pengaturan Cadangan Google Drive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Rekam medis terenkripsi dicadangkan ke Google Drive pribadi Anda:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Frekuensi: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  ...['Harian', 'Mingguan', 'Manual'].map((f) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: tempFreq == f,
                          onSelected: (_) => setModalState(() => tempFreq = f),
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cadangkan Hanya Melalui Wi-Fi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Hindari penggunaan kuota seluler untuk pencadangan', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                value: tempWifi,
                activeColor: AppColors.primary,
                onChanged: (val) => setModalState(() => tempWifi = val),
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Simpan Preferensi',
                onPressed: () {
                  setState(() {
                    _backupFrequency = tempFreq;
                    _backupWifiOnly = tempWifi;
                  });
                  ref.read(authStateProvider.notifier).syncDriveBackup(
                        email: user?.googleDriveEmail ?? 'sarah.anindya@gmail.com',
                        frequency: tempFreq,
                      );
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Preferensi Cadangan Disimpan',
                    message: 'Jadwal cadangan otomatis Google Drive diatur ke $tempFreq.',
                    type: ToastType.success,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBackupNow(PsychologistUserEntity? user) async {
    setState(() => _isBackingUp = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _isBackingUp = false);

    ref.read(authStateProvider.notifier).syncDriveBackup(
          email: user?.googleDriveEmail ?? 'sarah.anindya@gmail.com',
          frequency: _backupFrequency,
        );

    TopToast.show(
      context,
      title: 'Pencadangan Berhasil! ☁️',
      message: '18.4 MB data rekam SOAP & audio transkrip terenkripsi aman di Google Drive Anda.',
      type: ToastType.success,
    );
  }

  void _handleRestoreDrive() async {
    TopToast.show(
      context,
      title: 'Memeriksa Cadangan Google Drive...',
      message: 'Data lokal terverifikasi sinkron dengan cadangan cloud terakhir (Hari ini, 10:15 WIB).',
      type: ToastType.info,
    );
  }

  void _showEditCoinsRateModal(PsychologistUserEntity? user) {
    int currentCoins = user?.coinsPerSession ?? 150;
    final coinsList = [50, 100, 150, 200, 250, 300, 500];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Atur Tarif Koin per Sesi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pasien membayar sesi konsultasi dengan Koin. 1 Koin = Rp 1.000.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: coinsList.map((c) {
                  final isSelected = currentCoins == c;
                  return GestureDetector(
                    onTap: () => setModalState(() => currentCoins = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFC2410C) : const Color(0xFFF7F8FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFC2410C) : const Color(0xFFECEFF8),
                        ),
                      ),
                      child: Text(
                        '$c Koin (≈ Rp ${_formatNumber(c * 1000)})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: 'Simpan Tarif Koin',
                onPressed: () {
                  ref.read(authStateProvider.notifier).updateSessionSettings(
                        sessionDurationMinutes: _sessionDuration,
                        coinsPerSession: currentCoins,
                      );
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Tarif Koin Berhasil Disimpan',
                    message: 'Tarif sesi konsultasi kini $currentCoins Koin (≈ Rp ${_formatNumber(currentCoins * 1000)}).',
                    type: ToastType.success,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpgradeRoleModal(BuildContext context) {
    final strCtrl = TextEditingController();
    final assocCtrl = TextEditingController(text: 'HIMPSI');
    final partnerCtrl = TextEditingController();
    CounselorRole targetRole = CounselorRole.professionalIndependent;
    String? pickedFile;
    bool isUpgrading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isMandiri = targetRole == CounselorRole.professionalIndependent;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Upgrade ke Psikolog Profesional',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Daftarkan nomor STR/SIPP aktif untuk membuka dompet koin dan rekam SOAP klinis.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Segmented Role Switcher (Soft borders, NO harsh black outline)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => targetRole = CounselorRole.professionalIndependent),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isMandiri ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isMandiri ? const Color(0xFFECEFF8) : Colors.transparent,
                                ),
                                boxShadow: isMandiri
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 15,
                                    color: isMandiri ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Praktik Mandiri',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isMandiri ? FontWeight.bold : FontWeight.w500,
                                      color: isMandiri ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => targetRole = CounselorRole.professionalPartner),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isMandiri ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !isMandiri ? const Color(0xFFECEFF8) : Colors.transparent,
                                ),
                                boxShadow: !isMandiri
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.apartment_rounded,
                                    size: 15,
                                    color: !isMandiri ? const Color(0xFF7E22CE) : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Dengan Mitra',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: !isMandiri ? FontWeight.bold : FontWeight.w500,
                                      color: !isMandiri ? const Color(0xFF7E22CE) : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!isMandiri) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF7E22CE), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Akun psikolog mitra diatur jadwal dan tarif koinnya via Web Portal Mitra.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF6B21A8), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Form Input STR
                  const Text('Nomor STR / SIPP Aktif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFECEFF8)),
                    ),
                    child: TextField(
                      controller: strCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Misal: 4192-PSI-2024',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textLight),
                        prefixIcon: Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Form Organisasi Profesi
                  const Text('Organisasi Profesi Psikologi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFECEFF8)),
                    ),
                    child: TextField(
                      controller: assocCtrl,
                      decoration: const InputDecoration(
                        hintText: 'HIMPSI / IPK Indonesia',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textLight),
                        prefixIcon: Icon(Icons.account_balance_outlined, size: 18, color: AppColors.primary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),

                  if (!isMandiri) ...[
                    const SizedBox(height: 12),
                    const Text('Nama Lembaga / RS Mitra', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFECEFF8)),
                      ),
                      child: TextField(
                        controller: partnerCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Misal: RS Jiwa Sanjiwani / PT Sehat Jiwa',
                          hintStyle: TextStyle(fontSize: 13, color: AppColors.textLight),
                          prefixIcon: Icon(Icons.apartment_rounded, size: 18, color: Color(0xFF7E22CE)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Upload STR Document Container (Clean & Soft)
                  const Text('Unggah Berkas Bukti STR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      setModalState(() {
                        pickedFile = 'STR_Verified_${DateTime.now().year}.pdf';
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: pickedFile != null ? AppColors.verifiedBg : const Color(0xFFF7F8FC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: pickedFile != null ? const Color(0xFFBBF7D0) : const Color(0xFFECEFF8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: pickedFile != null ? const Color(0xFFDCFCE7) : AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              pickedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                              size: 18,
                              color: pickedFile != null ? AppColors.verifiedGreen : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickedFile ?? 'Pilih File Scan STR (PDF/JPG)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: pickedFile != null ? AppColors.verifiedGreen : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pickedFile != null ? 'Berkas siap diverifikasi (1.8 MB)' : 'Maksimal 5 MB • Kerahasiaan terenkripsi',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Button Upgrade
                  CustomButton(
                    label: 'Verifikasi & Upgrade Sekarang',
                    isLoading: isUpgrading,
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () async {
                      if (strCtrl.text.isEmpty) {
                        TopToast.show(
                          context,
                          title: 'Nomor STR Wajib Diisi',
                          message: 'Mohon masukkan nomor STR/SIPP Anda.',
                          type: ToastType.error,
                        );
                        return;
                      }

                      setModalState(() => isUpgrading = true);
                      ref.read(authStateProvider.notifier).upgradeToProfessional(
                            strNumber: strCtrl.text,
                            association: assocCtrl.text,
                            certificateDocFileName: pickedFile ?? 'STR_Uploaded.pdf',
                            newRole: targetRole,
                            partnerName: targetRole == CounselorRole.professionalPartner
                                ? partnerCtrl.text
                                : null,
                          );

                      await Future.delayed(const Duration(milliseconds: 500));
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (!context.mounted) return;

                      TopToast.show(
                        context,
                        title: 'Akun Berhasil Di-Upgrade!',
                        message:
                            'Selamat! Akun Anda kini aktif sebagai Psikolog Profesional dengan akses dompet koin.',
                        type: ToastType.success,
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

  Widget _buildBenefitPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildRoleSwitcherChip(String label, CounselorRole role, CounselorRole? currentRole) {
    final isSelected = currentRole == role;
    return GestureDetector(
      onTap: () {
        ref.read(authStateProvider.notifier).switchRole(role);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFECEFF8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  List<EvaCertificateEntity> _getCertificatesForUser(PsychologistUserEntity? user) {
    final name = user?.displayName ?? 'dr. Sarah Jenkins, M.Psi';
    final isVol = user?.isVolunteer == true;

    if (isVol) {
      return [
        EvaCertificateEntity(
          id: 'CERT-VOL-01',
          title: 'SERTIFIKAT KELULUSAN PEER COUNSELOR',
          subtitle: 'Certified Active Listener & Support Specialist',
          recipientName: name,
          milestoneCriteria: 'Lulus Uji Etika & Pelatihan Konseling Sebaya',
          certificateNumber: 'EVA/CERT/2026/VOL/00094',
          issueDate: '15 Oktober 2026',
          categoryLabel: 'Relawan Teman Sebaya',
          description:
              'Diberikan atas kelulusan program sertifikasi pendampingan emosional, komunikasi empatik non-klinis, dan kepatuhan penuh terhadap etika teman sebaya Eva.',
          badgeColor: const Color(0xFF0284C7),
        ),
        EvaCertificateEntity(
          id: 'CERT-VOL-02',
          title: 'SERTIFIKAT DEDIKASI TEMAN SEBAYA',
          subtitle: 'Community Mental Health Dedication Award',
          recipientName: name,
          milestoneCriteria: 'Menyelesaikan 10 Sesi Curhat Komunitas',
          certificateNumber: 'EVA/CERT/2026/VOL/00148',
          issueDate: '01 November 2026',
          categoryLabel: 'Relawan Teman Sebaya',
          description:
              'Diberikan sebagai penghargaan atas ketulusan mendengarkan aktif dan mendampingi keluhan emosional teman sebaya di ekosistem kesehatan mental Eva.',
          badgeColor: const Color(0xFFD97706),
        ),
        EvaCertificateEntity(
          id: 'CERT-VOL-03',
          title: 'SERTIFIKAT KONTRIBUTOR EMPATI SEBAYA',
          subtitle: 'Excellence in Community Empathy 2026',
          recipientName: name,
          milestoneCriteria: 'Pendampingan 25 Sesi Tanpa Keluhan & Rating 5.0',
          certificateNumber: 'EVA/CERT/2026/VOL/00220',
          issueDate: '05 November 2026',
          categoryLabel: 'Relawan Teman Sebaya',
          description:
              'Diberikan atas kontribusi konsisten menjaga ruang aman bebas penghakiman, memberikan pertolongan pertama psikologis suportif bagi sesama.',
          badgeColor: const Color(0xFF16A34A),
        ),
      ];
    } else {
      return [
        EvaCertificateEntity(
          id: 'CERT-PRO-01',
          title: 'SERTIFIKAT PRAKTIK TELEKONSELING KLINIS',
          subtitle: 'Clinical Tele-Psychology Excellence & Competence',
          recipientName: name,
          milestoneCriteria: 'Penyelesaian 25 Sesi Klinis Terverifikasi',
          certificateNumber: 'EVA/CERT/2026/PRO/00341',
          issueDate: '20 Oktober 2026',
          categoryLabel: user?.isPartner == true ? 'Psikolog Mitra' : 'Psikolog Mandiri',
          description:
              'Diberikan atas dedikasi dan kompetensi klinis prima dalam menyelenggarakan telekonsultasi kesehatan mental dengan standar etika tertinggi.',
          badgeColor: const Color(0xFF2563EB),
        ),
        EvaCertificateEntity(
          id: 'CERT-PRO-02',
          title: 'SERTIFIKAT KEPATUHAN REKAM MEDIS SOAP',
          subtitle: 'Certified Clinical Medical Record Standard',
          recipientName: name,
          milestoneCriteria: 'Kepatuhan Rekam SOAP 100% pada 50 Sesi',
          certificateNumber: 'EVA/CERT/2026/PRO/00512',
          issueDate: '02 November 2026',
          categoryLabel: user?.isPartner == true ? 'Psikolog Mitra' : 'Psikolog Mandiri',
          description:
              'Diberikan atas komitmen integritas dokumentasi SOAP klinis (Subjective, Objective, Assessment, Plan) yang terenkripsi aman demi keselamatan pasien.',
          badgeColor: const Color(0xFFD97706),
        ),
        EvaCertificateEntity(
          id: 'CERT-PRO-03',
          title: 'SERTIFIKAT KONSELOR TELADAN EVA 2026',
          subtitle: 'Distinguished Clinical Practitioner 2026',
          recipientName: name,
          milestoneCriteria: '100+ Sesi Terlaksana dengan Rating Kepuasan 4.9+',
          certificateNumber: 'EVA/CERT/2026/PRO/00789',
          issueDate: '06 November 2026',
          categoryLabel: user?.isPartner == true ? 'Psikolog Mitra' : 'Psikolog Mandiri',
          description:
              'Penghargaan tertinggi platform Eva atas loyalitas pelayanan intervensi krisis, kepuasan pasien bintang lima, dan kontribusi nyata pada kesehatan jiwa bangsa.',
          badgeColor: const Color(0xFF7E22CE),
        ),
      ];
    }
  }

  void _showCertificatesGalleryModal(BuildContext context, PsychologistUserEntity? user) {
    final certs = _getCertificatesForUser(user);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sertifikat & Pencapaian',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${certs.length} Sertifikat resmi diraih berdasarkan milestone',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textSecondary),
                    splashRadius: 22,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: certs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (modalCtx, idx) {
                    final c = certs[idx];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFECEFF8)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: c.badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.military_tech_rounded, color: c.badgeColor, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c.milestoneCriteria,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.issueDate,
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            c.description,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'No: ${c.certificateNumber}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                                label: const Text('Buka & Unduh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.of(modalCtx).pop();
                                  _showOfficialCertificateDialog(context, c);
                                },
                              ),
                            ],
                          ),
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
    );
  }

  void _showOfficialCertificateDialog(BuildContext context, EvaCertificateEntity cert) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 28, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8, left: 16),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Pratinjau Sertifikat Resmi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textSecondary),
                      splashRadius: 22,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDF8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFB45309), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD97706), width: 1.2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('✦', style: TextStyle(color: Color(0xFFB45309), fontSize: 14)),
                              Text('✦', style: TextStyle(color: Color(0xFFB45309), fontSize: 14)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.spa_rounded, color: AppColors.primary, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'EVA MENTAL HEALTH ECOSYSTEM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'LEMBAGA LAYANAN TELEKONSELING & KESEHATAN JIWA TERINTEGRASI',
                            style: TextStyle(
                              fontSize: 7.5,
                              letterSpacing: 0.8,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            cert.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Color(0xFF1E293B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cert.subtitle,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 40, height: 1.2, color: const Color(0xFFD97706)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('★', style: TextStyle(color: Color(0xFFD97706), fontSize: 10)),
                              ),
                              Container(width: 40, height: 1.2, color: const Color(0xFFD97706)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Diberikan dengan penuh hormat & apresiasi kepada:',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cert.recipientName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 8),
                            height: 1.5,
                            width: 140,
                            color: const Color(0xFFD97706),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '★ ${cert.milestoneCriteria} ★',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              cert.description,
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155), height: 1.45),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No: ${cert.certificateNumber}  •  Diterbitkan di Jakarta, ${cert.issueDate}',
                            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                children: [
                                  const Text(
                                    'dr. Robert W., Sp.KJ',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A8A),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Container(height: 1, width: 85, color: const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 2),
                                  const Text('Ketua Komite Medis', style: TextStyle(fontSize: 8, color: Color(0xFF64748B))),
                                ],
                              ),
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    colors: [Color(0xFFFDE68A), Color(0xFFD97706), Color(0xFFB45309)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(color: const Color(0xFFFEF3C7), width: 1.5),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.workspace_premium_rounded, size: 20, color: Colors.white),
                                      Text(
                                        'VERIFIED',
                                        style: TextStyle(
                                          fontSize: 6,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  const Text(
                                    'Nadine L., M.Psi',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A8A),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Container(height: 1, width: 85, color: const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 2),
                                  const Text('Direktur Konseling', style: TextStyle(fontSize: 8, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('✦', style: TextStyle(color: Color(0xFFB45309), fontSize: 14)),
                              Text('✦', style: TextStyle(color: Color(0xFFB45309), fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Tutup', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Unduh Sertifikat (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          TopToast.show(
                            context,
                            title: 'Sertifikat Berhasil Diunduh! 📄',
                            message: 'Tersimpan di unduhan: ${cert.certificateNumber.replaceAll("/", "_")}.pdf',
                            type: ToastType.success,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final userCerts = _getCertificatesForUser(user);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Banner Card (Modern Health App Styling)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: AppColors.primaryContainer,
                          backgroundImage: user?.profilePhotoUrl != null
                              ? NetworkImage(user!.profilePhotoUrl!)
                              : null,
                          child: user?.profilePhotoUrl == null
                              ? const Icon(Icons.person, size: 34, color: AppColors.primary)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'dr. Sarah Jenkins, M.Psi',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? 'sarah.jenkins@psikolog.eva.id',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (user?.isVolunteer == true)
                                    StatusBadge.volunteer('Relawan Teman Sebaya')
                                  else if (user?.isPartner == true)
                                    StatusBadge.proPartner('Psikolog Mitra')
                                  else
                                    StatusBadge.proIndependent('Psikolog Mandiri'),
                                  if (user?.isProfessional == true)
                                    StatusBadge.coins(user?.coinBalance ?? 1250),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Stats Bar (Rating, Sessions, Response Rate) - BISA DIKLIK MENUJU ULASAN!
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FD),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          InkWell(
                            onTap: _showPatientReviewsModal,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: _buildStatItem('⭐ 4.9', '140 Ulasan >'),
                            ),
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E5F0)),
                          _buildStatItem('38', 'Sesi Bulan Ini'),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E5F0)),
                          _buildStatItem('100%', 'Respon Booking'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 1.B. PROMINENT UPGRADE CARD (KHUSUS RELAWAN TEMAN SEBAYA)
              if (user?.isVolunteer == true) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD6E4FF)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Tingkatkan Status Praktik',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Upgrade ke Psikolog Profesional untuk membuka tarif koin honorarium dan rekam klinis SOAP.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildBenefitPill('💰 Tarif Koin'),
                          _buildBenefitPill('📋 Rekam SOAP Medis'),
                          _buildBenefitPill('📜 Sertifikasi Praktisi'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text(
                            'Ajukan Verifikasi STR & Upgrade Sekarang',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _showUpgradeRoleModal(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // CATEGORY SWITCHER PILLS (PREVIEW MODES) - SUBTLE & CLEAN
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    const Text('Pratinjau Peran:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildRoleSwitcherChip('Teman Sebaya', CounselorRole.peerVolunteer, user?.role),
                            const SizedBox(width: 6),
                            _buildRoleSwitcherChip('Mandiri', CounselorRole.professionalIndependent, user?.role),
                            const SizedBox(width: 6),
                            _buildRoleSwitcherChip('Mitra', CounselorRole.professionalPartner, user?.role),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. JADWAL PRAKTIK & OPERASIONAL
              _buildSectionHeader('Hari & Jam Praktik Online', Icons.calendar_month_rounded),

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
                    const Text('Hari Praktik Aktif:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 10),

                    // HARI PRAKTIK AKTIF: CUSTOM DAY SELECTION PILLS (LEGA & BORDER LEMBUT, TIDAK DEMPET & TANPA GARIS TEGAS)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _days.map((day) {
                        final isActive = _activeDays.contains(day);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isActive) {
                                if (_activeDays.length > 1) _activeDays.remove(day);
                              } else {
                                _activeDays.add(day);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.primary : const Color(0xFFF7F8FD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive ? AppColors.primary : const Color(0xFFECEFF8),
                                width: 1.2,
                              ),
                              boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.18),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isActive) ...[
                                  const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  day,
                                  style: TextStyle(
                                    color: isActive ? Colors.white : AppColors.textPrimary,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 24, color: Color(0xFFF0F2F8)),

                    // Jam Praktik (Dapat Diedit Manual)
                    InkWell(
                      onTap: _showEditWorkingHoursModal,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('Jam Operasional Praktik', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _workingHours,
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Durasi Sesi & Buffer Time (KEDUANYA BISA DIKLIK & DIEDIT)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _showEditDurationAndBufferModal,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F8FD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFECEFF8)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Durasi Sesi', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                      const SizedBox(height: 2),
                                      Text('$_sessionDuration Menit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _showEditDurationAndBufferModal,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F8FD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFECEFF8)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Jeda Buffer', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                      const SizedBox(height: 2),
                                      Text('$_bufferTime Menit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFF0F2F8)),

                    // Mode Libur (Vacation Mode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Mode Libur Sementara (Cuti)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            SizedBox(height: 2),
                            Text('Tutup sementara pemesanan slot jadwal baru', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                        Switch.adaptive(
                          value: _isVacationMode,
                          activeColor: AppColors.warning,
                          onChanged: (val) {
                            setState(() => _isVacationMode = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. HONORARIUM & TARIF KOIN (SESUAI PERAN)
              _buildSectionHeader('Honorarium & Keuangan Praktik', Icons.account_balance_wallet_outlined),

              if (user?.isVolunteer == true) ...[
                _buildCleanMenuCard(
                  icon: Icons.workspace_premium_rounded,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primaryContainer,
                  title: 'Upgrade ke Psikolog Profesional',
                  subtitle: 'Daftarkan STR/SIPP untuk membuka dompet koin & rekam SOAP',
                  trailingBadge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Upgrade 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                  onTap: () => _showUpgradeRoleModal(context),
                ),
              ] else if (user?.isPartner == true) ...[
                _buildCleanMenuCard(
                  icon: Icons.apartment_rounded,
                  iconColor: const Color(0xFF7E22CE),
                  iconBg: const Color(0xFFF3E8FF),
                  title: 'Tarif & Keuangan Mitra (Web Portal)',
                  subtitle: 'Koin sesi masuk ke kas lembaga mitra (${user?.partnerName ?? "RS Mitra"})',
                  trailingBadge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Web Mitra', style: TextStyle(color: Color(0xFF7E22CE), fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                  onTap: () {
                    TopToast.show(
                      context,
                      title: 'Pengaturan Koin Mitra',
                      message: 'Sebagai psikolog mitra, tarif koin dikelola oleh administrator mitra via Web Portal.',
                      type: ToastType.info,
                    );
                  },
                ),
              ] else ...[
                _buildCleanMenuCard(
                  icon: Icons.monetization_on_rounded,
                  iconColor: const Color(0xFFC2410C),
                  iconBg: const Color(0xFFFFF7ED),
                  title: 'Tarif Koin Konsultasi',
                  subtitle: '${user?.coinsPerSession ?? 150} Koin per $_sessionDuration menit (≈ Rp ${_formatNumber((user?.coinsPerSession ?? 150) * 1000)})',
                  trailingBadge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${user?.coinsPerSession ?? 150} Koin',
                          style: const TextStyle(color: Color(0xFFC2410C), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined, size: 12, color: Color(0xFFC2410C)),
                      ],
                    ),
                  ),
                  onTap: () => _showEditCoinsRateModal(user),
                ),
                _buildCleanMenuCard(
                  icon: Icons.account_balance_outlined,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFEFF6FF),
                  title: 'Rekening Bank Pencairan Koin',
                  subtitle: 'BCA • ****8192 (dr. Sarah Jenkins)',
                  trailingBadge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.verifiedBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Terverifikasi ✅', style: TextStyle(color: AppColors.verifiedGreen, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                  onTap: _showBankAccountModal,
                ),
              ],

              const SizedBox(height: 16),

              // 4. PENCADANGAN REKAM MEDIS & GOOGLE DRIVE E2EE (GAYA WHATSAPP)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildSectionHeader('Pencadangan Rekam Medis', Icons.cloud_sync_outlined),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.verifiedBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('E2EE 256-bit ✅', style: TextStyle(color: AppColors.verifiedGreen, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Data rekam medis SOAP & audio transkrip tersimpan lokal di perangkat Anda (bukan di server EVA). Cadangkan ke Google Drive pribadi Anda untuk keamanan.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.cloud_sync_rounded, color: AppColors.verifiedGreen, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.googleDriveEmail ?? 'sarah.anindya@gmail.com',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Cadangan: ${user?.lastDriveBackup != null ? "Hari ini, 10:15 WIB (18.4 MB)" : "Belum dicadangkan"} • Otomatis $_backupFrequency',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                          onPressed: () => _showDriveBackupSettingsModal(user),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFF0F2F8)),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFECEFF8)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                            ),
                            icon: const Icon(Icons.cloud_download_outlined, size: 16, color: AppColors.textPrimary),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Pulihkan Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ),
                            onPressed: _handleRestoreDrive,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                            ),
                            icon: _isBackingUp
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.cloud_upload_rounded, size: 16),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _isBackingUp ? 'Mencadangkan...' : 'Cadangkan Sekarang',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            onPressed: _isBackingUp ? null : () => _handleBackupNow(user),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. PENCAPAIAN & SERTIFIKASI EVA (MULTIPLE CERTIFICATES SYSTEM)
              _buildSectionHeader('Pencapaian & Sertifikasi Eva', Icons.military_tech_rounded),

              _buildCleanMenuCard(
                icon: Icons.workspace_premium_rounded,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFEF3C7),
                title: 'Sertifikat Penghargaan & Pencapaian',
                subtitle: '${userCerts.length} Sertifikat Resmi Diraih • Siap Diunduh (PDF)',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${userCerts.length} Sertif 🏆',
                    style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                onTap: () => _showCertificatesGalleryModal(context, user),
              ),
              const SizedBox(height: 16),

              // 6. LEGALITAS & KEAMANAN KLINIS (CLEAN MODERN CARDS)
              _buildSectionHeader('Legalitas & Keamanan Praktik', Icons.verified_user_outlined),

              // Kredensial SIPP & STR hanya untuk profesional (bukan relawan teman sebaya)
              if (user?.isVolunteer != true) ...[
                _buildCleanMenuCard(
                  icon: Icons.verified_user_outlined,
                  iconColor: AppColors.verifiedGreen,
                  iconBg: AppColors.verifiedBg,
                  title: 'Kredensial SIPP & STR Psikolog',
                  subtitle: 'STR #4192-PSI-2024 • KTKI & HIMPSI',
                  trailingBadge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.verifiedBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Aktif 2029', style: TextStyle(color: AppColors.verifiedGreen, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                  onTap: _showStrCredentialsModal,
                ),
              ],

              _buildCleanMenuCard(
                icon: Icons.shield_outlined,
                iconColor: AppColors.primary,
                iconBg: AppColors.secondary,
                title: 'Keamanan Rekam Medis & Privasi',
                subtitle: 'Biometrik FaceID & Enkripsi AES-256',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('2FA Aktif', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
                onTap: _showSecuritySettingsModal,
              ),

              // Panduan Etik sesuai peran
              if (user?.isVolunteer == true) ...[
                _buildCleanMenuCard(
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBg: const Color(0xFFE0F2FE),
                  title: 'Panduan Etika Konselor Teman Sebaya',
                  subtitle: 'Kode etik pendampingan non-klinis & protokol krisis',
                  trailingBadge: const SizedBox.shrink(),
                  onTap: _showPeerCounselorGuidelinesModal,
                ),
              ] else ...[
                _buildCleanMenuCard(
                  icon: Icons.menu_book_outlined,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFEF3C7),
                  title: 'Panduan Etik & SOP HIMPSI',
                  subtitle: 'Kode etik layanan telekonseling & penanganan krisis',
                  trailingBadge: const SizedBox.shrink(),
                  onTap: _showEthicalGuidelinesModal,
                ),
              ],

              _buildCleanMenuCard(
                icon: Icons.explore_rounded,
                iconColor: const Color(0xFF6366F1),
                iconBg: const Color(0xFFEEF2FF),
                title: 'Tur Panduan Aplikasi Konselor',
                subtitle: 'Pelajari alur tiap menu, rekam medis, koin & backup Drive',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Buka Tur 🧭', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 10)),
                ),
                onTap: () => ref.read(triggerCounselorSpotlightTourProvider.notifier).state++,
              ),
              const SizedBox(height: 24),

              // 7. LOGOUT
              GestureDetector(
                onTap: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/counselor-login');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.highRiskBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout, color: AppColors.error, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Keluar dari Akun Konselor',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanMenuCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required Widget trailingBadge,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECEFF8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailingBadge,
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
