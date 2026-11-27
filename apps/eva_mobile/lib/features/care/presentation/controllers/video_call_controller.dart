import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webrtc_client/webrtc_client.dart';

import '../../../../config/app_config.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/extension_availability_entity.dart';
import '../../domain/entities/video_call_state_entity.dart';
import '../../domain/repositories/video_call_repository.dart';

class VideoCallController extends StateNotifier<VideoCallStateEntity>
    with WidgetsBindingObserver {
  final VideoCallRepository repository;
  final IWebRtcPeerManager _peerManager;
  final IWebRtcSignalingService _signalingService;

  Timer? _callTimer;
  StreamSubscription? _signalingSub;
  StreamSubscription? _peerIceCandidateSub;
  StreamSubscription? _iceStateSub;

  IWebRtcPeerManager get peerManager => _peerManager;
  IWebRtcSignalingService get signalingService => _signalingService;

  VideoCallController({
    required this.repository,
    required ConsultationSessionEntity initialSession,
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
        super(VideoCallStateEntity(
          session: initialSession,
          connectionState: VideoCallConnectionState.connecting,
          roomId: 'room-${initialSession.id}',
          maxDurationSeconds: initialSession.durationMinutes * 60,
          isExtended: initialSession.isExtended,
        )) {
    WidgetsBinding.instance.addObserver(this);
    _initializeCall(initialSession);
  }

  Future<void> _initializeCall(ConsultationSessionEntity session) async {
    // 1. Request camera and microphone permissions (browsers prompt via getUserMedia)
    if (!AppConfig.useMockData && !kIsWeb) {
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
          audio: state.isMicPermissionGranted && !state.isMicMuted,
          video: state.isCameraPermissionGranted &&
              !state.isCameraOff &&
              state.qualityPreset != VideoQualityPreset.audioOnly,
          quality: state.qualityPreset,
        );
      }
    } catch (e) {
      debugPrint('[VideoCallController] startLocalStream error: $e');
      if (kIsWeb) {
        state = state.copyWith(
          isCameraPermissionGranted: false,
          isMicPermissionGranted: false,
        );
      }
    }

    // 4. Join room and fetch session credentials & ICE servers
    try {
      final joinedState = await repository.joinCall(session);
      state = state.copyWith(
        roomId: joinedState.roomId,
        token: joinedState.token,
        iceServers: joinedState.iceServers,
        wsUrl: joinedState.wsUrl,
        isWaitingForCounselor: true,
      );
    } catch (e) {
      debugPrint('[VideoCallController] joinCall error: $e');
    }

    // 5. Create PeerConnection as deterministic Answerer
    await _peerManager.createPeerConnectionInstance(
      iceServers: state.iceServers,
      isOfferer: false,
    );

    // 6. Listen to local ICE candidates to forward to counselor via signaling
    _peerIceCandidateSub =
        _peerManager.onLocalIceCandidateStream.listen((candidate) {
      _signalingService.sendMessage(SignalingMessage.create(
        type: 'ice_candidate',
        senderRole: 'patient',
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
          connectionState: VideoCallConnectionState.connected,
          isWaitingForCounselor: false,
          isCounselorReconnecting: false,
          clearCounselorStatusMessage: true,
        );
        _startCallTimer();
        _peerManager.setSpeakerphoneOn(state.isSpeakerOn);
      } else if (iceState ==
              RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        state = state.copyWith(
          connectionState: VideoCallConnectionState.reconnecting,
          isCounselorReconnecting: true,
          counselorStatusMessage:
              'Koneksi terputus. Mencoba menghubungkan kembali...',
        );
      }
    });

    // 8. Auto ICE restart callback on debounce (> 4s)
    final peer = _peerManager;
    if (peer is WebRtcPeerManager) {
      peer.onIceRestartNeeded = () {
        sendIceRestartRequest();
      };
    }

    // 9. Connect to Signaling Server via WebSocket
    final token = state.token ?? 'mock-token';
    final targetWsUrl = state.wsUrl ??
        '${AppConfig.wsCareBaseUrl}/${state.session.id}?token=$token';
    // Subscribe BEFORE connecting so an immediate `room_ready` is never missed.
    await _signalingSub?.cancel();
    _signalingSub =
        _signalingService.messageStream.listen(_handleSignalingMessage);
    try {
      await _signalingService.connect(targetWsUrl);
    } catch (e) {
      debugPrint('[VideoCallController] Signaling connect error: $e');
    }

    // 10. Enable Wakelock
    if (!AppConfig.useMockData) {
      try {
        await WakelockPlus.enable();
      } catch (_) {}
    }

    // If running in Mock mode, automatically simulate connected state after short delay
    if (AppConfig.useMockData) {
      Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        state = state.copyWith(
          connectionState: VideoCallConnectionState.connected,
          isWaitingForCounselor: false,
        );
        _startCallTimer();
      });
    }
  }

  void _handleSignalingMessage(SignalingMessage message) async {
    switch (message.type) {
      case 'room_ready':
        state = state.copyWith(isWaitingForCounselor: false);
        break;

      case 'offer':
        final sdp = message.payload['sdp']?.toString();
        final type = message.payload['type']?.toString() ?? 'offer';
        if (sdp != null) {
          try {
            await _peerManager.setRemoteDescription(
              RTCSessionDescription(sdp, type),
            );
            final answer = await _peerManager.createAnswer();
            _signalingService.sendMessage(SignalingMessage.create(
              type: 'answer',
              senderRole: 'patient',
              payload: {
                'sdp': answer.sdp,
                'type': answer.type,
              },
            ));
            state = state.copyWith(
              connectionState: VideoCallConnectionState.connected,
              isWaitingForCounselor: false,
              isCounselorReconnecting: false,
              clearCounselorStatusMessage: true,
            );
            _startCallTimer();
          } catch (e) {
            debugPrint('[VideoCallController] Answer creation error: $e');
          }
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

      case 'peer_reconnecting':
        state = state.copyWith(
          connectionState: VideoCallConnectionState.reconnecting,
          isCounselorReconnecting: true,
          counselorStatusMessage:
              'Konselor sedang mengalami gangguan jaringan...',
        );
        break;

      case 'peer_reconnected':
        state = state.copyWith(
          connectionState: VideoCallConnectionState.connected,
          isCounselorReconnecting: false,
          clearCounselorStatusMessage: true,
        );
        break;

      case 'ws_reconnected':
        final iceAfterReconnect = _peerManager.iceConnectionState;
        if (iceAfterReconnect ==
                RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            iceAfterReconnect ==
                RTCIceConnectionState.RTCIceConnectionStateFailed) {
          sendIceRestartRequest();
        }
        break;

      case 'media_state':
        final isRemoteCamOff = message.payload['is_camera_off'] as bool?;
        if (isRemoteCamOff != null) {
          state = state.copyWith(
            counselorStatusMessage:
                isRemoteCamOff ? 'Konselor menonaktifkan kamera' : null,
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
            isExtensionApproved: true,
            maxDurationSeconds: maxMins * 60,
            session: state.session.copyWith(
              durationMinutes: maxMins,
              isExtended: true,
            ),
          );
        } else {
          state = state.copyWith(
            isExtensionApproved: false,
          );
        }
        break;

      case 'session_ended':
        state = state.copyWith(
          connectionState: VideoCallConnectionState.ended,
        );
        break;
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      state = state.copyWith(
        callDurationSeconds: state.callDurationSeconds + 1,
      );
    });
  }

  void toggleMic() {
    final newMicState = !state.isMicMuted;
    state = state.copyWith(isMicMuted: newMicState);
    _peerManager.toggleAudio(!newMicState);
    _signalingService.sendMessage(SignalingMessage.create(
      type: 'media_state',
      senderRole: 'patient',
      payload: {
        'is_mic_muted': newMicState,
        'is_camera_off': state.isCameraOff,
      },
    ));
  }

  void toggleCamera() {
    final newCameraState = !state.isCameraOff;
    state = state.copyWith(isCameraOff: newCameraState);
    _peerManager.toggleVideo(!newCameraState);
    _signalingService.sendMessage(SignalingMessage.create(
      type: 'media_state',
      senderRole: 'patient',
      payload: {
        'is_mic_muted': state.isMicMuted,
        'is_camera_off': newCameraState,
      },
    ));
  }

  Future<ExtensionAvailabilityEntity> checkExtensionAvailability() async {
    state = state.copyWith(isCheckingExtension: true);
    try {
      final availability =
          await repository.checkExtensionAvailability(state.session.id);
      state = state.copyWith(
        isCheckingExtension: false,
        extensionAvailability: availability,
      );
      return availability;
    } catch (e) {
      state = state.copyWith(isCheckingExtension: false);
      rethrow;
    }
  }

  Future<bool> confirmAndExtendSession() async {
    if (state.isExtended || state.session.isExtended || state.isExtending) {
      return false;
    }
    state = state.copyWith(isExtending: true);
    try {
      final updated = await repository.extendSession(state.session.id);
      final newDurationMinutes =
          updated.durationMinutes >= 60 ? updated.durationMinutes : 60;
      state = state.copyWith(
        isExtending: false,
        isExtended: true,
        isExtensionApproved: true,
        isExtensionPromptDismissed: false,
        maxDurationSeconds: newDurationMinutes * 60,
        session: state.session.copyWith(
          durationMinutes: newDurationMinutes,
          isExtended: true,
        ),
      );
      _signalingService.sendMessage(SignalingMessage.create(
        type: 'extension_updated',
        senderRole: 'patient',
        payload: {
          'is_approved': true,
          'max_duration_minutes': newDurationMinutes,
        },
      ));
      return true;
    } catch (_) {
      state = state.copyWith(isExtending: false);
      return false;
    }
  }

  void dismissExtensionPrompt() {
    state = state.copyWith(isExtensionPromptDismissed: true);
  }

  Future<void> switchCamera() async {
    await _peerManager.switchCamera();
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  Future<void> toggleSpeaker() async {
    final newSpeakerState = !state.isSpeakerOn;
    state = state.copyWith(isSpeakerOn: newSpeakerState);
    await _peerManager.setSpeakerphoneOn(newSpeakerState);
  }

  Future<void> setVideoQualityPreset(VideoQualityPreset preset) async {
    state = state.copyWith(qualityPreset: preset);
    await _peerManager.setQualityPreset(preset);
  }

  void sendIceRestartRequest() {
    _signalingService.sendMessage(SignalingMessage.create(
      type: 'ice_restart_needed',
      senderRole: 'patient',
      payload: {'session_id': state.session.id},
    ));
  }

  Future<void> manualIceRestart() async {
    state = state.copyWith(
      connectionState: VideoCallConnectionState.reconnecting,
      counselorStatusMessage: 'Menghubungkan ulang sesi...',
    );
    sendIceRestartRequest();
  }

  Future<void> endCall() async {
    _callTimer?.cancel();
    state = state.copyWith(
      connectionState: VideoCallConnectionState.ended,
    );

    _signalingService.sendMessage(SignalingMessage.create(
      type: 'session_ended',
      senderRole: 'patient',
      payload: {'session_id': state.session.id},
    ));

    await repository.endCall(state.session.id);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _peerManager.toggleVideo(false);
    } else if (state == AppLifecycleState.resumed) {
      if (!this.state.isCameraOff &&
          this.state.qualityPreset != VideoQualityPreset.audioOnly) {
        _peerManager.toggleVideo(true);
      }
    }
  }

  Future<void> _cleanup() async {
    _callTimer?.cancel();
    await _signalingSub?.cancel();
    await _peerIceCandidateSub?.cancel();
    await _iceStateSub?.cancel();

    if (!AppConfig.useMockData) {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }

    await _peerManager.dispose();
    await _signalingService.disconnect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    super.dispose();
  }
}
