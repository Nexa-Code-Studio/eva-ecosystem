import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_back_button.dart';
import 'package:eva_mobile/widgets/app_snack_bar.dart';
import 'package:eva_mobile/widgets/custom_button.dart';
import 'package:eva_mobile/widgets/glass_card.dart';
import 'package:eva_mobile/widgets/skeleton_shimmer.dart';
import '../../domain/entities/coin_package_entity.dart';
import '../providers/coin_provider.dart';
import 'coin_topup_history_screen.dart';
import 'qris_payment_screen.dart';

/// Screen for browsing, selecting, and purchasing Eva AI coins via server-authoritative QRIS.
class CoinPurchaseScreen extends ConsumerStatefulWidget {
  const CoinPurchaseScreen({super.key});

  @override
  ConsumerState<CoinPurchaseScreen> createState() => _CoinPurchaseScreenState();
}

class _CoinPurchaseScreenState extends ConsumerState<CoinPurchaseScreen> {
  String? _selectedPackageId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(coinBalanceProvider.notifier).syncFromServer());
      unawaited(ref.read(topupFlowProvider.notifier).restorePendingOrder());
    });
  }

  Future<void> _handlePurchase(CoinPackageEntity package) async {
    final enabled = ref.read(qrisTopupEnabledProvider);
    if (!enabled) {
      AppSnackBar.showError(
        context,
        'Pembelian koin QRIS belum diaktifkan pada build rilis ini.',
      );
      return;
    }

    final order = await ref.read(topupFlowProvider.notifier).startTopup(package.id);
    if (!mounted) return;

    if (order == null) {
      final err = ref.read(topupFlowProvider).errorMessage ?? 'Gagal membuat tagihan QRIS.';
      AppSnackBar.showError(context, err);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrisPaymentScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coinBalance = ref.watch(coinBalanceProvider);
    final packagesAsync = ref.watch(coinPackagesProvider);
    final qrisEnabled = ref.watch(qrisTopupEnabledProvider);
    final flowState = ref.watch(topupFlowProvider);

    final packages = packagesAsync.valueOrNull ?? const <CoinPackageEntity>[];
    CoinPackageEntity? selectedPackage;
    if (packages.isNotEmpty) {
      selectedPackage = packages.firstWhere(
        (p) => p.id == _selectedPackageId,
        orElse: () => packages.firstWhere((p) => p.isPopular, orElse: () => packages.first),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Beli Koin EVA',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Top up koin via QRIS untuk berbicara dengan EVA & konsultasi psikolog',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Riwayat Pembelian',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CoinTopupHistoryScreen()),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(coinBalanceProvider.notifier).syncFromServer();
                  ref.invalidate(coinPackagesProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceHeroCard(coinBalance),
                      if (flowState.activeOrder != null &&
                          flowState.activeOrder!.status.isActivePending) ...[
                        const SizedBox(height: 16),
                        _buildPendingResumeBanner(context, flowState),
                      ],
                      if (!qrisEnabled) ...[
                        const SizedBox(height: 16),
                        _buildReleaseGateBanner(),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'PILIH PAKET KOIN',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textLight,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      packagesAsync.when(
                        loading: () => _buildLoadingPackages(),
                        error: (err, _) => _buildPackagesError(ref),
                        data: (items) => items.isEmpty
                            ? _buildEmptyPackages()
                            : _buildPackagesGrid(items, selectedPackage?.id),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'METODE PEMBAYARAN',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textLight,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQrisMethodCard(),
                      const SizedBox(height: 24),
                      _buildBenefitsCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            if (selectedPackage != null)
              _buildStickyBottomBar(
                selectedPackage,
                isCreating: flowState.isCreating,
                qrisEnabled: qrisEnabled,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceHeroCard(int coinBalance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5358CB), Color(0xFF8B93FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5358CB).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
            ),
            child: const Center(
              child: Icon(Icons.monetization_on_rounded, size: 30, color: Color(0xFFFFD54F)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo Koin Kamu',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$coinBalance Koin',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Aktif',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingResumeBanner(BuildContext context, TopupFlowState flowState) {
    final order = flowState.activeOrder!;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QrisPaymentScreen()),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFC2410C), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pembayaran QRIS Tertunda',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${order.package.name} (${order.formattedAmountIdr}) • Ketuk untuk lanjutkan',
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseGateBanner() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pembelian koin via QRIS sedang dinonaktifkan pada build distribusi ini sampai kebijakan rilis disetujui.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPackages() {
    return SkeletonShimmerHost(
      child: Column(
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonBox(height: 86, borderRadius: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildPackagesError(WidgetRef ref) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Gagal memuat daftar paket koin dari server.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.invalidate(coinPackagesProvider),
            child: const Text('Muat Ulang'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPackages() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Belum ada paket koin aktif saat ini.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildPackagesGrid(List<CoinPackageEntity> packages, String? selectedId) {
    return Column(
      children: packages.map((pkg) {
        final isSelected = pkg.id == selectedId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => _selectedPackageId = pkg.id),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF3F4FE) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: isSelected ? 12 : 6,
                    offset: Offset(0, isSelected ? 4 : 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : const Color(0xFFF8F9FE),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.toll_rounded,
                        size: 24,
                        color: isSelected ? AppColors.primary : const Color(0xFFFFB300),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 3,
                          children: [
                            Text(
                              pkg.title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (pkg.badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: pkg.isPopular
                                      ? const Color(0xFFFFF7ED)
                                      : AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: pkg.isPopular
                                        ? const Color(0xFFFDBA74)
                                        : const Color(0xFFC7D2FE),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  pkg.badge!,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: pkg.isPopular
                                        ? const Color(0xFFC2410C)
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Text(
                              '${pkg.totalCoins} Koin',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                            if (pkg.bonusCoins > 0)
                              Text(
                                '(+${pkg.bonusCoins} Bonus)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                          ],
                        ),
                        if (pkg.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            pkg.description,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pkg.formattedPrice,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 20,
                        color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQrisMethodCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.qr_code_2_rounded, size: 22, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QRIS Midtrans (Instan)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'GoPay, OVO, DANA, ShopeePay & semua M-Banking QRIS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.radio_button_checked_rounded, size: 18, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Manfaat Koin EVA',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBenefitItem(
            icon: Icons.record_voice_over_rounded,
            title: 'Bisa Berbicara Langsung dengan EVA',
            desc:
                'Dapat digunakan untuk sesi panggilan suara (Voice Call) dan interaksi curhat real-time dua arah bersama AI EVA.',
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(
            icon: Icons.psychology_rounded,
            title: 'Alat Transaksi Konsultasi Psikolog',
            desc:
                'Dapat digunakan sebagai alat transaksi untuk menjadwalkan dan berkonsultasi langsung dengan psikolog pada halaman Layanan.',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomBar(
    CoinPackageEntity selectedPackage, {
    required bool isCreating,
    required bool qrisEnabled,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Pembayaran',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selectedPackage.formattedPrice,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: CustomButton(
              text: qrisEnabled ? 'Bayar via QRIS' : 'Segera Hadir',
              isLoading: isCreating,
              onPressed: (isCreating || !qrisEnabled)
                  ? null
                  : () => _handlePurchase(selectedPackage),
            ),
          ),
        ],
      ),
    );
  }
}
