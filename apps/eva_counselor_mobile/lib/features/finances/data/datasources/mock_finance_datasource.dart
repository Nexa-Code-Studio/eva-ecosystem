import '../models/bank_account_dto.dart';
import '../models/payout_dto.dart';
import '../models/transaction_dto.dart';
import 'finance_datasource.dart';

class MockFinanceDataSource implements FinanceDataSource {
  final List<TransactionResponseDto> _mockTransactions;
  final List<PayoutRecordDto> _payouts = [];
  final Map<String, PayoutQuoteDto> _quotes = {};
  final Map<String, BankValidationDto> _validations = {};
  final Map<String, PayoutRecordDto> _idempotentPayouts = {};

  BankAccountDto? _currentAccount;
  int _availableBalance;
  final int _pendingClearingBalance;
  int _lockedWithdrawalBalance;
  final int _totalEarningsThisMonth;
  final int _totalWithdrawn;

  MockFinanceDataSource({bool isNewAccount = false})
      : _availableBalance = isNewAccount ? 0 : 850000,
        _pendingClearingBalance = isNewAccount ? 0 : 127500,
        _lockedWithdrawalBalance = 0,
        _totalEarningsThisMonth = isNewAccount ? 0 : 977500,
        _totalWithdrawn = 0,
        _mockTransactions = isNewAccount
            ? []
            : [
                TransactionResponseDto(
                  id: 'TRX-2026-0091',
                  patientName: 'Rian Pratama',
                  sessionType: 'Telekonsultasi Video (30 Menit)',
                  date: DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
                  amount: 150000,
                  adminFee: 30000,
                  netEarnings: 120000,
                  status: 'completed',
                ),
                TransactionResponseDto(
                  id: 'TRX-2026-0089',
                  patientName: 'Rian Pratama',
                  sessionType: 'Perpanjangan In-Call (+30 Menit)',
                  date: DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
                  amount: 150000,
                  adminFee: 30000,
                  netEarnings: 120000,
                  status: 'completed',
                ),
                TransactionResponseDto(
                  id: 'TRX-2026-0084',
                  patientName: 'Dinda Kirana',
                  sessionType: 'Telekonsultasi Video Darurat (30 Menit)',
                  date: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
                  amount: 150000,
                  adminFee: 30000,
                  netEarnings: 120000,
                  status: 'completed',
                ),
                TransactionResponseDto(
                  id: 'TRX-2026-0072',
                  patientName: 'Maya Lestari',
                  sessionType: 'Sesi Evaluasi Kognitif CBT (30 Menit)',
                  date: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
                  amount: 150000,
                  adminFee: 30000,
                  netEarnings: 120000,
                  status: 'completed',
                ),
                TransactionResponseDto(
                  id: 'TRX-2026-0060',
                  patientName: 'Penarikan Dana (Mandiri ****3333)',
                  sessionType: 'Transfer Bank Pencairan Honorarium',
                  date: DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
                  amount: 250000,
                  adminFee: 5000,
                  netEarnings: 245000,
                  status: 'payout_requested',
                  bankAccountInfo: 'Bank Mandiri • BUDI SANTOSO • ****3333',
                ),
              ] {
    if (!isNewAccount) {
      _currentAccount = const BankAccountDto(
        id: 'bank-acc-uuid-001',
        bankCode: 'mandiri',
        bankName: 'Bank Mandiri',
        accountNumberMasked: '****3333',
        accountHolderName: 'BUDI SANTOSO',
        verificationStatus: 'verified',
        verifiedAt: '2026-11-25T02:01:00Z',
        isActive: true,
      );

      _payouts.add(
        const PayoutRecordDto(
          id: 'withdrawal-uuid-001',
          referenceId: 'EVA-WD-001',
          status: 'completed',
          amountIdr: 250000,
          feeIdr: 5000,
          feeBearer: 'counselor',
          netAmountIdr: 245000,
          walletDebitIdr: 250000,
          currency: 'IDR',
          bankAccount: BankAccountDto(
            id: 'bank-acc-uuid-001',
            bankCode: 'mandiri',
            bankName: 'Bank Mandiri',
            accountNumberMasked: '****3333',
            accountHolderName: 'BUDI SANTOSO',
            verificationStatus: 'verified',
          ),
          createdAt: '2026-11-18T02:02:00Z',
          updatedAt: '2026-11-18T02:05:00Z',
          completedAt: '2026-11-18T02:05:00Z',
        ),
      );
    }
  }

