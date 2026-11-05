import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finances/presentation/screens/transaction_history_screen.dart';
import '../../../patients/presentation/screens/patient_list_screen.dart';
import 'counselor_home_screen.dart';

class CounselorMainShellScreen extends ConsumerStatefulWidget {
  const CounselorMainShellScreen({super.key});

  @override
  ConsumerState<CounselorMainShellScreen> createState() =>
      _CounselorMainShellScreenState();
}

class _CounselorMainShellScreenState
    extends ConsumerState<CounselorMainShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    CounselorHomeScreen(),
    PatientListScreen(),
    TransactionHistoryScreen(),
    _CounselorProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Beranda'),
                  _buildNavItem(1, Icons.people_alt_rounded, Icons.people_alt_outlined, 'Pasien'),
                  _buildNavItem(2, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Keuangan'),
                  _buildNavItem(3, Icons.person_rounded, Icons.person_outline, 'Profil'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
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

class _CounselorProfileTab extends ConsumerWidget {
  const _CounselorProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profil Profesional', style: AppTypography.headingMedium),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryContainer,
                backgroundImage: user?.profilePhotoUrl != null
                    ? NetworkImage(user!.profilePhotoUrl!)
                    : null,
                child: user?.profilePhotoUrl == null
                    ? const Icon(Icons.person, size: 40, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(height: 14),
              Text(user?.displayName ?? 'Sarah Anindya, M.Psi.', style: AppTypography.headingSmall),
              const SizedBox(height: 4),
              Text(user?.email ?? 'sarah.anindya@psikolog.eva.id', style: AppTypography.bodyMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.verifiedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No. STR: ${user?.strNumber ?? "STR-PK-198827364-2024"}',
                  style: const TextStyle(
                    color: AppColors.verifiedGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: const Icon(Icons.verified_outlined, color: AppColors.primary),
                title: const Text('Asosiasi Profesi'),
                subtitle: Text(user?.association ?? 'HIMPSI'),
              ),
              const SizedBox(height: 10),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: const Icon(Icons.payments_outlined, color: AppColors.primary),
                title: const Text('Tarif per Sesi'),
                subtitle: Text('Rp ${user?.consultationRatePerHour ?? 200000} / 50 Menit'),
              ),
              const SizedBox(height: 10),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: const Icon(Icons.lock_reset, color: AppColors.primary),
                title: const Text('Mode Eksekusi Saat Ini'),
                subtitle: const Text('Mock Data (Bisa di-switch ke Backend Live)'),
              ),
              const SizedBox(height: 28),
              ListTile(
                tileColor: AppColors.highRiskBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Keluar dari Akun Mitra', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/counselor-login');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
