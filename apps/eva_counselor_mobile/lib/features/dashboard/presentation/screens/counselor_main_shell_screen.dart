import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../finances/presentation/screens/transaction_history_screen.dart';
import '../../../patients/presentation/screens/patient_list_screen.dart';
import '../../../profile/presentation/screens/counselor_profile_screen.dart';
import '../widgets/counselor_spotlight_tour.dart';
import 'counselor_home_screen.dart';

final counselorBottomNavIndexProvider = StateProvider<int>((ref) => 0);
final triggerCounselorSpotlightTourProvider = StateProvider<int>((ref) => 0);

class CounselorMainShellScreen extends ConsumerStatefulWidget {
  const CounselorMainShellScreen({super.key});

  @override
  ConsumerState<CounselorMainShellScreen> createState() => _CounselorMainShellScreenState();
}

class _CounselorMainShellScreenState extends ConsumerState<CounselorMainShellScreen> {
  final List<Widget> _pages = const [
    CounselorHomeScreen(),
    PatientListScreen(),
    TransactionHistoryScreen(),
    CounselorProfileScreen(),
  ];

  final GlobalKey _navBarKey = GlobalKey();
  bool _showSpotlight = false;
  int _spotlightStep = 0;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeTour();
  }

  Future<void> _checkFirstTimeTour() async {
    final seen = await CounselorSpotlightTourOverlay.hasSeenTour();
    if (!seen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showSpotlight = true;
          });
        }
      });
    }
  }

  Rect _getNavRect(int index) {
    final navBox = _navBarKey.currentContext?.findRenderObject() as RenderBox?;
    final shellBox = context.findRenderObject() as RenderBox?;
    if (navBox != null && navBox.hasSize && shellBox != null && shellBox.hasSize) {
      final navPos = shellBox.globalToLocal(navBox.localToGlobal(Offset.zero));
      final navWidth = navBox.size.width;
      final navHeight = navBox.size.height;
      final itemWidth = navWidth / 4;
      final itemLeft = navPos.dx + index * itemWidth;
      return Rect.fromLTWH(itemLeft + 4, navPos.dy + 6, itemWidth - 8, navHeight - 12);
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    final localSize = (renderBox != null && renderBox.hasSize) ? renderBox.size : MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navWidth = localSize.width - 40;
    const navHeight = 68.0;
    final navTop = localSize.height - 20 - bottomPadding - navHeight;
    final itemWidth = navWidth / 4;
    final itemLeft = 20 + index * itemWidth;
    return Rect.fromLTWH(itemLeft + 4, navTop + 6, itemWidth - 8, navHeight - 12);
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
            key: _navBarKey,
            margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFECEFF8), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.glassShadow,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
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
        if (_showSpotlight)
          CounselorSpotlightTourOverlay(
            currentStep: _spotlightStep,
            targetRect: _getNavRect(_spotlightStep),
            onNext: _nextSpotlightStep,
            onSkip: _finishSpotlight,
          ),
      ],
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
