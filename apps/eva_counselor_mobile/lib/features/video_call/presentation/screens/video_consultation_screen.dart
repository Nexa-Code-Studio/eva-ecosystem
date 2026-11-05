import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../domain/entities/video_call_state_entity.dart';
import '../providers/video_call_provider.dart';

class VideoConsultationScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const VideoConsultationScreen({super.key, required this.sessionId});

  @override
  ConsumerState<VideoConsultationScreen> createState() =>
      _VideoConsultationScreenState();
}

class _VideoConsultationScreenState
    extends ConsumerState<VideoConsultationScreen> {
  final _quickNoteCtrl = TextEditingController();

  late final VideoCallSessionEntity _initialSession;

  @override
  void initState() {
    super.initState();
    _initialSession = VideoCallSessionEntity(
      sessionId: widget.sessionId,
      patientId: 'patient-001',
      patientName: 'Rian Pratama',
      scheduledTime: DateTime.now(),
    );

    // Auto start call on entering screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(videoCallControllerProvider(_initialSession).notifier)
          .startCall();
    });
  }

  void _showQuickNotesDrawer(BuildContext context, dynamic session) {
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
                Text(
                  'Catatan Singkat Selama Sesi',
                  style: AppTypography.headingSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
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
                    hint: 'Tulis observasi penting...',
                    controller: _quickNoteCtrl,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_quickNoteCtrl.text.isNotEmpty) {
                      ref
                          .read(videoCallControllerProvider(_initialSession).notifier)
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
                  ? const Text('Belum ada catatan observasi ditambahkan.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: session.realTimeNotes.length,
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(session.realTimeNotes[idx])),
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(videoCallControllerProvider(_initialSession));

    return Scaffold(
      backgroundColor: const Color(0xFF101318),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Patient Video View (Full Canvas)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF1A1F2C),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryLight, width: 3),
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                        child: Center(
                          child: Text(
                            session.patientName.substring(0, 1),
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
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
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDuration(session.callDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
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

            // 2. Picture-in-Picture (PiP) Psychologist Camera View
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 110,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3246),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: session.isVideoDisabled
                      ? const Icon(Icons.videocam_off, color: Colors.white54, size: 28)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.face_retouching_natural,
                                color: AppColors.primaryLight, size: 36),
                            SizedBox(height: 4),
                            Text(
                              'Anda (Psikolog)',
                              style: TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            // 3. Top Call Status & Quick Notes Button
            Positioned(
              top: 20,
              left: 20,
              child: Row(
                children: [
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: Text('Catatan (${session.realTimeNotes.length})'),
                    onPressed: () => _showQuickNotesDrawer(context, session),
                  ),
                ],
              ),
            ),

            // 4. Bottom Control Bar (Mute, Camera, Flip, End)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xDD1E2333),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mic Toggle
                    _buildRoundCallButton(
                      icon: session.isMicMuted ? Icons.mic_off : Icons.mic,
                      isActive: !session.isMicMuted,
                      onTap: () {
                        ref
                            .read(videoCallControllerProvider(_initialSession).notifier)
                            .toggleMic();
                      },
                    ),

                    // Video Camera Toggle
                    _buildRoundCallButton(
                      icon: session.isVideoDisabled
                          ? Icons.videocam_off
                          : Icons.videocam,
                      isActive: !session.isVideoDisabled,
                      onTap: () {
                        ref
                            .read(videoCallControllerProvider(_initialSession).notifier)
                            .toggleVideo();
                      },
                    ),

                    // Flip Camera
                    _buildRoundCallButton(
                      icon: Icons.flip_camera_ios,
                      isActive: false,
                      onTap: () {
                        ref
                            .read(videoCallControllerProvider(_initialSession).notifier)
                            .flipCamera();
                      },
                    ),

                    // End Call (Red)
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(videoCallControllerProvider(_initialSession).notifier)
                            .endCall();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 26),
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

  Widget _buildRoundCallButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white60,
          size: 22,
        ),
      ),
    );
  }
}
