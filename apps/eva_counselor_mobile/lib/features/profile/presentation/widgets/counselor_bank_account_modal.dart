import 'package:flutter/material.dart';
import '../../../../core/widgets/app_async_state_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finances/domain/entities/bank_account_entity.dart';
import '../../../finances/presentation/providers/finance_provider.dart';

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
  BankItemEntity? _selectedBank;
  late TextEditingController _accountNumberCtrl;

  bool _isValidating = false;
  bool _isSaving = false;
  BankValidationEntity? _validationResult;
  String? _validationErrorMessage;

  @override
  void initState() {
    super.initState();
    _accountNumberCtrl = TextEditingController();

    // Check existing bank account from currentBankAccountProvider or authStateProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeRef = widget.ref ?? ref;
      final currentAccount = activeRef.read(currentBankAccountProvider).value;
      final user = activeRef.read(authStateProvider).value;

      final hasExisting = currentAccount != null || (user?.bankName != null && user!.bankName.isNotEmpty);
      if (!hasExisting) {
        setState(() {
          _isEditing = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _accountNumberCtrl.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (_validationResult != null || _validationErrorMessage != null) {
      setState(() {
        _validationResult = null;
        _validationErrorMessage = null;
      });
    }
  }

  void _openBankSelector(List<BankItemEntity> banks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return _BankSelectorBottomSheet(
          banks: banks,
          selectedBank: _selectedBank,
          onSelected: (bank) {
            Navigator.of(modalCtx).pop();
            setState(() {
              _selectedBank = bank;
              _onInputChanged();
            });
          },
        );
      },
    );
  }

  Future<void> _validateAccount() async {
    final activeRef = widget.ref ?? ref;
    final bank = _selectedBank;
    final accountNumber = _accountNumberCtrl.text.trim();

    if (bank == null || accountNumber.isEmpty) {
      TopToast.show(
        context,
        title: 'Form Belum Lengkap',
        message: 'Mohon pilih bank tujuan dan isi nomor rekening Anda.',
        type: ToastType.error,
      );
      return;
    }

    setState(() {
      _isValidating = true;
      _validationErrorMessage = null;
      _validationResult = null;
    });

    try {
      final repo = activeRef.read(financeRepositoryProvider);
      final result = await repo.validateBankAccount(
        bankCode: bank.code,
        accountNumber: accountNumber,
      );

      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _validationResult = result;
      });

      if (!result.isVerified) {
        if (result.isMismatch) {
          _validationErrorMessage =
              'Nama pada rekening bank (${result.accountHolderName}) tidak cocok dengan identitas terdaftar Anda.';
        } else if (result.isNotFound) {
          _validationErrorMessage =
              'Nomor rekening tidak ditemukan pada bank ${bank.name}. Mohon periksa kembali nomor rekening.';
        } else {
          _validationErrorMessage =
              'Status validasi: ${result.status}. Rekening ini tidak dapat disimpan secara langsung.';
        }
      }
    } catch (e) {
      if (!mounted) return;
      String err = 'Gagal memverifikasi rekening bank ke provider inquiry.';
      if (e is ApiException) {
        err = e.message;
      }
      setState(() {
        _isValidating = false;
        _validationErrorMessage = err;
      });
      TopToast.show(
        context,
        title: 'Validasi Gagal',
        message: err,
        type: ToastType.error,
      );
    }
  }

  Future<void> _saveVerifiedAccount() async {
    final activeRef = widget.ref ?? ref;
    final validation = _validationResult;
    if (validation == null || !validation.isVerified) {
      TopToast.show(
        context,
        title: 'Rekening Belum Valid',
        message: 'Mohon lakukan validasi rekening terlebih dahulu.',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = activeRef.read(financeRepositoryProvider);
      final saved = await repo.saveCurrentBankAccount(
        validationId: validation.validationId,
      );

      // Invalidate relevant providers to update the application UI
      activeRef.invalidate(currentBankAccountProvider);
      activeRef.invalidate(financialSummaryProvider);

      // Sync local auth user state in memory
      activeRef.read(authStateProvider.notifier).syncVerifiedBankAccount(
            bankName: saved.bankName,
            accountNumberMasked: saved.accountNumberMasked,
            accountHolderName: saved.accountHolderName,
          );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isEditing = false;
        _validationResult = null;
        _accountNumberCtrl.clear();
      });

      TopToast.show(
        context,
        title: 'Rekening Tersimpan',
        message: 'Rekening ${saved.bankName} berhasil diverifikasi dan disimpan sebagai rekening pencairan.',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      String err = 'Gagal menyimpan rekening bank.';
      if (e is ApiException) err = e.message;
      TopToast.show(
        context,
        title: 'Gagal Menyimpan',
        message: err,
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRef = widget.ref ?? ref;
    final currentAccountAsync = activeRef.watch(currentBankAccountProvider);
    final banksAsync = activeRef.watch(supportedBanksProvider);
    final user = activeRef.watch(authStateProvider).value;

    final currentAccount = currentAccountAsync.value;
    final effectiveBankName = currentAccount?.bankName ?? user?.bankName ?? '';
    final effectiveAccountNumber = currentAccount?.accountNumberMasked ??
        ((user?.bankAccountNumber ?? '').isNotEmpty
            ? '****${user!.bankAccountNumber.length >= 4 ? user.bankAccountNumber.substring(user.bankAccountNumber.length - 4) : user.bankAccountNumber}'
            : '');
    final effectiveAccountHolder = currentAccount?.accountHolderName ?? user?.bankAccountHolder ?? user?.displayName ?? '';
    final isVerified = currentAccount?.isVerified ?? false;

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
                          ? 'Daftarkan Rekening Bank'
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
              'Rekening bank tujuan pencairan honorarium telekonsultasi Eva AI yang diverifikasi resmi:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 18, color: Color(0xFFB45309)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nama pemilik rekening divalidasi langsung via inquiry bank resmi. Nama rekening wajib identik dengan data psikolog terdaftar.',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF92400E),
                          height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (!_isEditing) ...[
              if (effectiveBankName.isNotEmpty) ...[
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
                            effectiveBankName,
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
                        effectiveAccountNumber,
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
                            effectiveAccountHolder,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isVerified
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF92400E),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isVerified ? 'Terverifikasi' : 'Belum Diverifikasi',
                              style: TextStyle(
                                color: isVerified
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(0xFFFDE68A),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
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
                // Empty state
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_outlined,
                          size: 44, color: AppColors.textLight),
                      const SizedBox(height: 10),
                      const Text(
                        'Belum Ada Rekening Terdaftar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Daftarkan rekening bank Anda agar dapat mencairkan honorarium telekonsultasi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        label: 'Daftarkan Rekening Sekarang',
                        onPressed: () => setState(() => _isEditing = true),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // EDIT FORM (Clean Inquiry Validation Flow)
              banksAsync.when(
                data: (banks) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Bank Tujuan Pencairan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _openBankSelector(banks),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFD6D9E4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_outlined,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _selectedBank?.name ?? 'Pilih Nama Bank Tujuan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedBank != null
                                        ? AppColors.textPrimary
                                        : AppColors.textLight,
                                    fontWeight: _selectedBank != null
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded,
                                  color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => AppAsyncStateView.loading(
                  title: 'Memuat daftar bank...',
                  message: 'Mengambil daftar bank yang didukung.',
                  compact: true,
                ),
                error: (e, _) => AppAsyncStateView.error(
                  title: 'Gagal memuat daftar bank',
                  message: 'Daftar bank belum dapat dimuat saat ini.',
                  onRetry: () => ref.invalidate(supportedBanksProvider),
                  compact: true,
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Nomor Rekening Bank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _accountNumberCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _onInputChanged(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Contoh: 1234567890',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.pin_outlined,
                      color: AppColors.primary, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD6D9E4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD6D9E4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Button to Validate Account with provider inquiry
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isValidating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                label: Text(
                  _isValidating ? 'Memeriksa ke Bank...' : 'Periksa Rekening (Inquiry Bank)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
                onPressed: _isValidating ? null : _validateAccount,
              ),

              if (_validationErrorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationErrorMessage!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF991B1B),
                              height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_validationResult != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _validationResult!.isVerified
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _validationResult!.isVerified
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Hasil Inquiry Bank:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _validationResult!.isVerified
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _validationResult!.isVerified
                                  ? 'Terverifikasi'
                                  : 'Tidak Valid',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _validationResult!.isVerified
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _validationResult!.accountHolderName.isNotEmpty
                            ? _validationResult!.accountHolderName
                            : '(Nama tidak ditemukan)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_validationResult!.bankName} • ${_validationResult!.accountNumberMasked}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],

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
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _validationResult = null;
                          _validationErrorMessage = null;
                        });
                      },
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CustomButton(
                      label: 'Simpan Rekening',
                      isLoading: _isSaving,
                      onPressed: (_validationResult != null &&
                              _validationResult!.isVerified &&
                              !_isSaving)
                          ? _saveVerifiedAccount
                          : null,
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

class _BankSelectorBottomSheet extends StatefulWidget {
  final List<BankItemEntity> banks;
  final BankItemEntity? selectedBank;
  final ValueChanged<BankItemEntity> onSelected;

  const _BankSelectorBottomSheet({
    required this.banks,
    required this.selectedBank,
    required this.onSelected,
  });

  @override
  State<_BankSelectorBottomSheet> createState() =>
      _BankSelectorBottomSheetState();
}

class _BankSelectorBottomSheetState extends State<_BankSelectorBottomSheet> {
  late TextEditingController _searchCtrl;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.banks.where((b) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return b.name.toLowerCase().contains(q) || b.code.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pilih Bank Tujuan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _filter = val.trim()),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              hintText: 'Cari nama bank (BCA, Mandiri, dsb)...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Bank tidak ditemukan',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final item = filtered[idx];
                      final isSelected = widget.selectedBank?.code == item.code;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryContainer : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.account_balance_outlined,
                            size: 18,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 20)
                            : null,
                        onTap: () => widget.onSelected(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
