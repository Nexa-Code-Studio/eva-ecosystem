import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/counselor_timeline_entity.dart';
import '../providers/care_provider.dart';
import '../../../coin/presentation/providers/coin_provider.dart';
import 'psychologist_availability_timeline_bar.dart';
import 'session_duration_stepper.dart';

class BookingConsultationSheet extends ConsumerStatefulWidget {
  final PsychologistEntity psychologist;

  const BookingConsultationSheet({
    super.key,
    required this.psychologist,
  });

  static Future<void> show(BuildContext context, PsychologistEntity psychologist) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingConsultationSheet(psychologist: psychologist),
    );
  }

  @override
  ConsumerState<BookingConsultationSheet> createState() => _BookingConsultationSheetState();
}

class _BookingConsultationSheetState extends ConsumerState<BookingConsultationSheet> {
  int _selectedDayOffset = 1; // 1 = Besok, 2 = Lusa, 3 = 3 Hari Lagi
  int _sessionCount = 1; // 1 sesi = 30m, 2 sesi = 60m, dst.
  TimeOfDay _selectedStartTime = const TimeOfDay(hour: 9, minute: 0);
  final TextEditingController _notesController = TextEditingController();
  bool _shareAiChatHistory = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickManualStartTime(OperatingHoursEntity opHours) async {
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

    if (picked != null) {
      final rawMin = picked.hour * 60 + picked.minute;
      final durationMin = _sessionCount * 30;
      final maxStart = (opHours.endMinutes - durationMin)
          .clamp(opHours.startMinutes, opHours.endMinutes);
      final clampedMin = rawMin.clamp(opHours.startMinutes, maxStart);
      setState(() {
        _selectedStartTime = TimeOfDay(
          hour: clampedMin ~/ 60,
          minute: clampedMin % 60,
        );
      });
    }
  }

