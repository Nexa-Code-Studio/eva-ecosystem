import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webrtc_client/webrtc_client.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/video_call_state_entity.dart';
import '../../domain/repositories/video_call_repository.dart';

class VideoCallController extends StateNotifier<VideoCallSessionEntity> {
  final IVideoCallRepository _repository;
  final IWebRtcPeerManager _peerManager;
  final IWebRtcSignalingService _signalingService;

  Timer? _durationTimer;
  StreamSubscription? _signalingSub;
  StreamSubscription? _peerIceCandidateSub;
  StreamSubscription? _iceStateSub;

  IWebRtcPeerManager get peerManager => _peerManager;
  IWebRtcSignalingService get signalingService => _signalingService;

  VideoCallController(
    this._repository,
    VideoCallSessionEntity initial, {
    IWebRtcPeerManager? peerManager,
    IWebRtcSignalingService? signalingService,
  })  : _peerManager = peerManager ??
            (AppConfig.useMockData
                ? MockWebRtcPeerManager()
                : WebRtcPeerManager()),
        _signalingService = signalingService ??
            (AppConfig.useMockData
                ? MockSignalingService()
                : WebRtcSignalingService()),
        super(initial);

  Future<void> initializeCall() async {
    // 1. Request OS camera and microphone permissions
    if (!AppConfig.useMockData) {
      try {
        final camStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        state = state.copyWith(
          isCameraPermissionGranted: camStatus.isGranted,
          isMicPermissionGranted: micStatus.isGranted,
        );
      } catch (e) {
        debugPrint('[VideoCallController] Permission request error: $e');
      }
    }

    // 2. Initialize video renderers
    await _peerManager.initializeRenderers();

    // 3. Start local media stream with initial quality preset
    try {
      if (state.isCameraPermissionGranted || state.isMicPermissionGranted) {
        await _peerManager.startLocalStream(
          audio: state.isMicPermissionGranted,
          video: state.isCameraPermissionGranted && !state.isVideoDisabled,
          quality: state.qualityPreset,
        );
      }
    } catch (e) {
      debugPrint('[VideoCallController] startLocalStream error: $e');
    }

    // 4. Fetch session credentials & ICE servers
    try {
      final sessionDetail = await _repository.getSessionDetails(state.sessionId);
      state = state.copyWith(
        patientName: sessionDetail.patientName.isNotEmpty
            ? sessionDetail.patientName
            : state.patientName,
        signalingToken: sessionDetail.signalingToken,
        channelName: sessionDetail.channelName,
        wsUrl: sessionDetail.wsUrl,
        iceServers: sessionDetail.iceServers,
        status: VideoCallStatus.waiting,
        isWaitingForPatient: true,
      );
    } catch (e) {
      debugPrint('[VideoCallController] getSessionDetails fallback: $e');
    }

    // 5. Create PeerConnection
    await _peerManager.createPeerConnectionInstance(
      iceServers: state.iceServers,
      isOfferer: true,
    );

    // 6. Listen to local ICE candidates to forward to signaling
    _peerIceCandidateSub =
        _peerManager.onLocalIceCandidateStream.listen((candidate) {
      _signalingService.sendMessage(SignalingMessage.create(
        type: 'ice_candidate',
        senderRole: 'counselor',
        payload: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      ));
    });

    // 7. Monitor ICE state transitions
    _iceStateSub = _peerManager.iceConnectionStateStream.listen((iceState) {
      if (iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        state = state.copyWith(
          status: VideoCallStatus.connected,
          isWaitingForPatient: false,
          isPatientReconnecting: false,
          clearPatientStatusMessage: true,
        );
        _startDurationTimer();
      } else if (iceState ==
              RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        state = state.copyWith(
          status: VideoCallStatus.reconnecting,
          isPatientReconnecting: true,
          patientStatusMessage: 'Koneksi terputus. Mencoba menghubungkan kembali...',
        );
      }
    });

    // 8. Auto ICE restart callback on debounce (> 4s)
    final peer = _peerManager;
    if (peer is WebRtcPeerManager) {
      peer.onIceRestartNeeded = () {
        restartIce();
      };
    }

    // 9. Connect to Signaling Server via WebSocket
    final token = state.signalingToken ?? 'mock-token';
    final targetWsUrl = state.wsUrl ??
        '${AppConfig.wsCareBaseUrl}/${state.sessionId}?token=$token';
    try {
      await _signalingService.connect(targetWsUrl);
      _signalingSub =
          _signalingService.messageStream.listen(_handleSignalingMessage);
    } catch (e) {
      debugPrint('[VideoCallController] Signaling connect error: $e');
    }

    // 10. Enable Wakelock
    if (!AppConfig.useMockData) {
      try {
        await WakelockPlus.enable();
      } catch (_) {}
    }
  }

