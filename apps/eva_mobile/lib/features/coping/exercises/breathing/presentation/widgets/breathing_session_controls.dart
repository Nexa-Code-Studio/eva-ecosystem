import 'package:flutter/material.dart';

/// Minimal top bar controls for exit, pause/resume, and mute without clutter.
class BreathingSessionControls extends StatelessWidget {
  final bool isPlaying;
  final bool isPaused;
  final bool isAudioGuided;
  final bool isMuted;
  final bool isLoadingOrError;
  final VoidCallback onExit;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleMute;

  static const Color _iconColor = Color(0xFFF4EFFF);
  static const Color _pillBg = Color(0x2EFFFFFF);
  static const Color _pillBorder = Color(0x3DFFFFFF);

  const BreathingSessionControls({
    super.key,
    required this.isPlaying,
    required this.isPaused,
    required this.isAudioGuided,
    required this.isMuted,
    required this.isLoadingOrError,
    required this.onExit,
    required this.onTogglePlayPause,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          _ControlIconButton(
            key: const Key('breathing_exit_button'),
            tooltip: 'Keluar dari latihan napas',
            icon: Icons.chevron_left_rounded,
            iconSize: 28,
            onPressed: onExit,
          ),
          const Spacer(),
          if (isAudioGuided && !isLoadingOrError) ...[
            _ControlIconButton(
              key: const Key('breathing_mute_button'),
              tooltip: isMuted
                  ? 'Nyalakan suara narasi'
                  : 'Bisukan suara narasi',
              icon: isMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              iconSize: 20,
              onPressed: onToggleMute,
            ),
            const SizedBox(width: 10),
          ],
          if (!isLoadingOrError)
            _ControlIconButton(
              key: const Key('breathing_play_pause_button'),
              tooltip: isPaused ? 'Lanjutkan latihan' : 'Jeda latihan',
              icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              iconSize: 22,
              onPressed: onTogglePlayPause,
            )
          else
            const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final VoidCallback onPressed;

  const _ControlIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.iconSize,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BreathingSessionControls._pillBg,
                border: Border.all(
                  color: BreathingSessionControls._pillBorder,
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: BreathingSessionControls._iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
