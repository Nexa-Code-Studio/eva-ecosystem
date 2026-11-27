import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_back_button.dart';
import 'package:eva_mobile/widgets/glass_card.dart';
import '../../domain/entities/coin_topup_order_entity.dart';
import '../providers/coin_provider.dart';
import 'qris_payment_screen.dart';

class CoinTopupHistoryScreen extends ConsumerWidget {
  const CoinTopupHistoryScreen({super.key});

  String _statusLabel(CoinTopupStatus status) {
    switch (status) {
      case CoinTopupStatus.creating:
        return 'Membuat QR';
      case CoinTopupStatus.pending:
        return 'Menunggu Bayar';
      case CoinTopupStatus.paid:
        return 'Berhasil';
      case CoinTopupStatus.expired:
        return 'Kedaluwarsa';
      case CoinTopupStatus.failed:
        return 'Gagal';
      case CoinTopupStatus.cancelled:
        return 'Dibatalkan';
      case CoinTopupStatus.refundPending:
        return 'Proses Refund';
      case CoinTopupStatus.partiallyRefunded:
        return 'Refund Sebagian';
      case CoinTopupStatus.refunded:
        return 'Direfund';
      case CoinTopupStatus.reviewRequired:
        return 'Perlu Tinjauan';
    }
  }

  Color _statusTextColor(CoinTopupStatus status) {
    if (status == CoinTopupStatus.paid) return AppColors.successDark;
    if (status.isActivePending) return AppColors.warningDark;
    return AppColors.errorDark;
  }

  Color _statusBgColor(CoinTopupStatus status) {
    if (status == CoinTopupStatus.paid) return AppColors.successContainer;
    if (status.isActivePending) return AppColors.warningContainer;
    return AppColors.errorContainer;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(topupHistoryProvider);

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
                    child: Text(
                      'Riwayat Pembelian Koin',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Gagal memuat riwayat pembelian.',
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref.invalidate(topupHistoryProvider),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (orders) {
                  if (orders.isEmpty) {
                    return Center(
                      child: Text(
                        'Belum ada riwayat pembelian koin.',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => ref.refresh(topupHistoryProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final order = orders[i];
                        final badgeTextColor = _statusTextColor(order.status);
                        final badgeBgColor = _statusBgColor(order.status);
                        return GlassCard.surface(
                          borderRadius: 18,
                          padding: const EdgeInsets.all(14),
                          onTap: () async {
                            await ref.read(topupFlowProvider.notifier).openOrder(order);
                            if (!ctx.mounted) return;
                            Navigator.push(
                              ctx,
                              MaterialPageRoute(builder: (_) => const QrisPaymentScreen()),
                            );
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.package.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${order.orderId} • ${order.totalCoins} Koin',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    order.formattedAmountIdr,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: badgeBgColor,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusLabel(order.status),
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: badgeTextColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
