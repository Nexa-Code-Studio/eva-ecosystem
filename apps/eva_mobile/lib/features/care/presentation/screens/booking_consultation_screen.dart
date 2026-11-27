import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_back_button.dart';
import '../../../../widgets/app_snack_bar.dart';
import '../../../../widgets/safe_network_avatar.dart';
import '../../../coin/presentation/providers/coin_provider.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/counselor_timeline_entity.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../providers/care_provider.dart';
import '../widgets/psychologist_availability_timeline_bar.dart';
import '../widgets/session_duration_stepper.dart';

/// Dedicated full-page booking flow for scheduling a consultation with a psychologist.
class BookingConsultationScreen extends ConsumerStatefulWidget {
  final PsychologistEntity psychologist;

  /// Optional clock override for deterministic date/time tests.
  final DateTime Function()? nowProvider;

  const BookingConsultationScreen({
    super.key,
    required this.psychologist,
    this.nowProvider,
  });

  static Future<T?> open<T>(
    BuildContext context,
    PsychologistEntity psychologist,
  ) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConsultationScreen(psychologist: psychologist),
      ),
    );
  }

  @override
  ConsumerState<BookingConsultationScreen> createState() =>
      _BookingConsultationScreenState();
}

class _BookingConsultationScreenState
    extends ConsumerState<BookingConsultationScreen> {
  late DateTime _selectedDate;
  int _sessionCount = 1;
  late TimeOfDay _selectedStartTime;
  late final TextEditingController _startTimeController;
  final FocusNode _startTimeFocusNode = FocusNode();
  final TextEditingController _notesController = TextEditingController();

  String? _timeInputError;
  bool _hasUserEditedTime = false;
  DateTime? _scheduledAutoSelectForDate;
  bool _shareAiChatHistory = false;
  bool _isLoading = false;

  DateTime _now() => (widget.nowProvider ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final now = _now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedStartTime = _defaultStartTimeForToday(now);
    _startTimeController = TextEditingController(
      text: _formatTimeOfDay(_selectedStartTime),
    );
    _startTimeFocusNode.addListener(_handleTimeFieldFocusChange);
  }

  @override
  void dispose() {
    _startTimeFocusNode.removeListener(_handleTimeFieldFocusChange);
    _startTimeFocusNode.dispose();
    _startTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleTimeFieldFocusChange() {
    if (!_startTimeFocusNode.hasFocus && _timeInputError == null) {
      final formatted = _formatTimeOfDay(_selectedStartTime);
      if (_startTimeController.text != formatted) {
        _startTimeController.text = formatted;
      }
    }
  }

  DateTime _minBookingDateTime(DateTime now) {
    final currentMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    return currentMinute.add(const Duration(minutes: 2));
  }

  TimeOfDay _defaultStartTimeForToday(DateTime now) {
    final minBooking = _minBookingDateTime(now);
    if (!_isSameDay(minBooking, now)) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
    final totalMin = minBooking.hour * 60 + minBooking.minute;
    final nextSlotMin = ((totalMin + 29) ~/ 30) * 30;
    final clampedMin = nextSlotMin < 8 * 60 ? 8 * 60 : nextSlotMin;
    if (clampedMin >= 23 * 60 + 30) {
      return TimeOfDay(hour: minBooking.hour, minute: minBooking.minute);
    }
    return TimeOfDay(hour: clampedMin ~/ 60, minute: clampedMin % 60);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatEndTime(TimeOfDay start, int durationMinutes) {
    final endTotal = start.hour * 60 + start.minute + durationMinutes;
    final h = ((endTotal ~/ 60) % 24).toString().padLeft(2, '0');
    final m = (endTotal % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  TimeOfDay? _parseTimeInput(String raw) {
    final normalized = raw.trim().replaceAll('.', ':');
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(normalized);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _minAllowedStartMinutes(CounselorTimelineEntity timeline) {
    final now = _now();
    final opStart = timeline.operatingHours.startMinutes;
    if (!_isSameDay(_selectedDate, now)) return opStart;

    final minBooking = _minBookingDateTime(now);
    if (!_isSameDay(minBooking, _selectedDate)) {
      return timeline.operatingHours.endMinutes;
    }

    final minMin = minBooking.hour * 60 + minBooking.minute;
    return minMin > opStart ? minMin : opStart;
  }

  TimeOfDay? _findEarliestAvailableTime(
    CounselorTimelineEntity timeline,
    int durationMinutes,
  ) {
    final opHours = timeline.operatingHours;
    final minStart = _minAllowedStartMinutes(timeline);
    final maxStart = opHours.endMinutes - durationMinutes;
    if (minStart > maxStart) return null;

    // Coba slot per 15 menit terlebih dahulu agar rapi, lalu fallback per menit.
    final roundedStart = ((minStart + 14) ~/ 15) * 15;
    for (int m = roundedStart; m <= maxStart; m += 15) {
      final candidate = TimeOfDay(hour: m ~/ 60, minute: m % 60);
      if (!timeline.evaluateSelection(candidate, durationMinutes).hasClash) {
        return candidate;
      }
    }
    for (int m = minStart; m <= maxStart; m++) {
      final candidate = TimeOfDay(hour: m ~/ 60, minute: m % 60);
      if (!timeline.evaluateSelection(candidate, durationMinutes).hasClash) {
        return candidate;
      }
    }
    return null;
  }

  String _formatIndonesianDate(DateTime date) {
    const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final dayName = dayNames[(date.weekday - 1).clamp(0, 6)];
    final monthName = monthNames[(date.month - 1).clamp(0, 11)];
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final formatted = '$dayName, ${date.day} $monthName ${date.year}';
    return _isSameDay(date, today) ? 'Hari Ini • $formatted' : formatted;
  }

  Future<void> _pickDate() async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
      helpText: 'Pilih Tanggal Konsultasi',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _hasUserEditedTime = false;
        _scheduledAutoSelectForDate = null;
        _timeInputError = null;
      });
    }
  }

  CollisionResult _evaluateSelection(
    CounselorTimelineEntity timeline,
    int durationMin,
  ) {
    final now = _now();
    final isToday = _isSameDay(_selectedDate, now);
    if (isToday) {
      final minBooking = _minBookingDateTime(now);
      if (!_isSameDay(minBooking, _selectedDate)) {
        return const CollisionResult(
          hasClash: true,
          reason: 'Jam praktik hari ini sudah selesai. Pilih tanggal lain.',
        );
      }

      final minAllowedMin = minBooking.hour * 60 + minBooking.minute;
      final maxStart = timeline.operatingHours.endMinutes - durationMin;
      if (minAllowedMin > maxStart) {
        return const CollisionResult(
          hasClash: true,
          reason: 'Jam praktik hari ini sudah selesai. Pilih tanggal lain.',
        );
      }

      final selectedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedStartTime.hour,
        _selectedStartTime.minute,
      );
      if (selectedDateTime.isBefore(minBooking)) {
        return const CollisionResult(
          hasClash: true,
          reason: 'Jam mulai minimal 2 menit dari waktu saat ini.',
        );
      }
    }

    final baseCollision = timeline.evaluateSelection(_selectedStartTime, durationMin);
    if (!baseCollision.hasClash) return baseCollision;

    if (baseCollision.clashType != null) {
      return CollisionResult(
        hasClash: true,
        reason: 'Jam yang dipilih tidak tersedia. Pilih jam lain pada area tersedia.',
        clashType: baseCollision.clashType,
      );
    }

    return baseCollision;
  }

  void _onStartTimeTextChanged(String value) {
    final parsed = _parseTimeInput(value);
    if (parsed == null) {
      setState(() {
        _timeInputError = 'Gunakan format JJ:MM, contoh 14:30';
      });
      return;
    }

    setState(() {
      _timeInputError = null;
      _hasUserEditedTime = true;
      _selectedStartTime = parsed;
    });
  }

  void _onTimelineTimeSelected(TimeOfDay selected) {
    final formatted = _formatTimeOfDay(selected);
    setState(() {
      _hasUserEditedTime = true;
      _timeInputError = null;
      _selectedStartTime = selected;
      _startTimeController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  Future<void> _pickStartTimeFromDialog(OperatingHoursEntity opHours) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) return;

    final now = _now();
    final isToday = _isSameDay(_selectedDate, now);
    final durationMin = _sessionCount * 30;
    final int minStart;
    if (isToday) {
      final minBooking = _minBookingDateTime(now);
      if (!_isSameDay(minBooking, _selectedDate)) {
        minStart = opHours.endMinutes;
      } else {
        minStart = (minBooking.hour * 60 + minBooking.minute)
            .clamp(opHours.startMinutes, opHours.endMinutes);
      }
    } else {
      minStart = opHours.startMinutes;
    }
    final maxStart =
        (opHours.endMinutes - durationMin).clamp(opHours.startMinutes, opHours.endMinutes);

    final rawMin = picked.hour * 60 + picked.minute;
    final int targetMin;
    if (minStart <= maxStart) {
      targetMin = rawMin.clamp(minStart, maxStart);
      if (rawMin < minStart && isToday) {
        AppSnackBar.showWarning(
          context,
          'Jam yang sudah lewat disesuaikan ke jam terdekat.',
        );
      }
    } else {
      targetMin = rawMin.clamp(opHours.startMinutes, maxStart);
    }

    final resolved = TimeOfDay(hour: targetMin ~/ 60, minute: targetMin % 60);
    _onTimelineTimeSelected(resolved);
  }

  Future<void> _handleConfirmBooking(CollisionResult collision) async {
    if (_timeInputError != null) {
      AppSnackBar.showError(context, _timeInputError!);
      return;
    }

    if (collision.hasClash) {
      AppSnackBar.showError(
        context,
        collision.reason ?? 'Jadwal yang dipilih tidak tersedia.',
      );
      return;
    }

    final requiredCoins = widget.psychologist.coinsPerSession * _sessionCount;
    final currentCoins = ref.read(coinBalanceProvider);

    if (requiredCoins > 0 && currentCoins < requiredCoins) {
      AppSnackBar.showError(
        context,
        'Saldo koin tidak mencukupi untuk konsultasi ini ($requiredCoins Koin).',
        action: SnackBarAction(
          label: 'Top Up',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushNamed(context, '/coin_purchase');
          },
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final finalDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedStartTime.hour,
      _selectedStartTime.minute,
    );

    final success = await ref.read(consultationSessionsProvider.notifier).bookNewSession(
          psychologistId: widget.psychologist.id,
          preferredDateTime: finalDateTime,
          sessionType: ConsultationType.onlineVideo,
          sessionCount: _sessionCount,
          durationMinutes: _sessionCount * 30,
          complaints: _notesController.text.trim(),
          shareAiChatHistory: _shareAiChatHistory,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      if (requiredCoins > 0) {
        await ref.read(coinBalanceProvider.notifier).syncAfterServerDebit(requiredCoins);
      }
      if (!mounted) return;
      await _showSuccessDialog();
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      AppSnackBar.showError(
        context,
        'Gagal menjadwalkan sesi. Silakan coba kembali.',
      );
    }
  }

  Future<void> _showSuccessDialog() {
    final totalCoins = widget.psychologist.coinsPerSession * _sessionCount;
    final totalMinutes = _sessionCount * 30;
    final descriptionText = totalCoins > 0
        ? 'Sesi konsultasi ($_sessionCount Sesi / $totalMinutes Menit) bersama ${widget.psychologist.name} dijadwalkan dengan $totalCoins Koin EVA.'
        : 'Sesi konsultasi ($_sessionCount Sesi / $totalMinutes Menit) bersama ${widget.psychologist.name} berhasil dijadwalkan.';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(22),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.successContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available, color: AppColors.success, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              'Jadwal Berhasil Dibuat!',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              descriptionText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (_shareAiChatHistory) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Riwayat percakapan AI dilampirkan untuk analisis psikolog',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Selesai',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleAutoSelectIfNeeded(CounselorTimelineEntity timeline) {
    if (_hasUserEditedTime || _scheduledAutoSelectForDate == _selectedDate) {
      return;
    }
    _scheduledAutoSelectForDate = _selectedDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasUserEditedTime) return;
      final best = _findEarliestAvailableTime(timeline, _sessionCount * 30);
      if (best != null && best != _selectedStartTime) {
        final formatted = _formatTimeOfDay(best);
        setState(() {
          _selectedStartTime = best;
          _startTimeController.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
          _timeInputError = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final timelineKey = (counselorId: widget.psychologist.id, date: _selectedDate);
    final timelineAsync = ref.watch(counselorTimelineProvider(timelineKey));
    timelineAsync.whenData(_scheduleAutoSelectIfNeeded);

    final now = _now();
    final isToday = _isSameDay(_selectedDate, now);
    TimeOfDay? minSelectableTime;
    if (isToday) {
      final minBooking = _minBookingDateTime(now);
      minSelectableTime = _isSameDay(minBooking, _selectedDate)
          ? TimeOfDay.fromDateTime(minBooking)
          : const TimeOfDay(hour: 23, minute: 59);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Page Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Jadwalkan Konsultasi',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPsychologistHeaderCard(),
                    const SizedBox(height: 20),

                    // Tanggal Sesi
                    _buildSectionTitle('Pilih Tanggal'),
                    const SizedBox(height: 8),
                    _buildDatePickerField(),
                    const SizedBox(height: 20),

                    // Durasi Sesi
                    _buildSectionTitle('Durasi Pemesanan Sesi'),
                    const SizedBox(height: 8),
                    SessionDurationStepper(
                      sessionCount: _sessionCount,
                      coinsPerSession: widget.psychologist.coinsPerSession,
                      onChanged: (newCount) => setState(() => _sessionCount = newCount),
                    ),
                    const SizedBox(height: 20),

                    // Jam Mulai & Ketersediaan
                    timelineAsync.when(
                      data: (timeline) {
                        final durationMin = _sessionCount * 30;
                        final collision = _evaluateSelection(timeline, durationMin);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Ketersediaan & Jam Mulai'),
                            const SizedBox(height: 8),
                            _buildStartTimeInputRow(timeline.operatingHours, durationMin),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderSoft),
                              ),
                              child: PsychologistAvailabilityTimelineBar(
                                timeline: timeline,
                                selectedStartTime: _selectedStartTime,
                                durationMinutes: durationMin,
                                onTimeSelected: _onTimelineTimeSelected,
                                collision: collision,
                                minSelectableTime: minSelectableTime,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildNotesAndConsentSection(),
                          ],
                        );
                      },
                      loading: () => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Ketersediaan & Jam Mulai'),
                          const SizedBox(height: 8),
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildNotesAndConsentSection(),
                        ],
                      ),
                      error: (err, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.errorDark, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Gagal memuat jadwal psikolog. Tarik untuk muat ulang atau coba lagi.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.errorDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildNotesAndConsentSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom CTA Bar
            _buildStickyBottomActionBar(timelineAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildPsychologistHeaderCard() {
    final coins = widget.psychologist.coinsPerSession;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          SafeNetworkAvatar(
            imageUrl: widget.psychologist.avatarUrl,
            radius: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.psychologist.name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.psychologist.title,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: coins > 0 ? AppColors.primaryContainer : AppColors.successContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              coins > 0 ? '$coins Koin' : 'Gratis',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: coins > 0 ? AppColors.onPrimaryContainer : AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField() {
    return InkWell(
      key: const Key('booking_date_picker_field'),
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _formatIndonesianDate(_selectedDate),
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              'Ubah',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartTimeInputRow(
    OperatingHoursEntity opHours,
    int durationMin,
  ) {
    final endFormatted = _formatEndTime(_selectedStartTime, durationMin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('booking_start_time_input'),
                controller: _startTimeController,
                focusNode: _startTimeFocusNode,
                keyboardType: TextInputType.datetime,
                onChanged: _onStartTimeTextChanged,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Jam Mulai (JJ:MM)',
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                  hintText: '14:30',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: AppColors.textLight,
                  ),
                  errorText: _timeInputError,
                  prefixIcon: const Icon(
                    Icons.schedule_rounded,
                    size: 19,
                    color: AppColors.primary,
                  ),
                  suffixText: _timeInputError == null ? 's.d. $endFormatted' : null,
                  suffixStyle: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                key: const Key('booking_pick_time_button'),
                onPressed: () => _pickStartTimeFromDialog(opHours),
                icon: const Icon(Icons.access_time_rounded, size: 18),
                label: Text(
                  'Pilih',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesAndConsentSection() {
    final totalCoins = widget.psychologist.coinsPerSession * _sessionCount;
    final currentCoins = ref.watch(coinBalanceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Fokus atau Cerita Singkat (Opsional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 2,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Misal: Sedang merasa cemas menghadapi sidang atau pekerjaan',
            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.borderSoft),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.borderSoft),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),

        // Persetujuan Berbagi Ringkasan Klinis (ringkas)
        Material(
          color: _shareAiChatHistory
              ? AppColors.primaryContainer.withValues(alpha: 0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => setState(() => _shareAiChatHistory = !_shareAiChatHistory),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _shareAiChatHistory
                      ? AppColors.primary
                      : AppColors.borderSoft,
                  width: _shareAiChatHistory ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      key: const Key('consent_share_chat_history_checkbox'),
                      value: _shareAiChatHistory,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: const BorderSide(
                        color: AppColors.textSecondary,
                        width: 1.5,
                      ),
                      onChanged: (val) {
                        setState(() => _shareAiChatHistory = val ?? false);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bagikan ringkasan klinis',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Opsional. Hanya kirim keluhan dan diagnosis terkonfirmasi, tanpa jurnal atau transkrip suara.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Alat Transaksi: Koin EVA
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monetization_on_rounded,
                  size: 16,
                  color: Color(0xFFFFB300),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alat Transaksi: Koin EVA',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      totalCoins > 0
                          ? 'Total biaya: $totalCoins Koin • Saldo: $currentCoins Koin'
                          : 'Gratis • Saldo: $currentCoins Koin',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (totalCoins > 0 && currentCoins < totalCoins)
                SizedBox(
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/coin_purchase'),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Top Up',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomActionBar(
    AsyncValue<CounselorTimelineEntity> timelineAsync,
  ) {
    final durationMin = _sessionCount * 30;
    final CollisionResult collision = timelineAsync.when(
      data: (timeline) => _evaluateSelection(timeline, durationMin),
      loading: () => const CollisionResult(
        hasClash: true,
        reason: 'Sedang memuat jadwal...',
      ),
      error: (_, _) => const CollisionResult(
        hasClash: true,
        reason: 'Tidak dapat mengonfirmasi jadwal.',
      ),
    );

    final isButtonEnabled =
        !collision.hasClash && _timeInputError == null && !_isLoading;

    final String ctaText;
    if (_timeInputError != null) {
      ctaText = 'Format Jam Tidak Valid';
    } else if (timelineAsync.isLoading) {
      ctaText = 'Memuat Jadwal...';
    } else if (collision.hasClash) {
      ctaText = 'Pilih Jam yang Tersedia';
    } else {
      ctaText = 'Konfirmasi Janji Konsultasi';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          key: const Key('booking_confirm_button'),
          onPressed: isButtonEnabled ? () => _handleConfirmBooking(collision) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.surfaceHigh,
            foregroundColor: Colors.white,
            disabledForegroundColor: AppColors.textSecondary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  ctaText,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
