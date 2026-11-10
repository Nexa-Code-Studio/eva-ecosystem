import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../providers/care_provider.dart';
import '../../../coin/presentation/providers/coin_provider.dart';
import 'clinic_location_map_card.dart';

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
  ConsultationType _selectedType = ConsultationType.onlineVideo;
  int _selectedDayOffset = 1; // 1 = Besok, 2 = Lusa
  int _selectedTimeSlot = 0; // Index in slots
  final TextEditingController _notesController = TextEditingController();
  bool _shareAiChatHistory = true;
  bool _isLoading = false;

  final List<String> _timeSlots = [
    '09:00 WIB',
    '13:30 WIB',
    '16:00 WIB',
    '19:30 WIB',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirmBooking() async {
    final requiredCoins = widget.psychologist.coinsPerSession;
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

    final targetDate = DateTime.now().add(Duration(days: _selectedDayOffset));
    final slotParts = _timeSlots[_selectedTimeSlot].split(' ')[0].split(':');
    final hour = int.parse(slotParts[0]);
    final minute = int.parse(slotParts[1]);

    final finalDateTime = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    );

    final success = await ref.read(consultationSessionsProvider.notifier).bookNewSession(
          psychologistId: widget.psychologist.id,
          preferredDateTime: finalDateTime,
          sessionType: _selectedType,
          complaints: _notesController.text.trim(),
          shareAiChatHistory: _shareAiChatHistory,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      // Deduct coins if required
      if (requiredCoins > 0) {
        await ref.read(coinBalanceProvider.notifier).spendCoins(requiredCoins);
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
    final coins = widget.psychologist.coinsPerSession;
    final descriptionText = coins > 0
        ? 'Sesi konsultasi Anda bersama ${widget.psychologist.name} telah berhasil dijadwalkan dengan transaksi $coins Koin EVA.'
        : 'Sesi konsultasi Anda bersama ${widget.psychologist.name} telah berhasil dijadwalkan secara gratis.';

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

            // Mode Sesi Selector
            Text(
              'Pilih Moda Konsultasi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTypeOption(
                    title: 'Online Video',
                    subtitle: 'Via Google Meet',
                    icon: Icons.videocam_outlined,
                    type: ConsultationType.onlineVideo,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTypeOption(
                    title: 'Tatap Muka',
                    subtitle: widget.psychologist.clinicAffiliation ?? 'Klinik Mitra',
                    icon: Icons.location_city_outlined,
                    type: ConsultationType.offlineClinic,
                  ),
                ),
              ],
            ),

            // Tunjukkan Maps Jika Moda Offline / Tatap Muka
            if (_selectedType == ConsultationType.offlineClinic) ...[
              const SizedBox(height: 12),
              ClinicLocationMapCard(
                clinicName: widget.psychologist.clinicAffiliation ?? 'Klinik Mitra Eva Care',
                address: 'Jl. Kemanggisan Raya No. 45, Palmerah, Jakarta Barat',
              ),
            ],

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
            const SizedBox(height: 16),

            // Pilihan Jam Sesi
            Text(
              'Pilih Jam Sesi (Durasi ${widget.psychologist.durationMinutes} menit)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_timeSlots.length, (index) {
                final isSelected = _selectedTimeSlot == index;
                return ChoiceChip(
                  label: Text(_timeSlots[index]),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedTimeSlot = index),
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
              }),
            ),
            const SizedBox(height: 16),

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
                              Text(
                                'Bagikan Riwayat Chat AI ke Psikolog',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Saya bersedia mengirimkan riwayat percakapan dengan AI sebagai bahan analisis untuk psikolog.',
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
            const SizedBox(height: 18),

            // CTA Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleConfirmBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Konfirmasi Janji Konsultasi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required ConsultationType type,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
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