  void _handleSignalingMessage(SignalingMessage message) async {
    switch (message.type) {
      case 'room_ready':
        // As Deterministic Offerer, counselor initiates SDP Offer
        state = state.copyWith(
          isWaitingForPatient: false,
          status: VideoCallStatus.connecting,
        );
        try {
          final offer = await _peerManager.createOffer();
          _signalingService.sendMessage(SignalingMessage.create(
            type: 'offer',
            senderRole: 'counselor',
            payload: {
              'sdp': offer.sdp,
              'type': offer.type,
            },
          ));
        } catch (e) {
          debugPrint('[VideoCallController] createOffer error: $e');
        }
        break;

      case 'answer':
        final sdp = message.payload['sdp']?.toString();
        final type = message.payload['type']?.toString() ?? 'answer';
        if (sdp != null) {
          await _peerManager.setRemoteDescription(
            RTCSessionDescription(sdp, type),
          );
          state = state.copyWith(
            status: VideoCallStatus.connected,
            isWaitingForPatient: false,
            isPatientReconnecting: false,
            clearPatientStatusMessage: true,
          );
          _startDurationTimer();
        }
        break;

      case 'ice_candidate':
        final candidate = message.payload['candidate']?.toString();
        final sdpMid = message.payload['sdpMid']?.toString();
        final sdpMLineIndex = message.payload['sdpMLineIndex'] as int? ?? 0;
        if (candidate != null) {
          await _peerManager.addRemoteCandidate(
            RTCIceCandidate(candidate, sdpMid, sdpMLineIndex),
          );
        }
        break;

      case 'ice_restart_needed':
      case 'peer_reconnecting':
        state = state.copyWith(
          isPatientReconnecting: true,
          patientStatusMessage: 'Pasien sedang menghubungkan ulang...',
        );
        break;

      case 'peer_reconnected':
        state = state.copyWith(
          isPatientReconnecting: false,
          clearPatientStatusMessage: true,
        );
        break;

      case 'chat_message':
        final sender = message.payload['sender_name']?.toString() ?? 'Pasien';
        final text = message.payload['text']?.toString() ?? '';
        if (text.isNotEmpty) {
          state = state.copyWith(
            liveChatMessages: List<String>.from(state.liveChatMessages)
              ..add('$sender: $text'),
          );
        }
        break;

      case 'extension_updated':
        final isApproved = message.payload['is_approved'] as bool? ?? false;
        final maxMins =
            (message.payload['max_duration_minutes'] as num?)?.toInt() ??
                (isApproved ? 60 : 30);
        if (isApproved) {
          state = state.copyWith(
            isExtended: true,
            isExtensionRequested: false,
            isExtensionApproved: true,
            maxDuration: Duration(minutes: maxMins),
          );
        } else {
          state = state.copyWith(
            isExtensionRequested: false,
            isExtensionApproved: false,
          );
        }
        break;

      case 'session_ended':
        endCall();
        break;
    }
  }

