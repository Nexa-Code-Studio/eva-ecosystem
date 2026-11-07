import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
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
    final coinAmountCtrl = TextEditingController(text: '150');
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
                    Row(
                      children: const [
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
                  isNumber: true,
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 10),
                _buildModalInput('Nama Bank Tujuan', bankCtrl),
                const SizedBox(height: 10),
                _buildModalInput('Nomor Rekening', accountCtrl, isNumber: true),
                const SizedBox(height: 10),
                _buildModalInput('Nama Pemilik Rekening (Sesuai KTP)', nameCtrl),
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

                    setModalState(() => isSubmitting = true);
                    final repo = ref.read(financeRepositoryProvider);
                    await repo.requestPayout(
                      amount: estimatedRp,
                      bankName: bankCtrl.text,
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
                          'Penukaran $requestedCoins Koin (Rp ${_formatRp(estimatedRp)}) sedang ditransfer ke rekening ${bankCtrl.text}.',
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

  void _showUpgradeModal(BuildContext context) {
    final strCtrl = TextEditingController();
    final assocCtrl = TextEditingController(text: 'HIMPSI');
    final partnerCtrl = TextEditingController();
    CounselorRole targetRole = CounselorRole.professionalIndependent;
    String? pickedFile;
    bool isUpgrading = false;

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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Upgrade ke Psikolog Profesional',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Daftarkan STR/SIPP Anda untuk membuka akses sistem koin honorarium dan rekam medis SOAP klinis.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // Role Choice
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Praktik Mandiri'),
                          selected: targetRole == CounselorRole.professionalIndependent,
                          onSelected: (_) => setModalState(
                              () => targetRole = CounselorRole.professionalIndependent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Dengan Mitra'),
                          selected: targetRole == CounselorRole.professionalPartner,
                          onSelected: (_) => setModalState(
                              () => targetRole = CounselorRole.professionalPartner),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildModalInput('Nomor STR / SIPP Aktif', strCtrl),
                  const SizedBox(height: 10),
                  _buildModalInput('Organisasi Profesi', assocCtrl),
                  if (targetRole == CounselorRole.professionalPartner) ...[
                    const SizedBox(height: 10),
                    _buildModalInput('Nama Lembaga Mitra', partnerCtrl),
                  ],
                  const SizedBox(height: 12),

                  // Upload doc
                  InkWell(
                    onTap: () {
                      setModalState(() {
                        pickedFile = 'STR_Scan_Verified_${DateTime.now().year}.pdf';
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFECEFF8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            pickedFile != null ? Icons.check_circle : Icons.upload_file,
                            size: 18,
                            color: pickedFile != null
                                ? AppColors.verifiedGreen
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            pickedFile ?? 'Unggah Scan Berkas STR (PDF/JPG)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: pickedFile != null
                                  ? AppColors.verifiedGreen
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  CustomButton(
                    label: 'Verifikasi & Upgrade Sekarang',
                    isLoading: isUpgrading,
                    onPressed: () async {
                      if (strCtrl.text.isEmpty) {
                        TopToast.show(
                          context,
                          title: 'Nomor STR Wajib Diisi',
                          message: 'Mohon masukkan nomor STR/SIPP Anda.',
                          type: ToastType.error,
                        );
                        return;
                      }

                      setModalState(() => isUpgrading = true);
                      ref.read(authStateProvider.notifier).upgradeToProfessional(
                            strNumber: strCtrl.text,
                            association: assocCtrl.text,
                            certificateDocFileName: pickedFile ?? 'STR_Uploaded.pdf',
                            newRole: targetRole,
                            partnerName: targetRole == CounselorRole.professionalPartner
                                ? partnerCtrl.text
                                : null,
                          );

                      await Future.delayed(const Duration(milliseconds: 500));
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (!context.mounted) return;

                      TopToast.show(
                        context,
                        title: 'Akun Berhasil Di-Upgrade!',
                        message:
                            'Selamat! Akun Anda kini aktif sebagai Psikolog Profesional dengan akses dompet koin.',
                        type: ToastType.success,
                      );
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

  Widget _buildModalInput(
    String label,
    TextEditingController ctrl, {
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
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

    // KASUS 1: RELAWAN NON-PROFESIONAL (VOLUNTEER) GATED
    if (authUser?.isVolunteer == true) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F7F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFF00796B),
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F7F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Relawan Teman Sebaya • Non-Profit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00796B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Menu Keuangan Khusus Profesional',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Layanan Teman Sebaya bersifat murni kemanusiaan & sukarela tanpa sistem transaksi koin.\n\nUntuk membuka dompet koin, menentukan tarif sesi telekonsultasi, dan merekrut pasien klinis, silakan daftarkan sertifikasi STR/SIPP Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      label: 'Upgrade ke Psikolog Profesional',
                      icon: Icons.verified_user_rounded,
                      onPressed: () => _showUpgradeModal(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // KASUS 2: PROFESIONAL DENGAN MITRA (KOIN DIATUR & MASUK KE KANTONG MITRA DI WEB)
    if (authUser?.isPartner == true) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Partner Notice Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6B21A8), Color(0xFF9333EA)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7E22CE).withValues(alpha: 0.25),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Mitra: ${authUser?.partnerName ?? "Klinik Sehati"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(Icons.apartment_rounded, color: Colors.white, size: 20),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Sistem Keuangan Dikelola Web Mitra',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Seluruh koin sesi telekonsultasi Anda disalurkan langsung ke kas lembaga mitra via Web Portal Mitra.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: const [
                            _MitraStatItem(label: 'Sesi Bulan Ini', value: '38 Sesi'),
                            _MitraStatItem(label: 'Koin Mitra Terakumulasi', value: '5.700 Koin'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Riwayat Sesi Konsultasi Mitra',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                _buildTransactionsList(txListAsync, isPartner: true),
              ],
            ),
          ),
        ),
      );
    }

    // KASUS 3: PROFESIONAL MANDIRI (SISTEM KOIN & REDEEM RUPIAH)
    final coins = authUser?.coinBalance ?? 1250;
    final rateCoins = authUser?.coinsPerSession ?? 150;
    final sessionMins = authUser?.sessionDurationMinutes ?? 50;

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
                            children: const [
                              Text('Menunggu Selesai SOAP', style: TextStyle(color: Colors.white70, fontSize: 10)),
                              SizedBox(height: 2),
                              Text('150 Koin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          Container(width: 1, height: 24, color: Colors.white24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Koin Bulan Ini', style: TextStyle(color: Colors.white70, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text('${coins + 2000} Koin', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
              _buildTransactionsList(txListAsync, isPartner: false),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList(AsyncValue<List<TransactionEntity>> txListAsync, {required bool isPartner}) {
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
                          isPartner
                              ? '+$coinsEarned Koin'
                              : isPayout
                                  ? '-$coinsEarned Koin'
                                  : '+$coinsEarned Koin',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: isPayout ? const Color(0xFFC2410C) : AppColors.verifiedGreen,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isPartner)
                          const Text(
                            '(Kas Mitra)',
                            style: TextStyle(fontSize: 10, color: Color(0xFF7E22CE), fontWeight: FontWeight.bold),
                          )
                        else if (isPayout)
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

class _MitraStatItem extends StatelessWidget {
  final String label;
  final String value;

  const _MitraStatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
