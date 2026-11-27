import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webrtc_client/webrtc_client.dart';

import '../../../../config/app_config.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_snack_bar.dart';
import '../../../../widgets/safe_network_avatar.dart';
import '../../../coin/presentation/providers/coin_provider.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/extension_availability_entity.dart';
import '../../domain/entities/video_call_state_entity.dart';
import '../controllers/video_call_controller.dart';
import '../providers/care_provider.dart';
import '../providers/video_call_provider.dart';
import 'booking_consultation_screen.dart';
import '../widgets/consultation_result_bottom_sheet.dart';
import '../widgets/in_call_extension_sheet.dart';

/// Real-Time WebRTC Video Call Screen for psychological teleconsultation (Answerer).
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
  final List<Map<String, String>> _sessionNotes = [];
  final TextEditingController _notesController = TextEditingController();
  bool _isEnding = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Draggable PiP coordinates
  Offset _pipPosition = const Offset(16, 76);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context)) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _notesController.dispose();
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Sesi akan diselesaikan dan catatan rangkuman beserta saran psikolog akan otomatis tersimpan di Riwayat Bicara.',
            style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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

  Future<void> _handleExtendTap(VideoCallController controller) async {
    try {
      final availability = await controller.checkExtensionAvailability();
      if (!mounted) return;

      if (availability.canExtend) {
        final currentBalance = ref.read(coinBalanceProvider);
        final requiredCoins = availability.extensionCoins > 0
            ? availability.extensionCoins
            : widget.session.psychologist.coinsPerSession;

        await showDialog<void>(
          context: context,
          builder: (_) => InCallExtensionConfirmDialog(
            requiredCoins: requiredCoins,
            currentBalance: currentBalance,
            onTopUp: () => Navigator.pushNamed(context, '/coin_purchase'),
            onConfirm: () => _executeDirectExtension(controller, requiredCoins),
          ),
        );
      } else {
        await _showBusyExtensionSheet(availability);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Gagal memeriksa ketersediaan perpanjangan sesi.',
        );
      }
    }
  }

  Future<void> _executeDirectExtension(
    VideoCallController controller,
    int requiredCoins,
  ) async {
    final success = await controller.confirmAndExtendSession();
    if (!mounted) return;

    if (success) {
      if (!widget.session.isPreview) {
        ref
            .read(consultationSessionsProvider.notifier)
            .markSessionExtended(widget.session.id, newDurationMinutes: 60);
        if (requiredCoins > 0) {
          await ref
              .read(coinBalanceProvider.notifier)
              .syncAfterServerDebit(requiredCoins);
        }
      }
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        'Sesi diperpanjang +30 menit (total 60 menit).',
      );
    } else {
      AppSnackBar.showError(
        context,
        'Gagal memperpanjang sesi. Silakan periksa jadwal atau saldo koin.',
      );
    }
  }

  Future<void> _showBusyExtensionSheet(
    ExtensionAvailabilityEntity availability,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InCallExtensionBusySheet(
        availability: availability,
        onScheduleNext: () {
          BookingConsultationScreen.open(context, widget.session.psychologist);
        },
      ),
    );
  }

  Future<void> _completeAndExitCall() async {
    if (_isEnding) return;
    _isEnding = true;
    await ref
        .read(videoCallControllerProvider(widget.session).notifier)
        .endCall();

    final useFallbackSummary = widget.session.isPreview || AppConfig.useMockData;

    final advice = widget.session.adviceList.isNotEmpty
        ? widget.session.adviceList
        : (useFallbackSummary
            ? const [
                'Lakukan relaksasi napas 4-7-8 setiap pagi dan malam.',
                'Gunakan format restrukturisasi kognitif di Eva Diary saat overthinking.',
                'Jadwalkan sesi evaluasi lanjutan dalam 2 minggu ke depan.',
              ]
            : const <String>[]);

    final actionItems = widget.session.actionItems.isNotEmpty
        ? widget.session.actionItems
        : (useFallbackSummary
            ? const [
                'Tulis 3 hal yang disyukuri setiap malam di Jurnal Eva.',
                'Latih mindful pause 3 detik sebelum merespon saat merasa tegang.',
              ]
            : const <String>[]);

    final String? sessionSummary =
        (widget.session.sessionSummary != null && widget.session.sessionSummary!.isNotEmpty)
            ? widget.session.sessionSummary
            : (useFallbackSummary
                ? 'Sesi video call telekonsultasi psikologi telah selesai dilaksanakan dengan lancar.'
                : null);
    final String? moodAfter =
        (widget.session.moodAfter != null && widget.session.moodAfter!.isNotEmpty)
            ? widget.session.moodAfter
            : (useFallbackSummary ? 'Lebih Tenang & Terarah (Skala 4/10)' : null);

    if (!widget.session.isPreview) {
      try {
        await ref.read(consultationSessionsProvider.notifier).completeSession(
              widget.session.id,
              adviceList: advice.isNotEmpty ? advice : null,
              actionItems: actionItems.isNotEmpty ? actionItems : null,
              sessionSummary: sessionSummary,
              moodAfter: moodAfter,
            );
      } catch (_) {}
    }

    if (!mounted) return;

    final refreshedSessions = ref.read(consultationSessionsProvider).value;
    ConsultationSessionEntity? serverSession;
    if (refreshedSessions != null) {
      for (final item in refreshedSessions) {
        if (item.id == widget.session.id) {
          serverSession = item;
          break;
        }
      }
    }

    final updatedSession = (serverSession ?? widget.session).copyWith(
      status: ConsultationStatus.completed,
      adviceList: (serverSession?.adviceList.isNotEmpty ?? false)
          ? serverSession!.adviceList
          : advice,
      actionItems: (serverSession?.actionItems.isNotEmpty ?? false)
          ? serverSession!.actionItems
          : actionItems,
      sessionSummary: serverSession?.sessionSummary ?? sessionSummary,
      moodAfter: serverSession?.moodAfter ?? moodAfter,
    );

    await ConsultationResultBottomSheet.show(
      context,
      updatedSession,
      onClose: () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _showQualityPresetSheet(
      VideoCallStateEntity callState, dynamic controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kualitas Video Konsultasi',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pilih preset kualitas video sesuai kondisi bandwidth jaringan Anda.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildQualityOption(
                  title: '720p HD (Rekomendasi)',
                  subtitle: '1280x720, 24-30 fps • ~1.5 Mbps',
                  preset: VideoQualityPreset.hd720p,
                  isSelected: callState.qualityPreset == VideoQualityPreset.hd720p,
                  onSelect: () {
                    controller.setVideoQualityPreset(VideoQualityPreset.hd720p);
                    Navigator.pop(ctx);
                  },
                ),
                _buildQualityOption(
                  title: '480p Hemat Data',
                  subtitle: '640x480, 24 fps • ~800 kbps',
                  preset: VideoQualityPreset.sd480p,
                  isSelected: callState.qualityPreset == VideoQualityPreset.sd480p,
                  onSelect: () {
                    controller.setVideoQualityPreset(VideoQualityPreset.sd480p);
                    Navigator.pop(ctx);
                  },
                ),
                _buildQualityOption(
                  title: 'Audio-Only (Kamera Mati)',
                  subtitle: 'Panggilan suara jernih hemat kuota • ~64 kbps',
                  preset: VideoQualityPreset.audioOnly,
                  isSelected:
                      callState.qualityPreset == VideoQualityPreset.audioOnly,
                  onSelect: () {
                    controller.setVideoQualityPreset(VideoQualityPreset.audioOnly);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQualityOption({
    required String title,
    required String subtitle,
    required VideoQualityPreset preset,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryContainer.withValues(alpha: 0.4)
            : AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.borderSoft,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onSelect,
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20)
              : null,
        ),
      ),
    );
  }

  void _openNotesSheet() {
    final callState = ref.read(videoCallControllerProvider(widget.session));

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          size: 22,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Catatan Pribadi Sesi',
                          style: GoogleFonts.inter(
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
              const Divider(height: 1, color: AppColors.borderSoft),
              Expanded(
                child: _sessionNotes.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada catatan. Tulis poin penting dari psikolog di sini.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessionNotes.length,
                        itemBuilder: (context, index) {
                          final note = _sessionNotes[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.borderSoft),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note['text'] ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  note['time'] ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _notesController,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tulis catatan konsultasi...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceLow,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: AppColors.borderSoft),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: AppColors.primary),
                      onPressed: () {
                        final text = _notesController.text.trim();
                        if (text.isNotEmpty) {
                          setState(() {
                            _sessionNotes.add({
                              'text': text,
                              'time': _formatTimer(
                                  callState.callDurationSeconds),
                            });
                          });
                          _notesController.clear();
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

  Widget _buildPermissionGate(dynamic controller) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141633).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      margin: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E224F),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.videocam_off_rounded,
              color: Color(0xFFFBBF24),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Izin Kamera & Mikrofon Diperlukan',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Untuk memulai sesi tatap muka online dengan psikolog, izinkan akses kamera dan mikrofon perangkat Anda, atau lanjutkan dalam mode Audio-Only.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    controller.setVideoQualityPreset(VideoQualityPreset.audioOnly);
                  },
                  child: Text(
                    'Audio-Only Saja',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    openAppSettings();
                  },
                  child: Text(
                    'Buka Pengaturan',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingRoom(
      ConsultationSessionEntity session, bool disableAnimation) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final scale = disableAnimation ? 1.0 : _pulseAnimation.value;
              return Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 2.5,
                    ),
                  ),
                  child: SafeNetworkAvatar(
                    imageUrl: session.psychologist.avatarUrl,
                    radius: 54,
                    backgroundColor: const Color(0xFF1E224F),
                    iconColor: Colors.white,
                    iconSize: 48,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            session.psychologist.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            session.psychologist.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!disableAnimation)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                else
                  const Icon(
                    Icons.hourglass_empty_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                const SizedBox(width: 10),
                Text(
                  'Menunggu psikolog bergabung ke ruangan...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sesi akan otomatis terhubung begitu psikolog siap.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge(VideoCallStateEntity callState) {
    Color dotColor;
    IconData icon;
    String statusText;

    if (callState.isWaitingForCounselor) {
      dotColor = const Color(0xFFF59E0B);
      icon = Icons.hourglass_top_rounded;
      statusText = 'Menunggu Psikolog';
    } else {
      switch (callState.connectionState) {
        case VideoCallConnectionState.connecting:
          dotColor = const Color(0xFFF59E0B);
          icon = Icons.sync_rounded;
          statusText = 'Menghubungkan...';
          break;
        case VideoCallConnectionState.connected:
          dotColor = const Color(0xFF22C55E);
          icon = Icons.verified_user_rounded;
          statusText = 'Terhubung • Sesi #${widget.session.sessionNumber}';
          break;
        case VideoCallConnectionState.reconnecting:
          dotColor = const Color(0xFFF97316);
          icon = Icons.wifi_off_rounded;
          statusText = 'Menghubungkan Ulang...';
          break;
        case VideoCallConnectionState.ended:
          dotColor = const Color(0xFFEF4444);
          icon = Icons.call_end_rounded;
          statusText = 'Panggilan Berakhir';
          break;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: dotColor, size: 12),
        const SizedBox(width: 5),
        Text(
          statusText,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final psychologist = widget.session.psychologist;
    final callState = ref.watch(videoCallControllerProvider(widget.session));
    ref.listen<VideoCallStateEntity>(
      videoCallControllerProvider(widget.session),
      (previous, next) {
        if (_isEnding) return;
        if (previous?.connectionState != VideoCallConnectionState.ended &&
            next.connectionState == VideoCallConnectionState.ended) {
          AppSnackBar.showWarning(
            context,
            'Psikolog mengakhiri sesi konsultasi.',
          );
          _completeAndExitCall();
        }
      },
    );
    final controller =
        ref.read(videoCallControllerProvider(widget.session).notifier);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    if (callState.isWaitingForCounselor && !disableAnimations) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    }

    final showPermissionGate = !callState.isCameraPermissionGranted &&
        callState.qualityPreset != VideoQualityPreset.audioOnly;

    return Scaffold(
      backgroundColor: const Color(0xFF141633),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Fullscreen Main Video Feed (Psychologist Remote Feed / Waiting Room)
            Positioned.fill(
              child: callState.isWaitingForCounselor
                  ? _buildWaitingRoom(widget.session, disableAnimations)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        // Remote RTCVideoView
                        if (controller.peerManager.isInitialized)
                          RTCVideoView(
                            controller.peerManager.remoteRenderer,
                            objectFit:
                                RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          )
                        else
                          // Fallback backdrop avatar
                          _buildBackdropAvatar(psychologist.avatarUrl),

                        // Scrim overlay for accessibility
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
                      ],
                    ),
            ),

            // 2. Permission Gate Overlay
            if (showPermissionGate)
              Center(
                child: _buildPermissionGate(controller),
              ),

            // 3. Reconnection Warning Banner
            if (callState.isCounselorReconnecting ||
                callState.connectionState ==
                    VideoCallConnectionState.reconnecting)
              Positioned(
                top: 70,
                left: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB45309).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          callState.counselorStatusMessage ??
                              'Gangguan jaringan. Sedang mencoba menghubungkan ulang...',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFB45309),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          controller.manualIceRestart();
                        },
                        child: Text(
                          'Hubungkan Ulang',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. Top Header Bar (Psychologist info, timer, quality badge)
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        SafeNetworkAvatar(
                          imageUrl: psychologist.avatarUrl,
                          radius: 18,
                          backgroundColor: const Color(0xFF2D3263),
                          iconColor: Colors.white,
                          iconSize: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                psychologist.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              _buildConnectionBadge(callState),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quality preset button
                  GestureDetector(
                    onTap: () =>
                        _showQualityPresetSheet(callState, controller),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tune_rounded,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            callState.qualityPreset ==
                                    VideoQualityPreset.audioOnly
                                ? 'Audio'
                                : (callState.qualityPreset ==
                                        VideoQualityPreset.sd480p
                                    ? '480p'
                                    : '720p'),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Timer Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          _formatTimer(callState.callDurationSeconds),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (callState.isExtended) ...[
                          const SizedBox(width: 6),
                          Container(
                            key: const Key('extended_duration_badge'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${callState.maxDurationSeconds ~/ 60}m',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 5. Draggable PiP (Local Self-View Camera Preview)
            if (!showPermissionGate &&
                callState.qualityPreset != VideoQualityPreset.audioOnly)
              Positioned(
                top: _pipPosition.dy,
                right: _pipPosition.dx,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _pipPosition = Offset(
                        (_pipPosition.dx - details.delta.dx)
                            .clamp(16.0, 200.0),
                        (_pipPosition.dy + details.delta.dy)
                            .clamp(60.0, 400.0),
                      );
                    });
                  },
                  onTap: controller.switchCamera,
                  child: Container(
                    width: 104,
                    height: 148,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E224F),
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
                        if (callState.isCameraOff)
                          Container(
                            color: const Color(0xFF141633),
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
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (controller.peerManager.isInitialized)
                          RTCVideoView(
                            controller.peerManager.localRenderer,
                            mirror: callState.isFrontCamera,
                            objectFit:
                                RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          )
                        else
                          Container(
                            color: const Color(0xFF2D3263),
                            child: const Center(
                              child: Icon(Icons.person,
                                  size: 28, color: Colors.white),
                            ),
                          ),

                        // Switch Camera Hint Icon
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.cameraswitch_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 5.5 In-Call Extension Banner (+30 Menit when <= 5 min remaining)
            if (callState.canShowExtensionBanner)
              Positioned(
                bottom: 108,
                left: 16,
                right: 16,
                child: InCallExtensionBanner(
                  remainingSeconds: callState.remainingSeconds,
                  isChecking: callState.isCheckingExtension,
                  onExtendTap: () => _handleExtendTap(controller),
                  onDismiss: controller.dismissExtensionPrompt,
                ),
              ),

            // 6. Bottom Call Action Controls (Accessible with touch target >= 48x48dp)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141633).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute / Unmute Mic
                    Semantics(
                      label: callState.isMicMuted ? 'Nyalakan Mikrofon' : 'Bisukan Mikrofon',
                      button: true,
                      child: _buildControlButton(
                        icon: callState.isMicMuted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        backgroundColor: callState.isMicMuted
                            ? AppColors.error
                            : const Color(0xFF2D3263),
                        iconColor: Colors.white,
                        onTap: controller.toggleMic,
                      ),
                    ),

                    // Camera On / Off
                    Semantics(
                      label: callState.isCameraOff ? 'Nyalakan Kamera' : 'Matikan Kamera',
                      button: true,
                      child: _buildControlButton(
                        icon: callState.isCameraOff
                            ? Icons.videocam_off_rounded
                            : Icons.videocam_rounded,
                        backgroundColor: callState.isCameraOff
                            ? AppColors.error
                            : const Color(0xFF2D3263),
                        iconColor: Colors.white,
                        onTap: controller.toggleCamera,
                      ),
                    ),

                    // Speakerphone Toggle
                    Semantics(
                      label: callState.isSpeakerOn ? 'Matikan Speaker' : 'Nyalakan Speaker',
                      button: true,
                      child: _buildControlButton(
                        icon: callState.isSpeakerOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_down_rounded,
                        backgroundColor: callState.isSpeakerOn
                            ? AppColors.primary
                            : const Color(0xFF2D3263),
                        iconColor: Colors.white,
                        onTap: controller.toggleSpeaker,
                      ),
                    ),

                    // Notes / Quick Chat Bottom Sheet
                    Semantics(
                      label: 'Buka Catatan Sesi',
                      button: true,
                      child: _buildControlButton(
                        icon: Icons.edit_note_rounded,
                        backgroundColor: const Color(0xFF2D3263),
                        iconColor: Colors.white,
                        onTap: _openNotesSheet,
                      ),
                    ),

                    // End Call Button
                    Semantics(
                      label: 'Akhiri Panggilan Konsultasi',
                      button: true,
                      child: _buildControlButton(
                        icon: Icons.call_end_rounded,
                        backgroundColor: const Color(0xFFDC2626),
                        iconColor: Colors.white,
                        onTap: _handleEndCall,
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
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }

  Widget _buildBackdropAvatar(String avatarUrl) {
    const fallback = ColoredBox(
      color: Color(0xFF1E224F),
      child: Icon(
        Icons.person_rounded,
        size: 100,
        color: Colors.white30,
      ),
    );
    final provider = resolveSafeAvatarImageProvider(avatarUrl);
    if (provider == null) return fallback;
    return Image(
      image: provider,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
