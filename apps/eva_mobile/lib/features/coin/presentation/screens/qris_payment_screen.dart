import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_back_button.dart';
import 'package:eva_mobile/widgets/app_snack_bar.dart';
import 'package:eva_mobile/widgets/custom_button.dart';
import 'package:eva_mobile/widgets/glass_card.dart';
import '../../domain/entities/coin_topup_order_entity.dart';
import '../providers/coin_provider.dart';

class QrisPaymentScreen extends ConsumerStatefulWidget {
  const QrisPaymentScreen({super.key});

  @override
  ConsumerState<QrisPaymentScreen> createState() => _QrisPaymentScreenState();
}

class _QrisPaymentScreenState extends ConsumerState<QrisPaymentScreen>
    with WidgetsBindingObserver {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  bool _notifiedPaid = false;
  TopupFlowNotifier? _topupNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _topupNotifier = ref.read(topupFlowProvider.notifier);
    _syncRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncRemaining();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final order = ref.read(topupFlowProvider).activeOrder;
      if (order != null && order.status.isActivePending) {
        _topupNotifier?.startPolling();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _topupNotifier?.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final order = ref.read(topupFlowProvider).activeOrder;
      if (order != null && order.status.isActivePending) {
        unawaited(ref.read(topupFlowProvider.notifier).checkStatus(forceProviderRefresh: true));
      }
    }
  }

  void _syncRemaining() {
    if (!mounted) return;
    final order = ref.read(topupFlowProvider).activeOrder;
    final expiresAt = order?.expiresAt;
    if (expiresAt == null) {
      if (_remaining != Duration.zero) {
        setState(() => _remaining = Duration.zero);
      }
      return;
    }
    final diff = expiresAt.toUtc().difference(DateTime.now().toUtc());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$mins:$secs';
    }
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(topupFlowProvider);
    final coinBalance = ref.watch(coinBalanceProvider);
    final sandboxEnabled = ref.watch(sandboxSimulationProvider);
    final order = flow.activeOrder;
    final showFloatingSim = sandboxEnabled && order != null && order.status.isActivePending;

    ref.listen<TopupFlowState>(topupFlowProvider, (prev, next) {
      final nextOrder = next.activeOrder;
      if (!_notifiedPaid &&
          nextOrder != null &&
          nextOrder.status == CoinTopupStatus.paid &&
          prev?.activeOrder?.status != CoinTopupStatus.paid) {
        _notifiedPaid = true;
        AppSnackBar.showSuccess(
          context,
          'Pembayaran berhasil! +${nextOrder.totalCoins} Koin telah ditambahkan.',
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: showFloatingSim ? _buildSandboxFloatingCard(flow) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                          'Pembayaran QRIS',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (order != null)
                          Text(
                            order.orderId,
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
            Expanded(
              child: order == null
                  ? _buildEmptyState(context)
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, showFloatingSim ? 116 : 24),
                      child: _buildOrderBody(context, flow, order, coinBalance),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSandboxFloatingCard(TopupFlowState flow) {
    return Container(
      width: 228,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.glassShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.science_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Simulator Sandbox',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CustomButton(
            text: 'Simulasikan Bayar',
            height: 44,
            borderRadius: 12,
            isLoading: flow.isRefreshing,
            onPressed: flow.isRefreshing
                ? null
                : () => ref.read(topupFlowProvider.notifier).simulateSandboxPayment(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2_rounded, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Tidak ada pesanan QRIS aktif.',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Kembali ke Paket Koin',
              height: 46,
              width: 220,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderBody(
    BuildContext context,
    TopupFlowState flow,
    CoinTopupOrderEntity order,
    int coinBalance,
  ) {
    if (order.status == CoinTopupStatus.paid) {
      return _buildSuccessCard(context, order, coinBalance);
    }
    if (order.status == CoinTopupStatus.expired ||
        order.status == CoinTopupStatus.failed ||
        order.status == CoinTopupStatus.cancelled) {
      return _buildFailureOrExpiredCard(context, order);
    }
    if (order.status.isRefundOrReview) {
      return _buildRefundOrReviewCard(context, order);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.package.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      order.expiresAt != null
                          ? 'Berakhir dalam ${_formatDuration(_remaining)}'
                          : 'Menunggu Pembayaran',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warningDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.formattedAmountIdr,
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'Untuk ${order.totalCoins} Koin EVA',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final qrSize = (MediaQuery.sizeOf(context).width - 80).clamp(240.0, 320.0);
                  return Container(
                    width: qrSize,
                    height: qrSize,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: _buildQrContent(flow, order),
                  );
                },
              ),
              const SizedBox(height: 14),
              if (flow.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    flow.errorMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              CustomButton(
                text: 'Cek Status Pembayaran',
                height: 46,
                width: 230,
                isOutline: true,
                isLoading: flow.isRefreshing,
                onPressed: flow.isRefreshing
                    ? null
                    : () => ref
                        .read(topupFlowProvider.notifier)
                        .checkStatus(forceProviderRefresh: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard.surface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cara Bayar QRIS',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Buka GoPay, OVO, DANA, ShopeePay, atau aplikasi m-banking kamu.\n'
                '2. Pilih menu Scan QR / QRIS.\n'
                '3. Jika aplikasi bank ada di ponsel ini, ambil screenshot QR lalu unggah dari galeri pada menu Scan QR, atau scan langsung menggunakan perangkat kedua.\n'
                '4. Saldo koin otomatis bertambah begitu pembayaran terkonfirmasi.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrContent(TopupFlowState flow, CoinTopupOrderEntity order) {
    if (order.status == CoinTopupStatus.creating || flow.isLoadingQr) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (flow.qrBytes != null && flow.qrBytes!.isNotEmpty) {
      return Image.memory(flow.qrBytes!, fit: BoxFit.contain);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 36, color: AppColors.textSecondary),
        const SizedBox(height: 8),
        Text(
          'QR belum termuat',
          style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        TextButton(
          onPressed: () => ref.read(topupFlowProvider.notifier).loadQrImage(order.id),
          child: const Text('Muat Ulang QR'),
        ),
      ],
    );
  }

  Widget _buildSuccessCard(BuildContext context, CoinTopupOrderEntity order, int coinBalance) {
    return GlassCard.surface(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.successDark),
          const SizedBox(height: 14),
          Text(
            'Pembelian Berhasil!',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+${order.totalCoins} Koin telah ditambahkan ke saldo EVA kamu.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            'Saldo Saat Ini: $coinBalance Koin',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          CustomButton(
            text: 'Selesai',
            height: 46,
            width: 180,
            onPressed: () {
              ref.read(topupFlowProvider.notifier).resetForNewOrder();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFailureOrExpiredCard(BuildContext context, CoinTopupOrderEntity order) {
    final isExpired = order.status == CoinTopupStatus.expired;
    return GlassCard.surface(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            isExpired ? Icons.timer_off_rounded : Icons.error_outline_rounded,
            size: 56,
            color: AppColors.error,
          ),
          const SizedBox(height: 14),
          Text(
            isExpired ? 'QRIS Kedaluwarsa' : 'Pembayaran Gagal / Dibatalkan',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isExpired
                ? 'Batas waktu pembayaran QRIS telah habis. Silakan buat pesanan baru.'
                : 'Transaksi tidak dapat diselesaikan (${order.status.apiValue}).',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          CustomButton(
            text: 'Pilih Paket Lagi',
            height: 46,
            width: 200,
            onPressed: () {
              ref.read(topupFlowProvider.notifier).resetForNewOrder();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRefundOrReviewCard(BuildContext context, CoinTopupOrderEntity order) {
    return GlassCard.surface(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.info_outline_rounded, size: 56, color: AppColors.warningDark),
          const SizedBox(height: 14),
          Text(
            'Status Pesanan: ${order.status.apiValue}',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesanan ${order.orderId} sedang dalam proses refund atau peninjauan rekonsiliasi.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          CustomButton(
            text: 'Kembali',
            height: 46,
            width: 180,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
