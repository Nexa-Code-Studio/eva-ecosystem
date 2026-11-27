import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Audio focus / playback events forwarded to [BreathingController].
enum BreathingAudioEventType {
  ready,
  buffering,
  playing,
  paused,
  completed,
  interrupted,
  error,
}

class BreathingAudioEvent {
  final BreathingAudioEventType type;
  final String? message;

  const BreathingAudioEvent(this.type, {this.message});
}

/// Minimal audio player contract isolating breathing orchestration from [AudioPlayer].
abstract class BreathingAudioAdapter {
  Stream<int> get positionMsStream;
  Stream<BreathingAudioEvent> get eventStream;

  /// Prepares an asset and returns its decoded duration in milliseconds if known.
  Future<int?> prepareAsset(String assetPath);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setMuted(bool muted);
  Future<void> dispose();
}

/// Concrete [BreathingAudioAdapter] powered by EVA Mobile's existing `audioplayers` package.
class AudioplayersBreathingAdapter implements BreathingAudioAdapter {
  AudioPlayer? _player;
  final StreamController<int> _positionController =
      StreamController<int>.broadcast();
  final StreamController<BreathingAudioEvent> _eventController =
      StreamController<BreathingAudioEvent>.broadcast();

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;
  bool _disposed = false;

  AudioplayersBreathingAdapter({AudioPlayer? player}) : _player = player {
    if (_player != null) {
      _attachPlayerListeners(_player!);
    }
  }

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final created = AudioPlayer();
    _player = created;
    _attachPlayerListeners(created);
    return created;
  }

  void _attachPlayerListeners(AudioPlayer player) {
    _positionSub = player.onPositionChanged.listen((duration) {
      if (!_disposed) {
        _positionController.add(duration.inMilliseconds);
      }
    });

    _stateSub = player.onPlayerStateChanged.listen((playerState) {
      if (_disposed) return;
      switch (playerState) {
        case PlayerState.playing:
          _eventController.add(
            const BreathingAudioEvent(BreathingAudioEventType.playing),
          );
          break;
        case PlayerState.paused:
          _eventController.add(
            const BreathingAudioEvent(BreathingAudioEventType.paused),
          );
          break;
        case PlayerState.stopped:
        case PlayerState.completed:
        case PlayerState.disposed:
          break;
      }
    });

    _completeSub = player.onPlayerComplete.listen((_) {
      if (!_disposed) {
        _eventController.add(
          const BreathingAudioEvent(BreathingAudioEventType.completed),
        );
      }
    });
  }

  @override
  Stream<int> get positionMsStream => _positionController.stream;

  @override
  Stream<BreathingAudioEvent> get eventStream => _eventController.stream;

  @override
  Future<int?> prepareAsset(String assetPath) async {
    final player = _ensurePlayer();
    await _configureAudioFocus(player);
    final cleanPath = assetPath.startsWith('assets/')
        ? assetPath.substring('assets/'.length)
        : assetPath;
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSourceAsset(cleanPath);
    final duration = await player.getDuration();
    if (!_disposed) {
      _eventController.add(
        const BreathingAudioEvent(BreathingAudioEventType.ready),
      );
    }
    return duration?.inMilliseconds;
  }

  Future<void> _configureAudioFocus(AudioPlayer player) async {
    try {
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (_) {
      // Allow platform defaults in headless test environments.
    }
  }

  @override
  Future<void> play() async {
    final player = _player;
    if (_disposed || player == null) return;
    await player.resume();
  }

  @override
  Future<void> pause() async {
    final player = _player;
    if (_disposed || player == null) return;
    await player.pause();
  }

  @override
  Future<void> stop() async {
    final player = _player;
    if (_disposed || player == null) return;
    try {
      await player.stop();
    } catch (_) {}
  }

  @override
  Future<void> setMuted(bool muted) async {
    final player = _player;
    if (_disposed || player == null) return;
    await player.setVolume(muted ? 0.0 : 1.0);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _positionSub?.cancel();
    await _stateSub?.cancel();
    await _completeSub?.cancel();
    final player = _player;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
    await _positionController.close();
    await _eventController.close();
  }
}
