import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import '../providers/counselor_level_metrics_provider.dart';
import 'counselor_level_progress_modal.dart';

class CounselorRateModal {
  static void show({
    required BuildContext context,
    required PsychologistUserEntity? user,
    required Function(int coins) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CounselorRateSheet(user: user),
    );
  }
}

class _CounselorRateSheet extends ConsumerStatefulWidget {
  final PsychologistUserEntity? user;

  const _CounselorRateSheet({required this.user});

  @override
  ConsumerState<_CounselorRateSheet> createState() => _CounselorRateSheetState();
}

class _CounselorRateSheetState extends ConsumerState<_CounselorRateSheet> {
  late TextEditingController _priceController;
  bool _isSaving = false;
  double _customPrice = 50000.0;

  @override
  void initState() {
    super.initState();
    final metrics = ref.read(counselorLevelMetricsProvider).valueOrNull;
    final initialPrice = metrics?.activeSessionPrice ?? 50000.0;
    _customPrice = initialPrice;
    _priceController = TextEditingController(text: initialPrice.toInt().toString());
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  String _formatRupiah(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  Future<void> _handleSavePricing(double minPrice, double maxPrice) async {
    final parsed = double.tryParse(_priceController.text.replaceAll('.', '').trim());
    if (parsed == null || parsed < minPrice || parsed > maxPrice) {
      TopToast.show(
        context,
        title: 'Tarif Tidak Valid',
        message: 'Tarif harus berada di rentang Rp${_formatRupiah(minPrice)} - Rp${_formatRupiah(maxPrice)}',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(counselorLevelMetricsProvider.notifier)
          .updateCustomPrice(parsed);

      if (!mounted) return;
      TopToast.show(
        context,
        title: 'Berhasil Disimpan',
        message: 'Tarif sesi mandiri berhasil diperbarui ke server!',
        type: ToastType.success,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      TopToast.show(
        context,
        title: 'Gagal Memperbarui Tarif',
        message: e.toString(),
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(counselorLevelMetricsProvider);
    final metrics = metricsAsync.valueOrNull;

    final platformFeePercent = metrics?.platformFeePercentage ?? 20.0;
    final minPrice = metrics?.minCustomPrice ?? 100000.0;
    final maxPrice = metrics?.maxCustomPrice ?? 500000.0;

    final feeAmount = _customPrice * (platformFeePercent / 100.0);
    final netEarning = _customPrice - feeAmount;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tarif & Bagi Hasil Platform',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              metrics != null
                  ? 'Tingkat Anda saat ini: Level ${metrics.levelTier} (${metrics.levelName})'
                  : 'Standar tarif dan pembagian hasil terhubung langsung ke server:',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Card 1: Sesi Paten 30 Menit
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.timer_outlined,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sesi Paten: 30 Menit • Rp${_formatRupiah(metrics?.activeSessionPrice ?? 50000.0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pasien dapat memilih jam konsultasi dinamis sesuai jam operasional yang Anda buka.',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 2: Custom Price (If Allowed) vs Locked Tier (If Not Allowed)
            if (metrics?.allowCustomPrice == true) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.tune_rounded,
                              size: 18, color: Color(0xFF9333EA)),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Atur Tarif Mandiri (Master Tier)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF7E22CE),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tentukan tarif konsultasi per sesi 30 menit (Rp${_formatRupiah(minPrice)} - Rp${_formatRupiah(maxPrice)}):',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD8B4FE)),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val.replaceAll('.', '').trim());
                        if (parsed != null) {
                          setState(() => _customPrice = parsed);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Live Breakdown
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tarif Sesi Pasien',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text('Rp${_formatRupiah(_customPrice)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Potongan Platform (${platformFeePercent.toStringAsFixed(0)}%)',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text('- Rp${_formatRupiah(feeAmount)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.error)),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Bagi Hasil Bersih Anda',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF15803D))),
                              Text('Rp${_formatRupiah(netEarning)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF15803D))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : () => _handleSavePricing(minPrice, maxPrice),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Simpan Tarif Baru ke Server',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ] else ...[
              // Locked Card with Level Education
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.handshake_outlined,
                          size: 20, color: Color(0xFF16A34A)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bagi Hasil Transparan & Terkelola',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tarif Rp${_formatRupiah(metrics?.activeSessionPrice ?? 50000.0)} mengikuti Tier ${metrics?.levelName ?? "Praktisi"} dengan bagi hasil bersih ${(100 - platformFeePercent).toStringAsFixed(0)}%.',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF166534),
                                height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.trending_up_rounded,
                    color: AppColors.primary, size: 18),
                label: const Text(
                  'Lihat Syarat Naik Level untuk Custom Tarif',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  CounselorLevelProgressModal.show(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
