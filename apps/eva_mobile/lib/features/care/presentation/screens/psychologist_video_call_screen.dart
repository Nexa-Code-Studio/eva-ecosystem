import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../providers/care_provider.dart';
import '../widgets/consultation_result_bottom_sheet.dart';

/// Immersive Mock Video Call screen with licensed psychologists and peer counselors.
class PsychologistVideoCallScreen extends ConsumerStatefulWidget {
  final ConsultationSessionEntity session;

  const PsychologistVideoCallScreen({
    super.key,
    required this.session,
  });

  @override
  ConsumerState<PsychologistVideoCallScreen> createState() =>
      _PsychologistVideoCallScreenState();
}

class _PsychologistVideoCallScreenState
    extends ConsumerState<PsychologistVideoCallScreen>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _secondsElapsed = 0;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _isSpeakerOn = true;
  bool _isPsychologistSpeaking = true;
  late AnimationController _pulseController;

  final List<Map<String, String>> _liveMessages = [
    {
      'sender': 'psychologist',
      'text': 'Halo, selamat datang di sesi konsultasi online kita hari ini.',
      'time': '00:05',
    },
    {
      'sender': 'psychologist',
      'text':
          'Ambil posisi yang paling nyaman ya. Bagaimana perasaanmu hari ini?',
      'time': '00:15',
    },
    {
      'sender': 'psychologist',
      'text':
          'Mari kita mulai dengan latihan pernapasan diafragma 4-7-8 sejenak untuk menenangkan detak jantung.',
      'time': '00:30',
    },
  ];

  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startTimer();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Alternate speaking indicator every few seconds
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _isPsychologistSpeaking = !_isPsychologistSpeaking;
      });
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  String _formatTimer(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _handleEndCall() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.call_end_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Akhiri Sesi Konsultasi?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Sesi akan diselesaikan dan catatan rangkuman beserta saran psikolog akan otomatis tersimpan di Riwayat Bicara.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Lanjutkan Sesi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _completeAndExitCall();
              },
              child: Text(
                'Ya, Selesaikan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeAndExitCall() async {
    final advice = widget.session.adviceList.isNotEmpty
        ? widget.session.adviceList
        : const [
            'Lakukan relaksasi napas 4-7-8 setiap pagi dan malam.',
            'Gunakan format restrukturisasi kognitif di Eva Diary saat overthinking.',
            'Jadwalkan sesi evaluasi lanjutan dalam 2 minggu ke depan.',
          ];

    final actionItems = widget.session.actionItems.isNotEmpty
        ? widget.session.actionItems
        : const [
            'Tulis 3 hal yang disyukuri setiap malam di Jurnal Eva.',
            'Latih mindful pause 3 detik sebelum merespon saat merasa tegang.',
          ];

    const sessionSummary =
        'Sesi video call tatap muka online selesai dilaksanakan. Pasien menunjukkan perbaikan pemahaman emosi dan memiliki rencana aksi mandiri yang jelas.';
    const moodAfter = 'Lebih Tenang & Terarah (Skala 4/10)';

    // 1. Mark session completed in Riverpod provider
    await ref.read(consultationSessionsProvider.notifier).completeSession(
          widget.session.id,
          adviceList: advice,
          actionItems: actionItems,
          sessionSummary: sessionSummary,
          moodAfter: moodAfter,
        );

    if (!mounted) return;

    final updatedSession = widget.session.copyWith(
      status: ConsultationStatus.completed,
      adviceList: advice,
      actionItems: actionItems,
      sessionSummary: sessionSummary,
      moodAfter: moodAfter,
    );

    // 2. Langsung tampilkan bottom sheet saran sesi hasil konsultasi (bukan dilarikan ke log history)
    await ConsultationResultBottomSheet.show(
      context,
      updatedSession,
      onClose: () {
        if (mounted) {
          Navigator.pop(context);
        }
      },
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _openLiveChatNotesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Catatan & Chat Sesi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Messages List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _liveMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _liveMessages[index];
                    final isPsy = msg['sender'] == 'psychologist';

                    return Align(
                      alignment: isPsy ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: isPsy
                              ? const Color(0xFFF1F5F9)
                              : AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: isPsy
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.end,
                          children: [
                            Text(
                              isPsy
                                  ? widget.session.psychologist.name
                                  : 'Kamu (Pasien)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isPsy
                                    ? AppColors.textSecondary
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg['text'] ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              msg['time'] ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Chat Input Box
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Kirim pesan atau catatan...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                      onPressed: () {
                        final text = _chatController.text.trim();
                        if (text.isNotEmpty) {
                          setState(() {
                            _liveMessages.add({
                              'sender': 'user',
                              'text': text,
                              'time': _formatTimer(_secondsElapsed),
                            });
                          });
                          _chatController.clear();
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final psychologist = widget.session.psychologist;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Fullscreen Main Video Feed (Psychologist)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0F172A),
                      const Color(0xFF1E293B),
                      const Color(0xFF0F172A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Psychologist Video Feed Mock Image
                    Opacity(
                      opacity: 0.88,
                      child: Image.network(
                        psychologist.avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF1E293B),
                          child: const Icon(
                            Icons.person,
                            size: 100,
                            color: Colors.white30,
                          ),
                        ),
                      ),
                    ),

                    // Cinematic Gradient Overlays
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.65),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Speaking Indicator Waves
                    if (_isPsychologistSpeaking)
                      Positioned(
                        bottom: 120,
                        left: 20,
                        right: 20,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.graphic_eq_rounded,
                                  color: Color(0xFF22C55E),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${psychologist.name} sedang berbicara...',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 2. Top Bar (Header & Timer)
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Psychologist Header Info
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(psychologist.avatarUrl),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                psychologist.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Online • Sesi #${widget.session.sessionNumber}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Timer Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fiber_manual_record_rounded,
                          color: Color(0xFFEF4444),
                          size: 11,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTimer(_secondsElapsed),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. User Floating PIP Camera Preview (Self-View)
            Positioned(
              top: 76,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() => _isFrontCamera = !_isFrontCamera);
                },
                child: Container(
                  width: 104,
                  height: 148,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isCameraOff)
                        Container(
                          color: const Color(0xFF0F172A),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.videocam_off_rounded,
                                  color: Colors.white54,
                                  size: 26,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Kamera Mati',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          color: const Color(0xFF334155),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primary,
                                  child: const Icon(
                                    Icons.person,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Kamu',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Camera Flip hint
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.flip_camera_ios_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Bottom Video Call Action Control Bar
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Mute / Unmute Mic
                    _buildControlButton(
                      icon: _isMicMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      isActive: !_isMicMuted,
                      activeColor: Colors.white24,
                      iconColor: _isMicMuted
                          ? const Color(0xFFEF4444)
                          : Colors.white,
                      onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                    ),

                    // Camera On / Off
                    _buildControlButton(
                      icon: _isCameraOff
                          ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded,
                      isActive: !_isCameraOff,
                      activeColor: Colors.white24,
                      iconColor: _isCameraOff
                          ? const Color(0xFFEF4444)
                          : Colors.white,
                      onTap: () => setState(() => _isCameraOff = !_isCameraOff),
                    ),

                    // Flip Camera
                    _buildControlButton(
                      icon: Icons.flip_camera_ios_rounded,
                      isActive: true,
                      activeColor: Colors.white24,
                      iconColor: Colors.white,
                      onTap: () => setState(() => _isFrontCamera = !_isFrontCamera),
                    ),

                    // Chat & Notes Drawer
                    _buildControlButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      isActive: true,
                      activeColor: AppColors.primary,
                      iconColor: Colors.white,
                      onTap: _openLiveChatNotesSheet,
                    ),

                    // End Call Button (Red)
                    GestureDetector(
                      onTap: _handleEndCall,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: activeColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}
