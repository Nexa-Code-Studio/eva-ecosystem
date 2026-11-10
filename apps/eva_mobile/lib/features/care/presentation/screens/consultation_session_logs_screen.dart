import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_back_button.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/psychologist_rating_review.dart';
import '../providers/care_provider.dart';
import '../widgets/booking_consultation_sheet.dart';
import 'consultation_rating_screen.dart';
import 'psychologist_detail_screen.dart';

/// Dedicated screen for displaying detailed clinical session logs, evaluations,
/// and actionable recommendations provided by a psychologist.
class ConsultationSessionLogsScreen extends ConsumerStatefulWidget {
  final PsychologistEntity psychologist;
  final List<ConsultationSessionEntity> sessions;

  const ConsultationSessionLogsScreen({
    super.key,
    required this.psychologist,
    required this.sessions,
  });

  @override
  ConsumerState<ConsultationSessionLogsScreen> createState() =>
      _ConsultationSessionLogsScreenState();
}

class _ConsultationSessionLogsScreenState
    extends ConsumerState<ConsultationSessionLogsScreen> {
  DateTime? _selectedDate; // null means 'Semua Tanggal'

  String _formatDate(DateTime dt) {
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatShortDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    // Reactively watch sessions from provider if available, fallback to passed sessions
    final sessionsAsync = ref.watch(consultationSessionsProvider);
    final allSessions = sessionsAsync.value ?? [];
    final psychologistSessions = allSessions
        .where((s) => s.psychologist.id == widget.psychologist.id)
        .toList();

    final activeSessions = psychologistSessions.isNotEmpty
        ? psychologistSessions
        : widget.sessions;

    final displayedSessions = _selectedDate == null
        ? activeSessions
        : activeSessions
            .where((s) => _isSameDay(s.sessionDateTime, _selectedDate!))
            .toList();

    final userRating = ref.watch(psychologistRatingsProvider)[widget.psychologist.id];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Navigation Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log & Saran Sesi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Catatan klinis & rekomendasi per sesi',
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
            ),

            // 2. Scrollable Body
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  // Psychologist Overview Card
                  _buildPsychologistHeaderCard(activeSessions.length),
                  const SizedBox(height: 14),

                  // Rating Section (Prompt to rate or Preview of submitted rating)
                  _buildRatingSection(userRating),
                  const SizedBox(height: 14),

                  // Date Filter Bar
                  if (activeSessions.isNotEmpty) ...[
                    _buildDateFilterBar(activeSessions),
                    const SizedBox(height: 14),
                  ],

                  // Session Logs List or Empty State
                  if (displayedSessions.isEmpty)
                    _buildEmptyState()
                  else
                    ...displayedSessions.map((session) {
                      return _buildSessionLogCard(session);
                    }),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // 3. Persistent Bottom Action Dock
            _buildBottomActionDock(),
          ],
        ),
      ),
    );
  }

  /// Psychologist Summary Header Card with Profile Navigation
  Widget _buildPsychologistHeaderCard(int totalSessionsCount) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PsychologistDetailScreen(
                psychologist: widget.psychologist,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(widget.psychologist.avatarUrl),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
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
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.psychologist.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.psychologist.rating}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•  $totalSessionsCount Sesi Dijalani',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rating section: switches between Rating Prompt Card and Rating Preview Card
  Widget _buildRatingSection(PsychologistRatingReview? userRating) {
    if (userRating != null) {
      return _buildRatingPreviewCard(userRating);
    }
    return _buildRatingPromptCard();
  }

  /// Interactive card prompting the user to submit a rating and review
  Widget _buildRatingPromptCard() {
    final counselorFirstName = widget.psychologist.name.split(',')[0];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Color(0xFFF59E0B),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Beri Penilaian Sesi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bagikan pengalamanmu bersama $counselorFirstName',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConsultationRatingScreen(
                    psychologist: widget.psychologist,
                  ),
                ),
              );
            },
            child: Text(
              'Beri Rating',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Preview card of the rating & review submitted by the user
  /// Strictly follows the format: Star, Baik/Tidak (Sentiment), Label, & Deskripsi
  Widget _buildRatingPreviewCard(PsychologistRatingReview userRating) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Avatar + Star + Numeric Score + 'Ubah' Button
          Row(
            children: [
              const CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.primaryContainer,
                child: Icon(
                  Icons.person_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ulasan Anda',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Star Rating Display
                    Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            final isFilled = (index + 1) <= userRating.rating.floor();
                            return Icon(
                              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFilled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                              size: 13,
                            );
                          }),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          userRating.rating.toStringAsFixed(1),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 'Ubah' Button
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConsultationRatingScreen(
                        psychologist: widget.psychologist,
                        initialRating: userRating,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Ubah',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Label (Ulasan Singkat)
          if (userRating.label.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.rate_review_outlined,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      userRating.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 3. Deskripsi (Ulasan Lengkap)
          if (userRating.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.format_quote_rounded,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    userRating.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Horizontal date filter chips for filtering session logs by date
  Widget _buildDateFilterBar(List<ConsultationSessionEntity> sessions) {
    final uniqueDates = <DateTime>{};
    for (final s in sessions) {
      uniqueDates.add(DateTime(
        s.sessionDateTime.year,
        s.sessionDateTime.month,
        s.sessionDateTime.day,
      ));
    }
    final sortedDates = uniqueDates.toList()..sort((a, b) => b.compareTo(a));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Calendar picker button
          InkWell(
            onTap: () => _pickDate(context, sessions),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedDate != null ? AppColors.primary : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: _selectedDate != null ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 16,
                    color: _selectedDate != null ? AppColors.primary : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 'Semua Tanggal' Chip
          ChoiceChip(
            label: Text('Semua Tanggal (${sessions.length})'),
            selected: _selectedDate == null,
            onSelected: (_) => setState(() => _selectedDate = null),
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _selectedDate == null ? Colors.white : AppColors.textPrimary,
            ),
            side: BorderSide(
              color: _selectedDate == null ? AppColors.primary : const Color(0xFFE2E8F0),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(width: 8),

          // Date Chips for unique session dates
          ...sortedDates.map((date) {
            final isSelected = _selectedDate != null && _isSameDay(_selectedDate!, date);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_formatShortDate(date)),
                selected: isSelected,
                onSelected: (_) => setState(() {
                  _selectedDate = isSelected ? null : date;
                }),
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }),

          // If a custom date was picked outside the existing list
          if (_selectedDate != null && !sortedDates.any((d) => _isSameDay(d, _selectedDate!)))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: const Icon(Icons.check, size: 14, color: Colors.white),
                label: Text(_formatShortDate(_selectedDate!)),
                selected: true,
                onSelected: (_) => setState(() => _selectedDate = null),
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  /// Open Date Picker modal
  Future<void> _pickDate(
    BuildContext context,
    List<ConsultationSessionEntity> sessions,
  ) async {
    final now = DateTime.now();
    final initial = _selectedDate ??
        (sessions.isNotEmpty ? sessions.first.sessionDateTime : now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Session Log Detail Card
  Widget _buildSessionLogCard(ConsultationSessionEntity session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Session # & Mode & Duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sesi #${session.sessionNumber}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          session.isOnlineVideo
                              ? Icons.videocam_rounded
                              : Icons.place_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          session.isOnlineVideo ? 'Video Call' : 'Tatap Muka',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${session.durationMinutes} Menit',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Date & Time
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '${_formatDate(session.sessionDateTime)} • ${_formatTime(session.sessionDateTime)} WIB',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // 1. Initial Complaint / Keluhan Pasien
          if (session.notes != null && session.notes!.isNotEmpty) ...[
            Text(
              'TOPIK & KELUHAN AWAL',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textLight,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '"${session.notes}"',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 2. Clinical Evaluation & Diagnosis Summary
          if (session.diagnosisSummary != null && session.diagnosisSummary!.isNotEmpty) ...[
            Text(
              'RINGKASAN EVALUASI PSIKOLOG',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textLight,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryContainer),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.psychology_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.diagnosisSummary!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 3. Saran & Rekomendasi Klinis (Aligned with Eva's Success Palette)
          if (session.adviceList.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_rounded,
                        size: 17,
                        color: AppColors.successDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Saran & Rekomendasi Psikolog:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.successDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...session.adviceList.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.successContainer,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.success),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.successDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 4. Action Items / Latihan Mandiri (Homework)
          if (session.actionItems.isNotEmpty) ...[
            Text(
              'LATIHAN MANDIRI (ACTION ITEMS)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textLight,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            ...session.actionItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // 5. Mood Progress Transition
          if (session.moodBefore != null || session.moodAfter != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perubahan Kondisi Emosional: ${session.moodBefore ?? '-'} ➔ ${session.moodAfter ?? 'Membaik'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Empty state when no sessions match filter
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_rounded,
            size: 40,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedDate != null
                ? 'Tidak ada catatan sesi pada ${_formatShortDate(_selectedDate!)}'
                : 'Tidak ada catatan sesi yang ditemukan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (_selectedDate != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(() => _selectedDate = null),
              child: Text(
                'Tampilkan Semua Tanggal',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Persistent bottom dock for rebooking / scheduling new sessions
  Widget _buildBottomActionDock() {
    final counselorFirstName = widget.psychologist.name.split(',')[0];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () {
            BookingConsultationSheet.show(context, widget.psychologist);
          },
          icon: const Icon(Icons.event_available_rounded, size: 18),
          label: Text(
            'Jadwalkan Sesi Baru Bersama $counselorFirstName',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