  @override
  Future<FinancialSummaryResponseDto> fetchSummary() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return FinancialSummaryResponseDto(
      availableBalance: _availableBalance,
      pendingClearingBalance: _pendingClearingBalance,
      lockedWithdrawalBalance: _lockedWithdrawalBalance,
      totalEarningsThisMonth: _totalEarningsThisMonth,
      totalWithdrawn: _totalWithdrawn,
      currency: 'IDR',
    );
  }

  @override
  Future<List<TransactionResponseDto>> fetchTransactions() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_mockTransactions);
  }

  @override
  Future<List<BankItemDto>> fetchSupportedBanks() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const [
      BankItemDto(code: 'bca', name: 'BCA (Bank Central Asia)'),
      BankItemDto(code: 'mandiri', name: 'Bank Mandiri'),
      BankItemDto(code: 'bni', name: 'BNI (Bank Negara Indonesia)'),
      BankItemDto(code: 'bri', name: 'BRI (Bank Rakyat Indonesia)'),
      BankItemDto(code: 'bsi', name: 'BSI (Bank Syariah Indonesia)'),
      BankItemDto(code: 'cimb', name: 'CIMB Niaga'),
      BankItemDto(code: 'permata', name: 'Bank Permata'),
      BankItemDto(code: 'danamon', name: 'Bank Danamon'),
      BankItemDto(code: 'jago', name: 'Bank Jago'),
      BankItemDto(code: 'seabank', name: 'SeaBank'),
    ];
  }

  @override
  Future<BankValidationDto> validateBankAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final cleanAcc = accountNumber.replaceAll(RegExp(r'\D'), '');
    final lastDigits = cleanAcc.length >= 4 ? cleanAcc.substring(cleanAcc.length - 4) : cleanAcc;

    if (cleanAcc == '0000000000') {
      return BankValidationDto(
        validationId: 'val-${DateTime.now().millisecondsSinceEpoch}',
        bankCode: bankCode,
        bankName: _resolveBankName(bankCode),
        accountNumberMasked: '****$lastDigits',
        accountHolderName: '',
        status: 'not_found',
        nameMatch: 'unknown',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
      );
    }

    if (cleanAcc == '9999999999') {
      return BankValidationDto(
        validationId: 'val-${DateTime.now().millisecondsSinceEpoch}',
        bankCode: bankCode,
        bankName: _resolveBankName(bankCode),
        accountNumberMasked: '****$lastDigits',
        accountHolderName: 'NAMA TIDAK SESUAI',
        status: 'verified',
        nameMatch: 'mismatch',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
      );
    }

    final valId = 'val-${DateTime.now().millisecondsSinceEpoch}';
    final result = BankValidationDto(
      validationId: valId,
      bankCode: bankCode,
      bankName: _resolveBankName(bankCode),
      accountNumberMasked: '****$lastDigits',
      accountHolderName: 'BUDI SANTOSO',
      status: 'verified',
      nameMatch: 'matched',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
    );

    _validations[valId] = result;
    return result;
  }

  @override
  Future<BankAccountDto?> fetchCurrentBankAccount() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _currentAccount;
  }

  @override
  Future<BankAccountDto> saveCurrentBankAccount({required String validationId}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final validation = _validations[validationId];
    if (validation == null) {
      if (_currentAccount != null) return _currentAccount!;
      throw Exception('VALIDATION_EXPIRED: ID validasi tidak ditemukan atau sudah kadaluwarsa.');
    }

    if (validation.status != 'verified' || validation.nameMatch != 'matched') {
      throw Exception('BANK_UNVERIFIED: Rekening bank belum terverifikasi secara valid.');
    }

    _currentAccount = BankAccountDto(
      id: 'bank-acc-${DateTime.now().millisecondsSinceEpoch}',
      bankCode: validation.bankCode,
      bankName: validation.bankName,
      accountNumberMasked: validation.accountNumberMasked,
      accountHolderName: validation.accountHolderName,
      verificationStatus: 'verified',
      verifiedAt: DateTime.now().toIso8601String(),
      isActive: true,
    );

    return _currentAccount!;
  }

  @override
  Future<PayoutPolicyDto> fetchPayoutPolicy() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const PayoutPolicyDto(
      minAmountIdr: 50000,
      maxAmountIdr: 10000000,
      feeIdr: 5000,
      dailyLimitIdr: 20000000,
      isPayoutEnabled: true,
    );
  }

  @override
  Future<PayoutQuoteDto> createPayoutQuote({
    required String bankAccountId,
    required int amountIdr,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    const fee = 5000;
    final quoteId = 'quote-${DateTime.now().millisecondsSinceEpoch}';
    final quote = PayoutQuoteDto(
      quoteId: quoteId,
      bankAccountId: bankAccountId,
      amountIdr: amountIdr,
      feeIdr: fee,
      feeBearer: 'counselor',
      netAmountIdr: amountIdr - fee,
      walletDebitIdr: amountIdr,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
      currency: 'IDR',
    );
    _quotes[quoteId] = quote;
    return quote;
  }

  @override
  Future<PayoutRecordDto> submitPayout({
    required String quoteId,
    required String idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_idempotentPayouts.containsKey(idempotencyKey)) {
      return _idempotentPayouts[idempotencyKey]!;
    }

    final quote = _quotes[quoteId];
    final amount = quote?.amountIdr ?? 250000;
    final fee = quote?.feeIdr ?? 5000;
    final net = quote?.netAmountIdr ?? (amount - fee);

    if (_availableBalance < amount) {
      throw Exception('INSUFFICIENT_BALANCE: Saldo siap tarik tidak mencukupi.');
    }

    _availableBalance -= amount;
    _lockedWithdrawalBalance += amount;

    final payoutId = 'wd-${DateTime.now().millisecondsSinceEpoch}';
    final record = PayoutRecordDto(
      id: payoutId,
      referenceId: 'EVA-WD-${_payouts.length + 100}',
      status: 'waiting_approval',
      amountIdr: amount,
      feeIdr: fee,
      feeBearer: 'counselor',
      netAmountIdr: net,
      walletDebitIdr: amount,
      currency: 'IDR',
      bankAccount: _currentAccount,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    _idempotentPayouts[idempotencyKey] = record;
    _payouts.insert(0, record);

    _mockTransactions.insert(
      0,
      TransactionResponseDto(
        id: 'TRX-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        patientName: 'Pencairan Honorarium (${_currentAccount?.bankName ?? 'Bank'} ${_currentAccount?.accountNumberMasked ?? ''})',
        sessionType: 'Transfer Bank Pencairan Honorarium',
        date: DateTime.now().toIso8601String(),
        amount: amount,
        adminFee: fee,
        netEarnings: net,
        status: 'payout_requested',
        bankAccountInfo: '${_currentAccount?.bankName} • ${_currentAccount?.accountHolderName} • ${_currentAccount?.accountNumberMasked}',
      ),
    );

    return record;
  }

  @override
  Future<PayoutRecordDto> fetchPayoutDetail(String payoutId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _payouts.firstWhere(
      (p) => p.id == payoutId,
      orElse: () => _payouts.isNotEmpty
          ? _payouts.first
          : throw Exception('Payout record not found'),
    );
  }

  @override
  Future<List<PayoutRecordDto>> fetchPayouts() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_payouts);
  }

  @override
  Future<bool> submitPayoutRequest(Map<String, dynamic> payload) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final amount = (payload['amount'] as num?)?.toInt() ?? 500000;
    final bankName = payload['bank_name'] as String? ?? 'BCA';
    final accNum = payload['account_number'] as String? ?? '1234567890';
    final lastDigits = accNum.length >= 4 ? accNum.substring(accNum.length - 4) : accNum;

    _mockTransactions.insert(
      0,
      TransactionResponseDto(
        id: 'TRX-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        patientName: 'Penarikan Dana ($bankName ****$lastDigits)',
        sessionType: 'Transfer Bank Pencairan Honorarium',
        date: DateTime.now().toIso8601String(),
        amount: amount,
        adminFee: 0,
        netEarnings: amount,
        status: 'payout_requested',
        bankAccountInfo: '$bankName • ${payload['account_holder']} • $accNum',
      ),
    );
    return true;
  }

  String _resolveBankName(String code) {
    switch (code.toLowerCase()) {
      case 'bca':
        return 'BCA (Bank Central Asia)';
      case 'mandiri':
        return 'Bank Mandiri';
      case 'bni':
        return 'BNI (Bank Negara Indonesia)';
      case 'bri':
        return 'BRI (Bank Rakyat Indonesia)';
      case 'bsi':
        return 'BSI (Bank Syariah Indonesia)';
      case 'cimb':
        return 'CIMB Niaga';
      case 'permata':
        return 'Bank Permata';
      case 'danamon':
        return 'Bank Danamon';
      case 'jago':
        return 'Bank Jago';
      case 'seabank':
        return 'SeaBank';
      default:
        return code.toUpperCase();
    }
  }
}
