import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/finance_provider.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  String _selectedFilter = 'Semua';

  void _showPayoutModal(BuildContext context, int availableBalance) {
    final amountCtrl = TextEditingController(text: availableBalance.toString());
    final bankCtrl = TextEditingController(text: 'BCA');
    final accountCtrl = TextEditingController(text: '8192039182');
    final nameCtrl = TextEditingController(text: 'Sarah Anindya');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
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
                    Text('Tarik Honorarium Konsultasi', style: AppTypography.headingSmall),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Saldo tersedia untuk ditarik: Rp ${availableBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Nominal Penarikan (Rp)',
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Nama Bank Tujuan',
                  controller: bankCtrl,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Nomor Rekening',
                  controller: accountCtrl,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Nama Pemilik Rekening (Sesuai KTP)',
                  controller: nameCtrl,
                ),
                const SizedBox(height: 24),
                CustomButton(
                  label: 'Konfirmasi Penarikan Dana',
                  isLoading: isSubmitting,
                  onPressed: () async {
                    setModalState(() => isSubmitting = true);
                    final repo = ref.read(financeRepositoryProvider);
                    await repo.requestPayout(
                      amount: int.tryParse(amountCtrl.text) ?? 0,
                      bankName: bankCtrl.text,
                      accountNumber: accountCtrl.text,
                      accountHolderName: nameCtrl.text,
                    );
                    ref.invalidate(financialSummaryProvider);
                    ref.invalidate(transactionsListProvider);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permintaan pencairan dana berhasil diajukan.'),
                        backgroundColor: AppColors.verifiedGreen,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatRp(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(financialSummaryProvider);
    final txListAsync = ref.watch(transactionsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Keuangan & Transaksi', style: AppTypography.headingMedium),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Overview Card
              summaryAsync.when(
                data: (summary) {
                  return GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Saldo Tersedia (Siap Tarik)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge.verified('Dompet Mitra'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rp ${_formatRp(summary.availableBalance)}',
                          style: AppTypography.headingLarge.copyWith(
                            color: AppColors.primary,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Menunggu Kliring',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rp ${_formatRp(summary.pendingClearingBalance)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.headingSmall.copyWith(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pendapatan Bulan Ini',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rp ${_formatRp(summary.totalEarningsThisMonth)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.headingSmall.copyWith(
                                      fontSize: 14,
                                      color: AppColors.verifiedGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        CustomButton(
                          label: 'Tarik Dana ke Rekening',
                          icon: Icons.payments_rounded,
                          onPressed: () => _showPayoutModal(context, summary.availableBalance),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Filter Chips
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Riwayat Honorarium', style: AppTypography.headingSmall),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Semua', 'Selesai', 'Penarikan'].map((f) {
                        final isSelected = _selectedFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: isSelected,
                            label: Text(f),
                            selectedColor: AppColors.primaryContainer,
                            labelStyle: AppTypography.bodySmall.copyWith(
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 12,
                            ),
                            onSelected: (_) => setState(() => _selectedFilter = f),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Transaction List
              txListAsync.when(
                data: (transactions) {
                  final filtered = transactions.where((t) {
                    if (_selectedFilter == 'Selesai') {
                      return t.status == TransactionStatus.completed;
                    }
                    if (_selectedFilter == 'Penarikan') {
                      return t.status == TransactionStatus.payoutRequested;
                    }
                    return true;
                  }).toList();

                  return Column(
                    children: filtered.map((t) {
                      final isPayout = t.status == TransactionStatus.payoutRequested;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isPayout
                                      ? AppColors.pendingBg
                                      : AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isPayout
                                      ? Icons.account_balance_outlined
                                      : Icons.video_call_outlined,
                                  color: isPayout
                                      ? AppColors.pendingAmber
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.patientName, style: AppTypography.headingSmall.copyWith(fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${t.sessionType} • ${t.date.day}/${t.date.month}',
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isPayout ? '-' : '+'}Rp ${_formatRp(t.netEarnings)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isPayout
                                          ? AppColors.textPrimary
                                          : AppColors.verifiedGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  isPayout
                                      ? StatusBadge.pending('Diproses')
                                      : StatusBadge.verified('Sukses'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
