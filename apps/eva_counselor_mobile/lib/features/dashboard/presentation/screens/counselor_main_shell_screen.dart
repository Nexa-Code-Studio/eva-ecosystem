import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finances/presentation/screens/transaction_history_screen.dart';
import '../../../patients/presentation/screens/patient_list_screen.dart';
import '../providers/counselor_nav_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(counselorBottomNavIndexProvider);

    return Scaffold(
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
    );
  }

  Widget _buildNavItem(int index, int currentIndex, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = currentIndex == index;
    return GestureDetector(
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
  int _consultationRate = 200000;
  bool _requireManualApproval = true; // Booking confirmation mode

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

  // 3. EDIT RATE MODAL (BISA MANUAL INPUT & PILIH REKOMENDASI)
  void _showEditRateModal() {
    int selectedRate = _consultationRate;
    final rateCtrl = TextEditingController(text: selectedRate.toString());

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
                  const Text('Ubah Tarif Konsultasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tentukan tarif per sesi ($_sessionDuration menit). Anda dapat mengetik manual atau memilih rekomendasi:',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // INPUT MANUAL TARIF DENGAN KEYBOARD ANGKA
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.4),
                ),
                child: Row(
                  children: [
                    const Text('Rp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: rateCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: '0',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                          if (parsed != null && parsed >= 0) {
                            setModalState(() => selectedRate = parsed);
                          }
                        },
                      ),
                    ),
                    Text('/ $_sessionDuration Mnt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              const Text('Rekomendasi Tarif Populer:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),

              // Rate Option Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [150000, 200000, 250000, 300000, 350000].map((rate) {
                  final isSelected = selectedRate == rate;
                  return GestureDetector(
                    onTap: () {
                      setModalState(() {
                        selectedRate = rate;
                        rateCtrl.text = rate.toString();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFF7F8FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFECEFF8),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        'Rp ${_formatNumber(rate)}${rate == 200000 ? " (HIMPSI)" : ""}',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 11,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Breakdown Honorarium
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Honorarium Bersih Psikolog (85%):', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('Rp ${_formatNumber((selectedRate * 0.85).toInt())}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.verifiedGreen)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Operasional Luna & Enkripsi Medis (15%):', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('Rp ${_formatNumber((selectedRate * 0.15).toInt())}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
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
                  setState(() => _consultationRate = selectedRate);
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Tarif Konsultasi Disimpan',
                    message: 'Tarif berhasil diatur ke Rp ${_formatNumber(_consultationRate)} / $_sessionDuration menit.',
                    type: ToastType.success,
                  );
                },
                child: const Text('Simpan Tarif Baru', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.verifiedBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'STR: ${user?.strNumber ?? "4192-PSI-2024"}',
                                      style: const TextStyle(
                                        color: AppColors.verifiedGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
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
              const SizedBox(height: 16),

              // CARD REVIW & KEPUASAN PASIEN
              InkWell(
                onTap: _showPatientReviewsModal,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFECEFF8)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.star_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Kepuasan Pasien • 4.9 / 5.0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: 2),
                            Text('Lihat rincian 140 ulasan & testimoni konseling Anda', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 22),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. SISTEM PENERIMAAN BOOKING PASIEN (MANUAL CONFIRM VS AUTO)
              const Text('Sistem Penerimaan Booking Pasien', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text(
                'Tentukan bagaimana reservasi jadwal konsultasi baru dari pasien diproses oleh sistem.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                    // Opsi 1: Menunggu Persetujuan Psikolog
                    InkWell(
                      onTap: () => setState(() => _requireManualApproval = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _requireManualApproval ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: _requireManualApproval ? AppColors.primary : AppColors.textLight,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Menunggu Persetujuan Psikolog (Disarankan)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                SizedBox(height: 2),
                                Text(
                                  'Setiap pasien booking, Anda mendapat notifikasi & berhak menyetujui atau mengajukan opsi jadwal lain.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 20, color: Color(0xFFF0F2F8)),

                    // Opsi 2: Otomatis Diterima (Instan)
                    InkWell(
                      onTap: () => setState(() => _requireManualApproval = false),
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            !_requireManualApproval ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: !_requireManualApproval ? AppColors.primary : AppColors.textLight,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Otomatis Diterima (Instan Booking)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                SizedBox(height: 2),
                                Text(
                                  'Slot konsultasi langsung terkunci otomatis jika pembayaran pasien telah terkonfirmasi.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. JADWAL PRAKTIK & OPERASIONAL
              const Text('Hari & Jam Praktik Online', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),

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

              // 4. HONORARIUM & TARIF (CLEAN MODERN CARDS)
              const Text('Honorarium & Keuangan Praktik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),

              _buildCleanMenuCard(
                icon: Icons.payments_outlined,
                iconColor: AppColors.verifiedGreen,
                iconBg: AppColors.verifiedBg,
                title: 'Tarif Konsultasi',
                subtitle: 'Rp ${_formatNumber(_consultationRate)} per $_sessionDuration menit',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rp ${_formatNumber(_consultationRate)}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 12, color: AppColors.primary),
                    ],
                  ),
                ),
                onTap: _showEditRateModal,
              ),

              _buildCleanMenuCard(
                icon: Icons.account_balance_outlined,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                title: 'Rekening Bank Pencairan',
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

              const SizedBox(height: 10),

              // 5. LEGALITAS & KEAMANAN KLINIS (CLEAN MODERN CARDS)
              const Text('Legalitas & Keamanan Praktik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),

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

              _buildCleanMenuCard(
                icon: Icons.menu_book_outlined,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFEF3C7),
                title: 'Panduan Etik & SOP HIMPSI',
                subtitle: 'Kode etik layanan telekonseling & penanganan krisis',
                trailingBadge: const SizedBox.shrink(),
                onTap: _showEthicalGuidelinesModal,
              ),
              const SizedBox(height: 24),

              // 6. LOGOUT
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