  void _startDurationTimer() {
    if (_durationTimer != null && _durationTimer!.isActive) return;

    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nextSeconds = state.callDuration.inSeconds + 1;
      final nextDuration = Duration(seconds: nextSeconds);

      // Auto-trigger in-call extension prompt at minute 25 (1500 seconds)
      bool promptExtension = state.isExtensionRequested;
      if (nextDuration.inMinutes >= 25 &&
          !state.isExtended &&
          state.isExtensionApproved == null &&
          !promptExtension) {
        promptExtension = true;
      }

      state = state.copyWith(
        callDuration: nextDuration,
        isExtensionRequested: promptExtension,
      );
    });
  }

  void setPatientName(String name) {
    if (name.isNotEmpty) {
      state = state.copyWith(patientName: name);
    }
  }

  void startCall() async {
    state = state.copyWith(status: VideoCallStatus.connecting);
    await _repository.startSession(state.sessionId);
    state = state.copyWith(
      status: VideoCallStatus.connected,
      isWaitingForPatient: false,
    );
    _startDurationTimer();
  }

  Future<void> restartIce() async {
    state = state.copyWith(
      status: VideoCallStatus.reconnecting,
      isPatientReconnecting: true,
      patientStatusMessage: 'Menghubungkan ulang sesi WebRTC...',
    );
    try {
      final reOffer = await _peerManager.createOffer(iceRestart: true);
      _signalingService.sendMessage(SignalingMessage.create(
        type: 'offer',
        senderRole: 'counselor',
        payload: {
          'sdp': reOffer.sdp,
          'type': reOffer.type,
          'ice_restart': true,
        },
      ));
    } catch (e) {
      debugPrint('[VideoCallController] restartIce error: $e');
    }
  }

  Future<void> manualIceRestart() async {
    await restartIce();
  }

  Future<void> setQualityPreset(VideoQualityPreset preset) async {
    await _peerManager.setQualityPreset(preset);
    state = state.copyWith(qualityPreset: preset);
  }

  Future<void> toggleSpeaker() async {
    final nextState = !state.isSpeakerOn;
    await _peerManager.setSpeakerphoneOn(nextState);
    state = state.copyWith(isSpeakerOn: nextState);
  }

  void toggleMic() {
    final nextState = !state.isMicMuted;
    _peerManager.toggleAudio(!nextState);
    state = state.copyWith(isMicMuted: nextState);
  }

  void toggleVideo() {
    final nextState = !state.isVideoDisabled;
    _peerManager.toggleVideo(!nextState);
    state = state.copyWith(isVideoDisabled: nextState);
  }

  Future<void> flipCamera() async {
    await _peerManager.switchCamera();
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  void handleLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused) {
      // Background: Disable video track gracefully
      _peerManager.toggleVideo(false);
    } else if (lifecycleState == AppLifecycleState.resumed) {
      // Foreground: Restore video track if not manually muted
      if (!state.isVideoDisabled &&
          state.qualityPreset != VideoQualityPreset.audioOnly) {
        _peerManager.toggleVideo(true);
      }
    }
  }

  void triggerExtensionRequest() {
    if (!state.isExtended && state.isExtensionApproved == null) {
      state = state.copyWith(isExtensionRequested: true);
    }
  }

  Future<bool> approveExtension() async {
    final success = await _repository.extendSession(state.sessionId);
    if (success) {
      state = state.copyWith(
        isExtended: true,
        isExtensionRequested: false,
        maxDuration: const Duration(minutes: 60),
        isExtensionApproved: true,
      );

      _signalingService.sendMessage(SignalingMessage.create(
        type: 'extension_updated',
        senderRole: 'counselor',
        payload: {
          'is_approved': true,
          'max_duration_minutes': 60,
        },
      ));
    }
    return success;
  }

  Future<void> rejectExtension() async {
    await _repository.rejectExtension(state.sessionId);
    state = state.copyWith(
      isExtensionRequested: false,
      isExtensionApproved: false,
    );

    _signalingService.sendMessage(SignalingMessage.create(
      type: 'extension_updated',
      senderRole: 'counselor',
      payload: {
        'is_approved': false,
        'max_duration_minutes': 30,
      },
    ));
  }

  void dismissExtensionPrompt() {
    state = state.copyWith(isExtensionRequested: false);
  }

  void addQuickNote(String note) {
    if (note.trim().isEmpty) return;
    final updated = List<String>.from(state.realTimeNotes)..add(note.trim());
    state = state.copyWith(realTimeNotes: updated);
  }

  void sendChatMessage(String text) {
    if (text.trim().isEmpty) return;
    final updated = List<String>.from(state.liveChatMessages)
      ..add('Konselor: ${text.trim()}');
    state = state.copyWith(liveChatMessages: updated);

    _signalingService.sendMessage(SignalingMessage.create(
      type: 'chat_message',
      senderRole: 'counselor',
      payload: {
        'sender_name': 'Konselor',
        'text': text.trim(),
      },
    ));
  }

  void endCall() async {
    _durationTimer?.cancel();
    state = state.copyWith(status: VideoCallStatus.ended);

    _signalingService.sendMessage(SignalingMessage.create(
      type: 'session_ended',
      senderRole: 'counselor',
      payload: {
        'duration_seconds': state.callDuration.inSeconds,
      },
    ));

    if (!AppConfig.useMockData) {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }

    await _repository.endSession(
      state.sessionId,
      state.callDuration,
      state.realTimeNotes,
    );

    await _peerManager.dispose();
    await _signalingService.disconnect();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _signalingSub?.cancel();
    _peerIceCandidateSub?.cancel();
    _iceStateSub?.cancel();
    _peerManager.dispose();
    _signalingService.dispose();
    if (!AppConfig.useMockData) {
      try {
        WakelockPlus.disable();
      } catch (_) {}
    }
    super.dispose();
  }
}
