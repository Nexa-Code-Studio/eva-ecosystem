import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_back_button.dart';
import 'package:eva_mobile/widgets/app_snack_bar.dart';
import 'package:eva_mobile/widgets/custom_button.dart';
import 'package:eva_mobile/widgets/glass_card.dart';
import '../../domain/entities/coin_package_entity.dart';
import '../providers/coin_provider.dart';

/// Screen for browsing, selecting, and purchasing Eva AI coins.
class CoinPurchaseScreen extends ConsumerStatefulWidget {
  const CoinPurchaseScreen({super.key});

  @override
  ConsumerState<CoinPurchaseScreen> createState() => _CoinPurchaseScreenState();
}

class _CoinPurchaseScreenState extends ConsumerState<CoinPurchaseScreen> {
  String _selectedPackageId = 'pkg_popular';
  String _selectedPaymentMethod = 'qris';
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'qris',
      'name': 'QRIS (Instant)',
      'desc': 'GoPay, OVO, DANA, ShopeePay & M-Banking',
      'icon': Icons.qr_code_2_rounded,
    },
    {
      'id': 'va',
      'name': 'Virtual Account Bank',
      'desc': 'BCA, Mandiri, BRI, BNI & Permata',
      'icon': Icons.account_balance_rounded,
    },
    {
      'id': 'gplay',
      'name': 'Google Play Billing',
      'desc': 'Saldo Google Play & Tagihan Operator',
      'icon': Icons.shop_two_rounded,
    },
  ];

  Future<void> _handlePurchase(CoinPackageEntity package) async {
    setState(() => _isProcessing = true);

    // Simulate instant secure payment processing
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    await ref.read(coinBalanceProvider.notifier).addCoins(package.totalCoins);

    setState(() => _isProcessing = false);

    if (!mounted) return;

    _showSuccessDialog(package);
  }

  void _showSuccessDialog(CoinPackageEntity package) {
    final currentBalance = ref.read(coinBalanceProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF3F4FE),
                  border: Border.all(
                    color: AppColors.primaryContainer,
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 46,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Pembelian Berhasil!',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selamat! ${package.totalCoins} Koin telah ditambahkan ke akunmu.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saldo Koin Sekarang:',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          size: 18,
                          color: Color(0xFFFFD54F),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$currentBalance Koin',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              CustomButton(
                text: 'Gunakan Koin Sekarang',
                onPressed: () {
                  Navigator.pop(ctx);
                  AppSnackBar.showSuccess(
                    context,
                    'Koin siap digunakan untuk berbicara dengan EVA & konsultasi psikolog!',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final coinBalance = ref.watch(coinBalanceProvider);
    final packages = ref.watch(coinPackagesProvider);
    final selectedPackage = packages.firstWhere(
      (pkg) => pkg.id == _selectedPackageId,
      orElse: () => packages.first,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Navigation Bar
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
                          'Top up koin untuk berbicara dengan EVA & konsultasi psikolog',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Hero Card (Theme Purple Gradient)
                    _buildBalanceHeroCard(coinBalance),

                    const SizedBox(height: 24),

                    // Section: Pilih Paket Koin
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

                    // Packages Grid
                    _buildPackagesGrid(packages),

                    const SizedBox(height: 24),

                    // Section: Metode Pembayaran
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

                    _buildPaymentMethodsList(),

                    const SizedBox(height: 24),

                    // Section: Manfaat Koin
                    _buildBenefitsCard(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // 3. Sticky Bottom Checkout Bar
            _buildStickyBottomBar(selectedPackage),
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
          colors: [
            Color(0xFF5358CB), // AppColors.primary
            Color(0xFF8B93FF), // AppColors.primaryLight
          ],
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.monetization_on_rounded,
                size: 30,
                color: Color(0xFFFFD54F),
              ),
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 14,
                  color: Colors.white,
                ),
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

  Widget _buildPackagesGrid(List<CoinPackageEntity> packages) {
    return Column(
      children: packages.map((pkg) {
        final isSelected = pkg.id == _selectedPackageId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              setState(() => _selectedPackageId = pkg.id);
            },
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
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
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

  Widget _buildPaymentMethodsList() {
    return Column(
      children: _paymentMethods.map((method) {
        final isSelected = method['id'] == _selectedPaymentMethod;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              setState(() => _selectedPaymentMethod = method['id'] as String);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryContainer
                          : const Color(0xFFF8F9FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        method['icon'] as IconData,
                        size: 20,
                        color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method['name'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          method['desc'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 18,
                    color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
              const Icon(
                Icons.stars_rounded,
                size: 20,
                color: AppColors.primary,
              ),
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
          decoration: BoxDecoration(
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

  Widget _buildStickyBottomBar(CoinPackageEntity selectedPackage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
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
              text: 'Beli Sekarang',
              isLoading: _isProcessing,
              onPressed: _isProcessing ? null : () => _handlePurchase(selectedPackage),
            ),
          ),
        ],
      ),
    );
  }
}
