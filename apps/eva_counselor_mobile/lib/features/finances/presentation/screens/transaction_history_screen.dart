import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/bank_constants.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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

  void _showRedeemCoinModal(BuildContext context, int availableCoins) {
    final authUser = ref.read(authStateProvider).value;
    final coinAmountCtrl = TextEditingController(text: availableCoins >= 50 ? '$availableCoins' : '');
    String? selectedBank = (authUser?.bankName != null && authUser!.bankName.isNotEmpty)
        ? (kIndonesianBanks.contains(authUser.bankName) ? authUser.bankName : 'Lainnya')
        : null;
    final customBankCtrl = TextEditingController(
      text: selectedBank == 'Lainnya' ? (authUser?.bankName ?? '') : '',
    );
    final accountCtrl = TextEditingController(text: authUser?.bankAccountNumber ?? '');
    final nameCtrl = TextEditingController(text: authUser?.bankAccountHolder ?? authUser?.displayName ?? '');
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
          final requestedCoins = int.tryParse(coinAmountCtrl.text) ?? 0;
          final estimatedRp = requestedCoins * 1000;

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
                    const Row(
                      children: [
                        Icon(Icons.monetization_on_rounded, color: Color(0xFFC2410C), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Redeem Koin ke Rupiah',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Saldo Koin Siap Tukar: $availableCoins Koin (1 Koin = Rp 1.000)',
                  style: const TextStyle(
                    color: Color(0xFFC2410C),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),

                // Live Rupiah Conversion Preview
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimasi Rupiah Diterima:',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        'Rp ${_formatRp(estimatedRp)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC2410C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                _buildModalInput(
                  'Jumlah Koin yang Ditukar (Min. 50 Koin)',
                  coinAmountCtrl,
                  hintText: 'Contoh: 150',
                  isNumber: true,
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nama Bank Tujuan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedBank,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(Icons.account_balance_outlined,
                            color: AppColors.primary, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      hint: const Text('Pilih Nama Bank',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textLight)),
                      items: kIndonesianBanks
                          .map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(b,
                                  style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedBank = val;
                        });
                      },
                    ),
                    if (selectedBank == 'Lainnya') ...[
                      const SizedBox(height: 10),
                      _buildModalInput(
                          'Nama Bank Lainnya', customBankCtrl,
                          hintText: 'Ketik nama bank Anda'),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _buildModalInput('Nomor Rekening', accountCtrl, hintText: 'Masukkan nomor rekening', isNumber: true),
                const SizedBox(height: 10),
                _buildModalInput('Nama Pemilik Rekening (Sesuai KTP)', nameCtrl, hintText: 'Nama pemilik rekening bank'),
                const SizedBox(height: 20),

                CustomButton(
                  label: 'Konfirmasi Pencairan Rupiah',
                  isLoading: isSubmitting,
                  onPressed: () async {
                    if (requestedCoins < 50 || requestedCoins > availableCoins) {
                      TopToast.show(
                        context,
                        title: 'Jumlah Koin Tidak Valid',
                        message: 'Jumlah koin minimal 50 dan tidak melebihi saldo.',
                        type: ToastType.error,
                      );
                      return;
                    }

                    final finalBank = selectedBank == 'Lainnya'
                        ? customBankCtrl.text.trim()
                        : (selectedBank ?? '');
                    if (finalBank.isEmpty || accountCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                      TopToast.show(
                        context,
                        title: 'Data Belum Lengkap',
                        message: 'Mohon pilih bank tujuan, nomor rekening, dan nama pemilik.',
                        type: ToastType.error,
                      );
                      return;
                    }

                    setModalState(() => isSubmitting = true);
                    final repo = ref.read(financeRepositoryProvider);
                    await repo.requestPayout(
                      amount: estimatedRp,
                      bankName: finalBank,
                      accountNumber: accountCtrl.text,
                      accountHolderName: nameCtrl.text,
                    );

                    ref.read(authStateProvider.notifier).redeemCoins(requestedCoins);
                    ref.invalidate(financialSummaryProvider);
                    ref.invalidate(transactionsListProvider);

                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    if (!context.mounted) return;

                    TopToast.show(
                      context,
                      title: 'Redeem Koin Diajukan',
                      message:
                          'Penukaran $requestedCoins Koin (Rp ${_formatRp(estimatedRp)}) sedang diproses ke rekening $finalBank.',
                      type: ToastType.success,
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

  Widget _buildModalInput(
    String label,
    TextEditingController ctrl, {
    String? hintText,
    bool isNumber = false,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
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
    final authUser = ref.watch(authStateProvider).value;
    final txListAsync = ref.watch(transactionsListProvider);
    final transactions = txListAsync.value ?? [];

    // KASUS 3: PROFESIONAL MANDIRI (SISTEM KOIN & REDEEM RUPIAH)
    final coins = authUser?.coinBalance ?? 0;
    final isFreshAccount = transactions.isEmpty && coins == 0;
    final rateCoins = authUser?.coinsPerSession ?? 150;
    final sessionMins = authUser?.sessionDurationMinutes ?? 30;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Balance Overview Card (Sistem Koin Emas & Periwinkle)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3F46B8), Color(0xFF5B63E6)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4B53BB).withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Dompet Koin Konselor',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Rate: $rateCoins Koin / $sessionMins mnt',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD54F), size: 28),
                            const SizedBox(width: 6),
                            Text(
                              '$coins Koin',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '≈ Rp ${_formatRp(coins * 1000)}',
                            style: const TextStyle(
                              color: Color(0xFFC2410C),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Menunggu Selesai SOAP', style: TextStyle(color: Colors.white70, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text('${isFreshAccount ? 0 : 150} Koin', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          Container(width: 1, height: 24, color: Colors.white24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Koin Bulan Ini', style: TextStyle(color: Colors.white70, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text('${isFreshAccount ? 0 : coins} Koin', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(46),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.currency_exchange_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Redeem Koin ke Rupiah (Bank Transfer)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      onPressed: () => _showRedeemCoinModal(context, coins),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Filter Pills (Separated to Column to avoid horizontal overflow)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Riwayat Koin & Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Semua', 'Koin Masuk', 'Redeem'].map((f) {
                        final isSel = _selectedFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedFilter = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSel ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isSel ? AppColors.primary : const Color(0xFFECEFF8)),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                  color: isSel ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. Transactions List
              _buildTransactionsList(txListAsync),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList(AsyncValue<List<TransactionEntity>> txListAsync) {
    return txListAsync.when(
      data: (transactions) {
        final filtered = transactions.where((t) {
          if (_selectedFilter == 'Koin Masuk') {
            return t.status == TransactionStatus.completed;
          }
          if (_selectedFilter == 'Redeem') {
            return t.status == TransactionStatus.payoutRequested;
          }
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: const Text('Tidak ada riwayat transaksi.', style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        return Column(
          children: filtered.map((t) {
            final isPayout = t.status == TransactionStatus.payoutRequested;
            final coinsEarned = (t.netEarnings / 1000).round();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECEFF8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isPayout
                          ? const Color(0xFFFFF7ED)
                          : AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPayout ? Icons.currency_exchange_rounded : Icons.videocam_rounded,
                      color: isPayout ? const Color(0xFFC2410C) : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.patientName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.sessionType} • ${t.date.day}/${t.date.month}/${t.date.year}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isPayout ? '-$coinsEarned Koin' : '+$coinsEarned Koin',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: isPayout ? const Color(0xFFC2410C) : AppColors.verifiedGreen,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isPayout)
                          Text(
                            'Rp ${_formatRp(t.netEarnings)}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFFC2410C), fontWeight: FontWeight.w600),
                          ),
                        const SizedBox(height: 3),
                        isPayout
                            ? StatusBadge.pending('Ditransfer')
                            : StatusBadge.verified('SOAP Terisi'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
