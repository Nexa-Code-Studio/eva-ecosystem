import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../domain/entities/video_call_state_entity.dart';
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
    extends ConsumerState<VideoConsultationScreen> {
  final _quickNoteCtrl = TextEditingController();
  late final VideoCallSessionEntity _initialSession;

  bool _isPatientPresent = false;
  Timer? _simulatedJoinTimer;

  @override
  void initState() {
    super.initState();
    final name = widget.patientName ?? 'Rian Pratama';
    _initialSession = VideoCallSessionEntity(
      sessionId: widget.sessionId,
      patientId: 'patient-001',
      patientName: name,
      scheduledTime: DateTime.now(),
    );

    // Otomatis simulasi pasien masuk setelah 3.5 detik HANYA jika bukan early entry
    if (!widget.isEarlyEntry) {
      _simulatedJoinTimer = Timer(const Duration(milliseconds: 3500), () {
        if (mounted && !_isPatientPresent) {
          _connectPatient();
        }
      });
    }
  }

  void _connectPatient() {
    _simulatedJoinTimer?.cancel();
    setState(() => _isPatientPresent = true);
    ref.read(videoCallControllerProvider(_initialSession).notifier).startCall();
    TopToast.show(
      context,
      title: 'Pasien Telah Bergabung',
      message: '${_initialSession.patientName} telah terhubung. Penghitung waktu sesi 30 menit resmi dimulai.',
      type: ToastType.success,
    );
  }

  @override
  void dispose() {
    _simulatedJoinTimer?.cancel();
    super.dispose();
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
                  ? const Text('Belum ada catatan observasi ditambahkan.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
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
                                  session.realTimeNotes[idx] as String,
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
            // 1. Patient Video View / Waiting Canvas
            Positioned.fill(
              child: Container(
                color: const Color(0xFF161A24),
                child: Center(
                  child: !_isPatientPresent
                      ? _buildWaitingPatientView(session)
                      : _buildConnectedPatientView(session),
                ),
              ),
            ),

            // 2. Picture-in-Picture Counselor Self View (Top Right)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 100,
                height: 135,
                decoration: BoxDecoration(
                  color: const Color(0xFF282D3D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Container(
                        color: const Color(0xFF2B3245),
                        child: Center(
                          child: session.isVideoDisabled
                              ? const Icon(Icons.videocam_off, color: Colors.white54, size: 24)
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person, color: Colors.white, size: 30),
                                    SizedBox(height: 4),
                                    Text('Anda (Psikolog)', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                        ),
                      ),
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
                            child: const Icon(Icons.mic_off, color: Colors.white, size: 10),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Top Call Status HUD & Timer Bar
            Positioned(
              top: 20,
              left: 20,
              right: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text('Catatan (${session.realTimeNotes.length})', style: const TextStyle(fontSize: 12)),
                        onPressed: () => _showQuickNotesDrawer(context, session),
                      ),
                    ],
                  ),
                  if (_isPatientPresent && !session.isExtended && session.isExtensionApproved == null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      key: const Key('simulate_extension_btn'),
                      onTap: () {
                        ref
                            .read(videoCallControllerProvider(_initialSession).notifier)
                            .triggerExtensionRequest();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_bottom_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              'Simulasi Mnt-25 (Minta Tambah +30m)',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // JADWAL VC CHIP
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_available_rounded, size: 12, color: Colors.white70),
                        const SizedBox(width: 5),
                        Text(
                          'Jadwal Sesi: ${widget.scheduledTime ?? "14:00 - 14:30 WIB"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // TIMER / STATUS BADGE (STANDBY vs MENUNGGU vs AKTIF)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isPatientPresent
                          ? AppColors.verifiedGreen.withValues(alpha: 0.85)
                          : (widget.isEarlyEntry
                              ? const Color(0xFF2563EB).withValues(alpha: 0.85)
                              : AppColors.pendingAmber.withValues(alpha: 0.85)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isPatientPresent
                              ? 'Sesi Aktif: ${_formatDuration(session.callDuration)} / ${session.isExtended ? "60:00" : "30:00"}'
                              : (widget.isEarlyEntry
                                  ? 'Standby Lebih Awal • Menunggu Jam Jadwal'
                                  : 'Menunggu Pasien Masuk...'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        if (session.isExtended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                        Navigator.of(context).pop(true);
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

            // 5. In-Call 30-Min Extension Request Dialog / Overlay
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
                            Icon(Icons.info_outline, size: 14, color: Color(0xFF93C5FD)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Jika disetujui, durasi panggilan bertambah menjadi 60 menit tanpa memutus sambungan video.',
                                style: TextStyle(color: Color(0xFF93C5FD), fontSize: 10),
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
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () {
                                ref
                                    .read(videoCallControllerProvider(_initialSession).notifier)
                                    .rejectExtension();
                                TopToast.show(
                                  context,
                                  title: 'Perpanjangan Ditolak',
                                  message: 'Pasien akan diarahkan untuk reservasi sesi berikutnya.',
                                  type: ToastType.info,
                                );
                              },
                              child: const Text(
                                'Tolak',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.verifiedGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                final success = await ref
                                    .read(videoCallControllerProvider(_initialSession).notifier)
                                    .approveExtension();
                                if (success && context.mounted) {
                                  TopToast.show(
                                    context,
                                    title: 'Sesi Diperpanjang! 🎉',
                                    message: 'Konsultasi diperpanjang +30 menit (total 60:00).',
                                    type: ToastType.success,
                                  );
                                }
                              },
                              child: const Text(
                                'Terima (+30 Mnt)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
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

  // WAITING / STANDBY STATE WIDGET (BELUM HADIR)
  Widget _buildWaitingPatientView(VideoCallSessionEntity session) {
    final isEarly = widget.isEarlyEntry;

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
                    color: (isEarly ? const Color(0xFF2563EB) : AppColors.primary).withValues(alpha: 0.15),
                  ),
                ),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isEarly ? const Color(0xFF60A5FA) : AppColors.pendingAmber,
                      width: 2,
                    ),
                    color: const Color(0xFF1E2333),
                  ),
                  child: Center(
                    child: isEarly
                        ? const Icon(Icons.hourglass_top_rounded, size: 36, color: Color(0xFF93C5FD))
                        : Text(
                            session.patientName.substring(0, 1),
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isEarly
                  ? 'Ruang Standby Pra-Konseling'
                  : 'Menunggu ${session.patientName} Hadir...',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                  const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF93C5FD)),
                  const SizedBox(width: 6),
                  Text(
                    'Jadwal Sesi: ${widget.scheduledTime ?? "14:00 - 14:50 WIB"}',
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

            // Card Penjelasan & Cek Perangkat
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2C),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF93C5FD)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEarly
                              ? 'Anda masuk lebih awal dari jam jadwal. Ruang sesi sudah aktif & terenkripsi. Durasi 50 menit baru akan berjalan saat pasien resmi masuk pada jam jadwal.'
                              : 'Ruang telekonsultasi aktif. Penghitung durasi 50 menit akan berjalan otomatis saat pasien masuk ke dalam panggilan.',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.45),
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
                            color: session.isMicMuted ? AppColors.error : const Color(0xFF4ADE80),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            session.isMicMuted ? 'Mic Mati' : 'Mic Aktif',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 14, color: Colors.white24),
                      Row(
                        children: [
                          Icon(
                            session.isVideoDisabled ? Icons.videocam_off : Icons.videocam,
                            size: 14,
                            color: session.isVideoDisabled ? AppColors.error : const Color(0xFF4ADE80),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            session.isVideoDisabled ? 'Kamera Mati' : 'Kamera Aktif',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Simulasi Masuk Pasien
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: Text(
                isEarly ? 'Simulasikan Pasien Hadir Lebih Awal' : 'Simulasikan Pasien Masuk',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: _connectPatient,
            ),
            const SizedBox(height: 10),

            // Tombol Keluar Standby
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 14, color: Colors.white60),
              label: const Text('Keluar & Kembali Nanti', style: TextStyle(color: Colors.white60, fontSize: 12)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // CONNECTED STATE WIDGET (SUDAH HADIR)
  Widget _buildConnectedPatientView(VideoCallSessionEntity session) {
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
          child: ClipOval(
            child: Image.network(
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  session.patientName.isNotEmpty ? session.patientName[0] : 'P',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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
              Icon(Icons.shield_outlined, size: 12, color: AppColors.verifiedGreen),
              SizedBox(width: 6),
              Text(
                'Terenkripsi Klinis End-to-End',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
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
          color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.white10,
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
