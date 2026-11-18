import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CounselorBankAccountModal {
  static void show(BuildContext context, {WidgetRef? ref}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _BankAccountModalContent(ref: ref),
    );
  }
}

class _BankAccountModalContent extends ConsumerStatefulWidget {
  final WidgetRef? ref;

  const _BankAccountModalContent({this.ref});

  @override
  ConsumerState<_BankAccountModalContent> createState() =>
      _BankAccountModalContentState();
}

class _BankAccountModalContentState
    extends ConsumerState<_BankAccountModalContent> {
  bool _isEditing = false;
  late TextEditingController _bankNameCtrl;
  late TextEditingController _accountNumberCtrl;
  late TextEditingController _accountHolderCtrl;

  @override
  void initState() {
    super.initState();
    final user = (widget.ref ?? ref).read(authStateProvider).value;
    _bankNameCtrl = TextEditingController(
        text: user?.bankName ?? 'BCA (Bank Central Asia)');
    _accountNumberCtrl =
        TextEditingController(text: user?.bankAccountNumber ?? '8192039182');
    _accountHolderCtrl = TextEditingController(
        text: user?.bankAccountHolder ?? 'dr. Sarah Jenkins, M.Psi');
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    super.dispose();
  }

  void _saveBankDetails() {
    if (_bankNameCtrl.text.trim().isEmpty ||
        _accountNumberCtrl.text.trim().isEmpty ||
        _accountHolderCtrl.text.trim().isEmpty) {
      TopToast.show(
        context,
        title: 'Form Belum Lengkap',
        message: 'Mohon isi nama bank, nomor rekening, dan nama pemilik.',
        type: ToastType.error,
      );
      return;
    }

    (widget.ref ?? ref).read(authStateProvider.notifier).updateBankDetails(
          bankName: _bankNameCtrl.text.trim(),
          accountNumber: _accountNumberCtrl.text.trim(),
          accountHolder: _accountHolderCtrl.text.trim(),
        );

    setState(() => _isEditing = false);

    TopToast.show(
      context,
      title: 'Rekening Tersimpan! 💳',
      message: 'Rekening pencairan dana berhasil diperbarui.',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = (widget.ref ?? ref).watch(authStateProvider).value;
    final bankName = user?.bankName ?? _bankNameCtrl.text;
    final accountNumber = user?.bankAccountNumber ?? _accountNumberCtrl.text;
    final accountHolder = user?.bankAccountHolder ?? _accountHolderCtrl.text;

    final maskedAccount = accountNumber.length > 4
        ? '•••• •••• •••• ${accountNumber.substring(accountNumber.length - 4)}'
        : accountNumber;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      _isEditing
                          ? 'Ubah Rekening Bank'
                          : 'Rekening Bank Pencairan',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Rekening terdaftar untuk pencairan otomatis honorarium telekonsultasi Eva AI:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            if (!_isEditing) ...[
              // ATM / Debit Card Visual
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bankName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('UTAMA',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      maskedAccount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          accountHolder,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        const Text(
                          'TERVERIFIKASI ✅',
                          style: TextStyle(
                            color: Color(0xFF6EE7B7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pencairan saldo dompet diproses ke rekening di atas secara real-time atau otomatis terjadwal tanpa potongan transfer.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD6D9E4)),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.edit_note_rounded,
                    size: 18, color: AppColors.primary),
                label: const Text(
                  'Ubah Rekening Bank',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primary),
                ),
                onPressed: () => setState(() => _isEditing = true),
              ),
            ] else ...[
              // EDIT FORM
              CustomTextField(
                label: 'Nama Bank (e.g. BCA, Mandiri, BNI, BRI)',
                hint: 'Masukkan nama bank',
                controller: _bankNameCtrl,
                prefixIcon: Icons.account_balance_outlined,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Nomor Rekening',
                hint: 'Masukkan nomor rekening',
                controller: _accountNumberCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.pin_outlined,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Nama Pemilik Rekening (Sesuai Buku Tabungan / KTP)',
                hint: 'Masukkan nama lengkap pemilik',
                controller: _accountHolderCtrl,
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => setState(() => _isEditing = false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CustomButton(
                      label: 'Simpan Rekening',
                      onPressed: _saveBankDetails,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
