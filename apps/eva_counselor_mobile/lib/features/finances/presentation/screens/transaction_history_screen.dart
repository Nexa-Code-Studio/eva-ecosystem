import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../profile/presentation/widgets/counselor_bank_account_modal.dart';
import '../../domain/entities/bank_account_entity.dart';
import '../../domain/entities/payout_entity.dart';
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

  String _formatRp(int amount) {
    final isNegative = amount < 0;
    final absStr = amount.abs().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return isNegative ? '-$absStr' : absStr;
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(financialSummaryProvider);
    ref.invalidate(transactionsListProvider);
    ref.invalidate(currentBankAccountProvider);
    ref.invalidate(payoutsHistoryProvider);
    await Future.wait([
      ref.read(financialSummaryProvider.future),
      ref.read(transactionsListProvider.future),
      ref.read(currentBankAccountProvider.future),
    ]);
  }

  void _showPayoutFlow(BuildContext context, FinancialSummaryEntity summary) {
    final bankAccount = ref.read(currentBankAccountProvider).value;

    if (bankAccount == null || !bankAccount.isVerified) {
      _showUnverifiedBankDialog(context);
      return;
    }

    _showPayoutAmountModal(context, summary, bankAccount);
  }

  void _showUnverifiedBankDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_outlined,
                size: 36,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rekening Bank Belum Terverifikasi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Untuk keamanan dan kepatuhan perbankan, Anda wajib mendaftarkan dan memverifikasi rekening bank sebelum mencairkan honorarium.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CustomButton(
              label: 'Daftarkan / Verifikasi Rekening',
              onPressed: () {
                Navigator.of(ctx).pop();
                CounselorBankAccountModal.show(context, ref: ref);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Nanti Saja', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayoutAmountModal(
    BuildContext context,
    FinancialSummaryEntity summary,
    BankAccountEntity bankAccount,
  ) {
    final amountCtrl = TextEditingController();
    bool isCreatingQuote = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final requestedAmount = int.tryParse(amountCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
          final available = summary.availableBalance;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.payments_outlined, color: AppColors.primary, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Pencairan Honorarium',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Saldo siap tarik: Rp ${_formatRp(available)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Destination Bank Account Badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${bankAccount.bankName} • ${bankAccount.accountNumberMasked}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'A.N. ${bankAccount.accountHolderName}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'VERIFIED',
                            style: TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Nominal Penarikan (IDR)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setModalState(() {}),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      hintText: '50.000',
                      hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 16),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Quick amount chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildQuickChip(100000, amountCtrl, setModalState),
                      _buildQuickChip(250000, amountCtrl, setModalState),
                      _buildQuickChip(500000, amountCtrl, setModalState),
                      ActionChip(
                        label: const Text('Tarik Semua', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        onPressed: () {
                          setModalState(() {
                            amountCtrl.text = available.toString();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    '• Batas penarikan minimal Rp 50.000\n• Biaya transaksi kliring perbankan Rp 5.000',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 20),

                  CustomButton(
                    label: 'Lanjutkan (Tinjau Rincian)',
                    isLoading: isCreatingQuote,
                    onPressed: () async {
                      if (requestedAmount < 50000) {
                        TopToast.show(
                          context,
                          title: 'Nominal Tidak Memenuhi Syarat',
                          message: 'Nominal penarikan minimal Rp 50.000.',
                          type: ToastType.error,
                        );
                        return;
                      }

                      if (requestedAmount > available) {
                        TopToast.show(
                          context,
                          title: 'Saldo Tidak Mencukupi',
                          message: 'Nominal penarikan melebihi saldo siap tarik (Rp ${_formatRp(available)}).',
                          type: ToastType.error,
                        );
                        return;
                      }

                      setModalState(() => isCreatingQuote = true);
                      try {
                        final repo = ref.read(financeRepositoryProvider);
                        final quote = await repo.createPayoutQuote(
                          bankAccountId: bankAccount.id,
                          amountIdr: requestedAmount,
                        );

                        if (!modalCtx.mounted) return;
                        Navigator.of(modalCtx).pop();

                        if (!context.mounted) return;
                        _showPayoutConfirmationSheet(context, quote, bankAccount);
                      } catch (e) {
                        setModalState(() => isCreatingQuote = false);
                        String msg = 'Gagal membuat quote pencairan.';
                        if (e is ApiException) msg = e.message;
                        TopToast.show(
                          context,
                          title: 'Gagal Membuat Quote',
                          message: msg,
                          type: ToastType.error,
                        );
                      }
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

  Widget _buildQuickChip(
    int amount,
    TextEditingController ctrl,
    void Function(void Function()) setModalState,
  ) {
    return ActionChip(
      label: Text(
        'Rp ${_formatRp(amount)}',
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      onPressed: () {
        setModalState(() {
          ctrl.text = amount.toString();
        });
      },
    );
  }

  void _showPayoutConfirmationSheet(
    BuildContext context,
    PayoutQuoteEntity quote,
    BankAccountEntity bankAccount,
  ) {
    // Generate a stable idempotency key for this quote confirmation session
    final idempotencyKey = 'EVA-IDEMP-${quote.quoteId}-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Konfirmasi Pencairan Dana',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: isSubmitting ? null : () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pastikan data pencairan di bawah ini sudah sesuai sebelum dikirim:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // Quote Breakdown Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildQuoteRow('Nominal Penarikan:', 'Rp ${_formatRp(quote.amountIdr)}'),
                      const SizedBox(height: 8),
                      _buildQuoteRow('Biaya Kliring Bank:', 'Rp ${_formatRp(quote.feeIdr)}'),
                      const Divider(height: 18),
                      _buildQuoteRow(
                        'Dana Bersih Diterima:',
                        'Rp ${_formatRp(quote.netAmountIdr)}',
                        isHighlight: true,
                      ),
                      const SizedBox(height: 8),
                      _buildQuoteRow(
                        'Total Pemotongan Dompet:',
                        'Rp ${_formatRp(quote.walletDebitIdr)}',
                      ),
                      const Divider(height: 18),
                      _buildQuoteRow('Rekening Tujuan:', bankAccount.bankName),
                      const SizedBox(height: 4),
                      _buildQuoteRow('Nomor Rekening:', bankAccount.accountNumberMasked),
                      const SizedBox(height: 4),
                      _buildQuoteRow('Nama Pemilik:', bankAccount.accountHolderName),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Quote ini berlaku selama 10 menit. Permintaan menggunakan kunci idempotensi aman untuk mencegah duplikasi.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isSubmitting ? null : () => Navigator.of(sheetCtx).pop(),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: CustomButton(
                        label: isSubmitting ? 'Mengirim...' : 'Konfirmasi & Kirim',
                        isLoading: isSubmitting,
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setSheetState(() => isSubmitting = true);
                                try {
                                  final repo = ref.read(financeRepositoryProvider);
                                  await repo.submitPayout(
                                    quoteId: quote.quoteId,
                                    idempotencyKey: idempotencyKey,
                                  );

                                  ref.invalidate(financialSummaryProvider);
                                  ref.invalidate(transactionsListProvider);
                                  ref.invalidate(payoutsHistoryProvider);

                                  if (!sheetCtx.mounted) return;
                                  Navigator.of(sheetCtx).pop();

                                  if (!context.mounted) return;
                                  TopToast.show(
                                    context,
                                    title: 'Pencairan Berhasil Diajukan 💳',
                                    message:
                                        'Permintaan dana Rp ${_formatRp(quote.netAmountIdr)} telah dikirim ke antrean perbankan.',
                                    type: ToastType.success,
                                  );
                                } catch (e) {
                                  setSheetState(() => isSubmitting = false);
                                  String msg = 'Gagal memproses penarikan.';
                                  if (e is ApiException) msg = e.message;
                                  TopToast.show(
                                    context,
                                    title: 'Penarikan Gagal',
                                    message: msg,
                                    type: ToastType.error,
                                  );
                                }
                              },
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
  }

  Widget _buildQuoteRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isHighlight ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 15 : 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: isHighlight ? const Color(0xFFC2410C) : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showPayoutDetailModal(BuildContext context, PayoutRecordEntity payout) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detail Transaksi Pencairan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildQuoteRow('ID Referensi:', payout.referenceId),
                  const SizedBox(height: 8),
                  _buildQuoteRow('Status Payout:', payout.statusIndonesianLabel, isHighlight: true),
                  const SizedBox(height: 8),
                  _buildQuoteRow('Nominal Penarikan:', 'Rp ${_formatRp(payout.amountIdr)}'),
                  const SizedBox(height: 8),
                  _buildQuoteRow('Biaya Kliring:', 'Rp ${_formatRp(payout.feeIdr)}'),
                  const SizedBox(height: 8),
                  _buildQuoteRow('Dana Bersih Diterima:', 'Rp ${_formatRp(payout.netAmountIdr)}'),
                  const Divider(height: 18),
                  _buildQuoteRow('Bank Tujuan:', payout.bankAccount?.bankName ?? '-'),
                  const SizedBox(height: 4),
                  _buildQuoteRow('Nomor Rekening:', payout.bankAccount?.accountNumberMasked ?? '-'),
                  const SizedBox(height: 4),
                  _buildQuoteRow('Nama Penerima:', payout.bankAccount?.accountHolderName ?? '-'),
                  const Divider(height: 18),
                  _buildQuoteRow(
                    'Waktu Pengajuan:',
                    '${payout.createdAt.day}/${payout.createdAt.month}/${payout.createdAt.year} ${payout.createdAt.hour.toString().padLeft(2, '0')}:${payout.createdAt.minute.toString().padLeft(2, '0')}',
                  ),
                  if (payout.completedAt != null) ...[
                    const SizedBox(height: 4),
                    _buildQuoteRow(
                      'Waktu Selesai:',
                      '${payout.completedAt!.day}/${payout.completedAt!.month}/${payout.completedAt!.year}',
                    ),
                  ],
                  if (payout.failureMessage != null) ...[
                    const SizedBox(height: 4),
                    _buildQuoteRow('Catatan Gagal:', payout.failureMessage!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              label: 'Tutup',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(financialSummaryProvider);
    final txListAsync = ref.watch(transactionsListProvider);
    final payoutsAsync = ref.watch(payoutsHistoryProvider);
    final bankAccountAsync = ref.watch(currentBankAccountProvider);

    final summary = summaryAsync.value ??
        const FinancialSummaryEntity(
          availableBalance: 0,
          pendingClearingBalance: 0,
          lockedWithdrawalBalance: 0,
          totalEarningsThisMonth: 0,
          totalWithdrawn: 0,
        );

    final bankAccount = bankAccountAsync.value;
    final hasVerifiedBank = bankAccount != null && bankAccount.isVerified;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Balance Overview Card (Clean Modern IDR Hierarchy)
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
                              'Saldo Honorarium Konselor',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              hasVerifiedBank ? 'Rekening Terverifikasi ✅' : 'Belum Ada Rekening ⚠️',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Large Primary Balance
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text(
                            'Rp ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatRp(summary.availableBalance),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Saldo Siap Tarik',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 16),

                      // Breakdown Cards (Available, Pending Clearing, Locked Withdrawal)
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
                                const Text(
                                  'Menunggu Kliring',
                                  style: TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rp ${_formatRp(summary.pendingClearingBalance)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 24, color: Colors.white24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dalam Pencairan',
                                  style: TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rp ${_formatRp(summary.lockedWithdrawalBalance)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 24, color: Colors.white24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Bulan Ini',
                                  style: TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rp ${_formatRp(summary.totalEarningsThisMonth)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text(
                          'Tarik Dana / Pencairan Honorarium',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () => _showPayoutFlow(context, summary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Filter Pills
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Riwayat Transaksi & Pencairan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Semua', 'Honorarium Masuk', 'Pencairan Dana'].map((f) {
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
                                  border: Border.all(
                                    color: isSel ? AppColors.primary : const Color(0xFFECEFF8),
                                  ),
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
                _buildTransactionsList(txListAsync, payoutsAsync),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList(
    AsyncValue<List<TransactionEntity>> txListAsync,
    AsyncValue<List<PayoutRecordEntity>> payoutsAsync,
  ) {
    return txListAsync.when(
      data: (transactions) {
        final filtered = transactions.where((t) {
          if (_selectedFilter == 'Honorarium Masuk') {
            return t.status == TransactionStatus.completed;
          }
          if (_selectedFilter == 'Pencairan Dana') {
            return t.status == TransactionStatus.payoutRequested;
          }
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFECEFF8)),
            ),
            child: const Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textLight),
                SizedBox(height: 8),
                Text(
                  'Tidak ada riwayat transaksi.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return Column(
          children: filtered.map((t) {
            final isPayout = t.status == TransactionStatus.payoutRequested;

            return InkWell(
              onTap: () {
                if (isPayout) {
                  final payouts = payoutsAsync.value ?? [];
                  final match = payouts.isNotEmpty ? payouts.first : null;
                  if (match != null) {
                    _showPayoutDetailModal(context, match);
                  }
                }
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isPayout ? '-Rp ${_formatRp(t.amount)}' : '+Rp ${_formatRp(t.netEarnings)}',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isPayout ? const Color(0xFFC2410C) : AppColors.verifiedGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        isPayout
                            ? StatusBadge.pending('Diproses')
                            : StatusBadge.verified('Selesai'),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Gagal memuat transaksi: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
        ),
      ),
    );
  }
}