  Future<void> _handleConfirmBooking(CollisionResult collision) async {
    if (collision.hasClash) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            collision.reason ?? 'Jadwal yang Anda pilih bentrok dengan sesi lain/istirahat.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final requiredCoins = widget.psychologist.coinsPerSession * _sessionCount;
    final currentCoins = ref.read(coinBalanceProvider);

    if (requiredCoins > 0 && currentCoins < requiredCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saldo koin tidak mencukupi untuk konsultasi ini ($requiredCoins Koin).',
            style: GoogleFonts.plusJakartaSans(fontSize: 12),
          ),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'Top Up',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/coin_purchase');
            },
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final finalDateTime = DateTime(
      now.year,
      now.month,
      now.day + _selectedDayOffset,
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
      // Sinkronkan saldo koin dari PostgreSQL (atau kurangi lokal pada mock mode)
      if (requiredCoins > 0) {
        await ref.read(coinBalanceProvider.notifier).syncAfterServerDebit(requiredCoins);
      }
      if (!mounted) return;
      Navigator.pop(context);
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menjadwalkan sesi. Silakan coba kembali.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    final totalCoins = widget.psychologist.coinsPerSession * _sessionCount;
    final totalMinutes = _sessionCount * 30;
    final descriptionText = totalCoins > 0
        ? 'Sesi konsultasi ($_sessionCount Sesi / $totalMinutes Menit) bersama ${widget.psychologist.name} telah berhasil dijadwalkan dengan transaksi $totalCoins Koin EVA.'
        : 'Sesi konsultasi ($_sessionCount Sesi / $totalMinutes Menit) bersama ${widget.psychologist.name} telah berhasil dijadwalkan secara gratis.';

    showDialog(
      context: context,
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              descriptionText,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (_shareAiChatHistory) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.4),
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
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
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Selesai',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final targetDate = DateTime(now.year, now.month, now.day + _selectedDayOffset);
    final timelineAsync = ref.watch(counselorTimelineProvider(
      (counselorId: widget.psychologist.id, date: targetDate),
    ));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Psychologist Summary Header
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryContainer,
                  backgroundImage: NetworkImage(widget.psychologist.avatarUrl),
                  onBackgroundImageError: (exception, stackTrace) {},
                  child: Text(
                    widget.psychologist.name.substring(0, 2).toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.psychologist.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.psychologist.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Mode Telekonsultasi Online (100% Video Call)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Telekonsultasi Video Call Online • Durasi 30 Menit / Sesi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Tanggal Sesi
            Text(
              'Pilih Hari',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDayChip('Besok', 1),
                const SizedBox(width: 8),
                _buildDayChip('Lusa', 2),
                const SizedBox(width: 8),
                _buildDayChip('3 Hari Lagi', 3),
              ],
            ),
            const SizedBox(height: 18),

            // Durasi Sesi & Stepper
            Text(
              'Durasi Pemesanan Sesi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SessionDurationStepper(
              sessionCount: _sessionCount,
              coinsPerSession: widget.psychologist.coinsPerSession,
              onChanged: (newCount) => setState(() => _sessionCount = newCount),
            ),
            const SizedBox(height: 18),

            // Timeline Ketersediaan & Pilihan Jam
            timelineAsync.when(
              data: (timeline) {
                final durationMin = _sessionCount * 30;
                final collision = timeline.evaluateSelection(_selectedStartTime, durationMin);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ketersediaan & Jam Mulai',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        InkWell(
                          onTap: () => _pickManualStartTime(timeline.operatingHours),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.edit_calendar_outlined,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Pilih Jam Manual',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PsychologistAvailabilityTimelineBar(
                      timeline: timeline,
                      selectedStartTime: _selectedStartTime,
                      durationMinutes: durationMin,
                      onTimeSelected: (t) => setState(() => _selectedStartTime = t),
                      collision: collision,
                    ),
                    const SizedBox(height: 18),

                    // Catatan Singkat
                    _buildNotesAndConsentSection(),

                    const SizedBox(height: 20),

                    // Action Button
                    _buildConfirmButton(collision: collision),
                  ],
                );
              },
              loading: () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Memuat Ketersediaan Jadwal...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildNotesAndConsentSection(),
                  const SizedBox(height: 20),
                  _buildConfirmButton(
                    collision: const CollisionResult(
                      hasClash: true,
                      reason: 'Sedang memuat data ketersediaan jadwal...',
                    ),
                  ),
                ],
              ),
              error: (err, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gagal memuat jadwal psikolog: $err',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildNotesAndConsentSection(),
                  const SizedBox(height: 20),
                  _buildConfirmButton(
                    collision: const CollisionResult(
                      hasClash: true,
                      reason: 'Tidak dapat mengonfirmasi jadwal.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesAndConsentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Catatan Singkat
        Text(
          'Fokus atau Cerita Singkat (Opsional)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Misal: Sedang merasa cemas menghadapi sidang/pekerjaan...',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textLight),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        const SizedBox(height: 16),

        // Persetujuan Berbagi Riwayat Chat AI (Consent)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _shareAiChatHistory
                ? AppColors.primaryContainer.withValues(alpha: 0.35)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _shareAiChatHistory
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
              width: _shareAiChatHistory ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _shareAiChatHistory = !_shareAiChatHistory;
              });
            },
            borderRadius: BorderRadius.circular(10),
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
                      color: Color(0xFF94A3B8),
                      width: 1.5,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _shareAiChatHistory = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Bagikan Ringkasan Klinis Terpilih ke Psikolog',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Opsional (Default non-aktif). Mengirimkan keluhan dan diagnosis profesional yang telah Anda konfirmasi tanpa membagikan transkrip suara atau jurnal pribadi.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
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
        const SizedBox(height: 16),

        // Alat Transaksi: Koin EVA
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4FE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryContainer),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      widget.psychologist.coinsPerSession > 0
                          ? 'Biaya: ${widget.psychologist.coinsPerSession} Koin • Saldo koinmu: ${ref.watch(coinBalanceProvider)} Koin'
                          : 'Bebas biaya koin (Gratis) • Saldo koinmu: ${ref.watch(coinBalanceProvider)} Koin',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.psychologist.coinsPerSession > 0 &&
                  ref.watch(coinBalanceProvider) < widget.psychologist.coinsPerSession)
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/coin_purchase');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Top Up',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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

  Widget _buildConfirmButton({required CollisionResult collision}) {
    final isButtonEnabled = !collision.hasClash && !_isLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isButtonEnabled ? () => _handleConfirmBooking(collision) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: isButtonEnabled ? 2 : 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                collision.hasClash ? 'Jadwal Bentrok - Pilih Jam Lain' : 'Konfirmasi Janji Konsultasi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildDayChip(String label, int offset) {
    final isSelected = _selectedDayOffset == offset;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedDayOffset = offset),
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
        ),
      ),
    );
  }
}
