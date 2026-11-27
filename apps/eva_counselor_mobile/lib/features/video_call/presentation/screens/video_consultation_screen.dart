import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webrtc_client/webrtc_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../domain/entities/video_call_state_entity.dart';
import '../controllers/video_call_controller.dart';
import '../providers/video_call_provider.dart';

class VideoConsultationScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String? patientName;
  final String? scheduledTime;
  final bool isEarlyEntry;

  const VideoConsultationScreen({
    super.key,
    required this.sessionId,
    this.patientName,
    this.scheduledTime,
    this.isEarlyEntry = false,
  });

  @override
  ConsumerState<VideoConsultationScreen> createState() =>
      _VideoConsultationScreenState();
}

class _VideoConsultationScreenState
    extends ConsumerState<VideoConsultationScreen>
    with WidgetsBindingObserver {
  final _quickNoteCtrl = TextEditingController();
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize controller and WebRTC peer connection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl =
          ref.read(videoCallControllerProvider(widget.sessionId).notifier);
      if (widget.patientName != null && widget.patientName!.isNotEmpty) {
        ctrl.setPatientName(widget.patientName!);
      }
      ctrl.initializeCall();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(videoCallControllerProvider(widget.sessionId).notifier)
        .handleLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quickNoteCtrl.dispose();
    // Matikan kamera, mikrofon, dan koneksi media seketika saat konselor keluar dari ruang VC
    try {
      final session = ref.read(videoCallControllerProvider(widget.sessionId));
      // Only end the session on the backend when a call is actually live.
      // Leaving the waiting room must NOT end the consultation; provider
      // autoDispose releases camera, mic, and signaling on its own.
      final isLiveSession = session.status == VideoCallStatus.connecting ||
          session.status == VideoCallStatus.connected ||
          session.status == VideoCallStatus.reconnecting;
      if (isLiveSession && !_isLeaving) {
        ref.read(videoCallControllerProvider(widget.sessionId).notifier).endCall();
      }
    } catch (_) {}
    super.dispose();
  }

  void _showQuickNotesDrawer(
      BuildContext context, VideoCallSessionEntity session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Catatan Cepat Selama Sesi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: '',
                    hint: 'Tulis observasi afek atau poin penting...',
                    controller: _quickNoteCtrl,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_quickNoteCtrl.text.isNotEmpty) {
                      ref
                          .read(videoCallControllerProvider(widget.sessionId)
                              .notifier)
                          .addQuickNote(_quickNoteCtrl.text);
                      _quickNoteCtrl.clear();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: session.realTimeNotes.isEmpty
                  ? const Text(
                      'Belum ada catatan observasi ditambahkan.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: session.realTimeNotes.length,
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  session.realTimeNotes[idx],
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQualityPresetSelector(
      BuildContext context, VideoCallSessionEntity session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2333),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Kualitas Video Konsultasi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sesuaikan resolusi berdasarkan stabilitas jaringan internet Anda.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ...VideoQualityPreset.values.map((preset) {
                final isSelected = session.qualityPreset == preset;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    preset == VideoQualityPreset.audioOnly
                        ? Icons.volume_up_rounded
                        : (preset == VideoQualityPreset.hd720p
                            ? Icons.hd_rounded
                            : Icons.sd_rounded),
                    color: isSelected ? AppColors.primary : Colors.white70,
                  ),
                  title: Text(
                    preset.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    preset == VideoQualityPreset.audioOnly
                        ? 'Hemat data & baterai (tanpa kamera)'
                        : (preset == VideoQualityPreset.hd720p
                            ? '1280x720 • Jernih & Stabil'
                            : '640x480 • Hemat Kuota'),
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(videoCallControllerProvider(widget.sessionId)
                            .notifier)
                        .setQualityPreset(preset);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(videoCallControllerProvider(widget.sessionId));
    ref.listen<VideoCallSessionEntity>(
      videoCallControllerProvider(widget.sessionId),
      (previous, next) {
        if (_isLeaving) return;
        if (previous?.status != VideoCallStatus.ended &&
            next.status == VideoCallStatus.ended) {
          _isLeaving = true;
          TopToast.show(
            context,
            title: 'Sesi Berakhir',
            message: 'Pasien telah mengakhiri sesi konsultasi.',
            type: ToastType.info,
          );
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
        }
      },
    );
    final controller =
        ref.read(videoCallControllerProvider(widget.sessionId).notifier);
    final isPatientConnected =
        !session.isWaitingForPatient && session.status == VideoCallStatus.connected;
    final totalSeconds = (session.isExtended ? 60 : 30) * 60;
    final remainingSeconds = totalSeconds - session.callDuration.inSeconds;
    final isNearEnd = isPatientConnected && remainingSeconds <= 300 && remainingSeconds > 0;
    final isUrgentEnd = isPatientConnected && remainingSeconds <= 120 && remainingSeconds > 0;

    return PopScope(
      canPop: !isPatientConnected,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isPatientConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sesi konsultasi sedang berlangsung. Silakan gunakan tombol "Akhiri Sesi" untuk menyelesaikan.',
              ),
              backgroundColor: AppColors.highRiskRed,
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF101318),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Patient Video View / Waiting Canvas
            Positioned.fill(
              child: Container(
                color: const Color(0xFF161A24),
                child: Center(
                  child: session.isWaitingForPatient
                      ? _buildWaitingPatientView(session)
                      : _buildPatientVideoView(controller, session),
                ),
              ),
            ),

            // Top & Bottom WCAG AA Gradient Scrim (Contrast >= 4.5:1)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.25, 0.75, 1.0],
                      colors: [
                        Color(0xD9000000),
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xE6000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Picture-in-Picture Counselor Self View (Top Right)
            Positioned(
              top: 20,
              right: 20,
              child: Semantics(
                label: 'Pratinjau Video Konselor',
                child: Container(
                  width: 104,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFF282D3D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        _buildLocalVideo(controller, session),
                        if (session.isMicMuted)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.mic_off,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Top Call Status HUD & Control Bar
            Positioned(
              top: 20,
              left: 20,
              right: 135,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Semantics(
                        button: true,
                        label: 'Kembali ke halaman sebelumnya',
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.15),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.arrow_back, size: 20),
                          onPressed: () {
                            if (isPatientConnected) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sesi konsultasi sedang berlangsung. Silakan gunakan tombol "Akhiri Sesi" untuk menyelesaikan.',
                                  ),
                                  backgroundColor: AppColors.highRiskRed,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: 'Buka catatan cepat observasi klinis',
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.15),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(48, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: Text(
                            'Catatan (${session.realTimeNotes.length})',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () =>
                              _showQuickNotesDrawer(context, session),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Jadwal & Quality Controls
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // JADWAL CHIP
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_available_rounded,
                                size: 12, color: Colors.white70),
                            const SizedBox(width: 5),
                            Text(
                              'Jadwal: ${widget.scheduledTime ?? "14:00 - 14:30 WIB"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // QUALITY SELECTOR PILL
                      Semantics(
                        button: true,
                        label: 'Pilih resolusi kualitas video',
                        child: GestureDetector(
                          onTap: () =>
                              _showQualityPresetSelector(context, session),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2333),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tune_rounded,
                                    size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  session.qualityPreset.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // TIMER / STATUS BADGE (Non-color-only accessible status)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPatientConnected
                          ? (isUrgentEnd
                              ? const Color(0xFFDC2626)
                              : (isNearEnd
                                  ? const Color(0xFFD97706)
                                  : AppColors.verifiedGreen.withValues(alpha: 0.9)))
                          : (session.isPatientReconnecting
                              ? AppColors.pendingAmber.withValues(alpha: 0.9)
                              : const Color(0xFF2563EB)
                                  .withValues(alpha: 0.9)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPatientConnected
                              ? (isNearEnd ? Icons.alarm_rounded : Icons.check_circle_rounded)
                              : (session.isPatientReconnecting
                                  ? Icons.sync_problem_rounded
                                  : Icons.hourglass_top_rounded),
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPatientConnected
                              ? (isNearEnd
                                  ? '⏱️ Sisa ${_formatDuration(Duration(seconds: remainingSeconds))} (${_formatDuration(session.callDuration)}/${session.isExtended ? "60:00" : "30:00"})'
                                  : 'Sesi Aktif: ${_formatDuration(session.callDuration)} / ${session.isExtended ? "60:00" : "30:00"}')
                              : (session.isPatientReconnecting
                                  ? 'Menghubungkan Ulang...'
                                  : 'Menunggu Pasien...'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        if (session.isExtended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '+30m',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
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

            // 4. Permission Gate Notice (Non-blocking fallback)
            if (!session.isCameraPermissionGranted ||
                !session.isMicPermissionGranted)
              Positioned(
                top: 155,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2333),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.pendingAmber.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.pendingAmber, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Izin kamera/mikrofon belum aktif. Gunakan Audio-Only atau izinkan di pengaturan.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: () => openAppSettings(),
                        child: const Text('Pengaturan',
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Reconnection & Auto ICE Restart Banner
            if (session.isPatientReconnecting ||
                session.status == VideoCallStatus.reconnecting)
              Positioned(
                top: 160,
                left: 20,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2016),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.pendingAmber,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.pendingAmber),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          session.patientStatusMessage ??
                              'Pasien sedang menghubungkan ulang...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Hubungkan ulang panggilan WebRTC sekarang',
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pendingAmber,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(48, 36),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => controller.manualIceRestart(),
                          child: const Text(
                            'Hubungkan Ulang',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 6. Bottom Control Bar (Mute, Video, Speaker, Flip, End)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xDD1E2333),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mic Toggle
                    _buildRoundCallButton(
                      semanticLabel: session.isMicMuted
                          ? 'Nyalakan Mikrofon'
                          : 'Matikan Mikrofon',
                      icon: session.isMicMuted ? Icons.mic_off : Icons.mic,
                      isActive: !session.isMicMuted,
                      onTap: () => controller.toggleMic(),
                    ),

                    // Video Camera Toggle
                    _buildRoundCallButton(
                      semanticLabel: session.isVideoDisabled
                          ? 'Nyalakan Kamera'
                          : 'Matikan Kamera',
                      icon: session.isVideoDisabled
                          ? Icons.videocam_off
                          : Icons.videocam,
                      isActive: !session.isVideoDisabled,
                      onTap: () => controller.toggleVideo(),
                    ),

                    // Speakerphone Toggle
                    _buildRoundCallButton(
                      semanticLabel: session.isSpeakerOn
                          ? 'Alihkan ke Earpiece'
                          : 'Alihkan ke Speaker',
                      icon: session.isSpeakerOn
                          ? Icons.volume_up_rounded
                          : Icons.phone_in_talk_rounded,
                      isActive: session.isSpeakerOn,
                      onTap: () => controller.toggleSpeaker(),
                    ),

                    // Flip Camera
                    _buildRoundCallButton(
                      semanticLabel: 'Putar Kamera Depan/Belakang',
                      icon: Icons.flip_camera_ios,
                      isActive: false,
                      onTap: () => controller.flipCamera(),
                    ),

                    // End Call (Red)
                    Semantics(
                      button: true,
                      label: 'Akhiri Panggilan Konsultasi',
                      child: GestureDetector(
                        onTap: () {
                          _isLeaving = true;
                          controller.endCall();
                          Navigator.of(context).pop(true);
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end,
                              color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 7. In-Call 30-Min Extension Request Dialog / Overlay
            if (session.isExtensionRequested)
              Positioned(
                top: 90,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2333),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hourglass_bottom_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Permintaan Tambah Sesi (+30 Mnt)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pasien (${session.patientName}) mengajukan perpanjangan telekonsultasi.',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14, color: Color(0xFF93C5FD)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Jika disetujui, durasi panggilan bertambah menjadi 60 menit tanpa memutus sambungan video.',
                                style: TextStyle(
                                    color: Color(0xFF93C5FD), fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size(48, 44),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () {
                                controller.rejectExtension();
                                TopToast.show(
                                  context,
                                  title: 'Perpanjangan Ditolak',
                                  message:
                                      'Pasien akan diarahkan untuk reservasi sesi berikutnya.',
                                  type: ToastType.info,
                                );
                              },
                              child: const Text(
                                'Tolak',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.verifiedGreen,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(48, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                final success =
                                    await controller.approveExtension();
                                if (success && context.mounted) {
                                  TopToast.show(
                                    context,
                                    title: 'Sesi Diperpanjang! 🎉',
                                    message:
                                        'Konsultasi diperpanjang +30 menit (total 60:00).',
                                    type: ToastType.success,
                                  );
                                }
                              },
                              child: const Text(
                                'Terima (+30 Mnt)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // 8. Warning Banner: Time Is Running Out (<= 5 Mins & <= 2 Mins)
            if (isNearEnd && !session.isExtensionRequested)
              Positioned(
                top: 86,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUrgentEnd
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isUrgentEnd
                            ? Icons.alarm_rounded
                            : Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isUrgentEnd
                                  ? '⏰ Waktu Sesi Tersisa ${_formatDuration(Duration(seconds: remainingSeconds))}!'
                                  : '⚠️ Waktu Sesi Tersisa ${_formatDuration(Duration(seconds: remainingSeconds))}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isUrgentEnd
                                  ? 'Sesi segera berakhir. Mohon bersiap menyelesaikan konsultasi & melengkapi catatan klinis.'
                                  : 'Mulai rangkum evaluasi sesi bersama pasien sebelum sesi berakhir.',
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

  // WAITING ROOM STATE WIDGET
  Widget _buildWaitingPatientView(VideoCallSessionEntity session) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 70),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.pendingAmber,
                      width: 2,
                    ),
                    color: const Color(0xFF1E2333),
                  ),
                  child: Center(
                    child: Text(
                      session.patientName.isNotEmpty
                          ? session.patientName[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Menunggu ${session.patientName} Masuk...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Info Jadwal Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 14, color: Color(0xFF93C5FD)),
                  const SizedBox(width: 6),
                  Text(
                    'Jadwal Sesi: ${widget.scheduledTime ?? "14:00 - 14:30 WIB"}',
                    style: const TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Card Kesiapan Perangkat & Enkripsi
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2C),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 16, color: Color(0xFF93C5FD)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ruang konsultasi aktif dan terenkripsi secara klinis. Durasi konsultasi resmi berjalan tepat setelah pasien bergabung.',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.45),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Colors.white12),

                  // Status Audio & Kamera Psikolog
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          Icon(
                            session.isMicMuted ? Icons.mic_off : Icons.mic,
                            size: 14,
                            color: session.isMicMuted
                                ? AppColors.error
                                : const Color(0xFF4ADE80),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            session.isMicMuted ? 'Mic Mati' : 'Mic Siap',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 14, color: Colors.white24),
                      Row(
                        children: [
                          Icon(
                            session.isVideoDisabled
                                ? Icons.videocam_off
                                : Icons.videocam,
                            size: 14,
                            color: session.isVideoDisabled
                                ? AppColors.error
                                : const Color(0xFF4ADE80),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            session.isVideoDisabled
                                ? 'Kamera Mati'
                                : 'Kamera Siap',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Keluar Standby
            TextButton.icon(
              icon:
                  const Icon(Icons.arrow_back, size: 14, color: Colors.white60),
              label: const Text('Keluar & Kembali Nanti',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // CONNECTED PATIENT VIEW (LIVE STREAM OR FALLBACK)
  Widget _buildPatientVideoView(
      VideoCallController controller, VideoCallSessionEntity session) {
    if (AppConfig.useMockData || !controller.peerManager.isInitialized) {
      return _buildConnectedPatientPlaceholder(session);
    }

    return RTCVideoView(
      controller.peerManager.remoteRenderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  Widget _buildConnectedPatientPlaceholder(VideoCallSessionEntity session) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.verifiedGreen, width: 3),
            color: const Color(0xFF2B3245),
          ),
          child: Center(
            child: Text(
              session.patientName.isNotEmpty
                  ? session.patientName[0].toUpperCase()
                  : 'P',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          session.patientName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined,
                  size: 12, color: AppColors.verifiedGreen),
              SizedBox(width: 6),
              Text(
                'Terenkripsi Klinis End-to-End • WebRTC P2P',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // LOCAL PIP VIDEO VIEW
  Widget _buildLocalVideo(
      VideoCallController controller, VideoCallSessionEntity session) {
    if (session.isVideoDisabled ||
        session.qualityPreset == VideoQualityPreset.audioOnly) {
      return const Center(
        child: Icon(Icons.videocam_off, color: Colors.white54, size: 24),
      );
    }

    if (AppConfig.useMockData || !controller.peerManager.isInitialized) {
      return Container(
        color: const Color(0xFF2B3245),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, color: Colors.white, size: 30),
              SizedBox(height: 4),
              Text('Anda (Psikolog)',
                  style: TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
      );
    }

    return RTCVideoView(
      controller.peerManager.localRenderer,
      mirror: session.isFrontCamera,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  Widget _buildRoundCallButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                isActive ? Colors.white.withValues(alpha: 0.2) : Colors.white10,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.white60,
            size: 22,
          ),
        ),
      ),
    );
  }
}
