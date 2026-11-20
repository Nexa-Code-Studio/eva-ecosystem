import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/ice_server_config.dart';
import '../models/video_quality_preset.dart';

abstract class IWebRtcPeerManager {
  RTCVideoRenderer get localRenderer;
  RTCVideoRenderer get remoteRenderer;
  bool get isInitialized;
  RTCIceConnectionState get iceConnectionState;

  Stream<RTCIceConnectionState> get iceConnectionStateStream;
  Stream<RTCIceCandidate> get onLocalIceCandidateStream;
  Stream<MediaStream> get onRemoteStreamStream;

  Future<void> initializeRenderers();
  Future<void> createPeerConnectionInstance({
    required List<IceServerConfig> iceServers,
    bool isOfferer = true,
  });
  Future<MediaStream> startLocalStream({
    bool audio = true,
    bool video = true,
    VideoQualityPreset quality = VideoQualityPreset.hd720p,
  });

  Future<RTCSessionDescription> createOffer({bool iceRestart = false});
  Future<RTCSessionDescription> createAnswer();
  Future<void> setRemoteDescription(RTCSessionDescription description);
  Future<void> addRemoteCandidate(RTCIceCandidate candidate);

  void toggleAudio(bool enabled);
  void toggleVideo(bool enabled);
  Future<void> switchCamera();
  Future<void> setSpeakerphoneOn(bool speakerOn);
  Future<void> setQualityPreset(VideoQualityPreset preset);

  Future<void> restartIce();
  Future<void> dispose();
}

class WebRtcPeerManager implements IWebRtcPeerManager {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  bool _isRemoteDescriptionSet = false;
  bool _isInitialized = false;

  final _iceConnectionStateController = StreamController<RTCIceConnectionState>.broadcast();
  final _onLocalIceCandidateController = StreamController<RTCIceCandidate>.broadcast();
  final _onRemoteStreamController = StreamController<MediaStream>.broadcast();

  RTCIceConnectionState _currentIceState = RTCIceConnectionState.RTCIceConnectionStateNew;

  Timer? _iceFailureDebounceTimer;
  VoidCallback? onIceRestartNeeded;

  @override
  RTCVideoRenderer get localRenderer => _localRenderer;

  @override
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  @override
  bool get isInitialized => _isInitialized;

  @override
  RTCIceConnectionState get iceConnectionState => _currentIceState;

  @override
  Stream<RTCIceConnectionState> get iceConnectionStateStream => _iceConnectionStateController.stream;

  @override
  Stream<RTCIceCandidate> get onLocalIceCandidateStream => _onLocalIceCandidateController.stream;

  @override
  Stream<MediaStream> get onRemoteStreamStream => _onRemoteStreamController.stream;

  @override
  Future<void> initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _isInitialized = true;
  }

  @override
  Future<void> createPeerConnectionInstance({
    required List<IceServerConfig> iceServers,
    bool isOfferer = true,
  }) async {
    final iceServerList = iceServers.map((s) => s.toMap()).toList();

    // Default public STUN fallback if no ICE servers given
    if (iceServerList.isEmpty) {
      iceServerList.add({
        'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302']
      });
    }

    final configuration = {
      'iceServers': iceServerList,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (candidate) {
      _onLocalIceCandidateController.add(candidate);
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
        _onRemoteStreamController.add(_remoteStream!);
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      _currentIceState = state;
      _iceConnectionStateController.add(state);
      _handleIceStateChange(state);
    };
  }

  void _handleIceStateChange(RTCIceConnectionState state) {
    if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
        state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
      // Auto ICE restart debounce > 4s
      _iceFailureDebounceTimer?.cancel();
      _iceFailureDebounceTimer = Timer(const Duration(seconds: 4), () {
        if (_currentIceState == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            _currentIceState == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          debugPrint('[WebRtcPeerManager] ICE failed/disconnected > 4s, triggering restart');
          onIceRestartNeeded?.call();
        }
      });
    } else if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
               state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      _iceFailureDebounceTimer?.cancel();
    }
  }

  @override
  Future<MediaStream> startLocalStream({
    bool audio = true,
    bool video = true,
    VideoQualityPreset quality = VideoQualityPreset.hd720p,
  }) async {
    final mediaConstraints = {
      'audio': audio,
      'video': video
          ? {
              'mandatory': {
                'minWidth': quality.targetWidth.toString(),
                'minHeight': quality.targetHeight.toString(),
                'minFrameRate': '24',
                'maxFrameRate': quality.targetFrameRate.toString(),
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;

    if (_peerConnection != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    return _localStream!;
  }

  @override
  Future<RTCSessionDescription> createOffer({bool iceRestart = false}) async {
    if (_peerConnection == null) {
      throw StateError('PeerConnection not created');
    }

    final constraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      if (iceRestart) 'optional': [{'IceRestart': true}],
    };

    final offer = await _peerConnection!.createOffer(constraints);
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  @override
  Future<RTCSessionDescription> createAnswer() async {
    if (_peerConnection == null) {
      throw StateError('PeerConnection not created');
    }

    final constraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    final answer = await _peerConnection!.createAnswer(constraints);
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (_peerConnection == null) return;
    await _peerConnection!.setRemoteDescription(description);
    _isRemoteDescriptionSet = true;
    await _flushPendingCandidates();
  }

  @override
  Future<void> addRemoteCandidate(RTCIceCandidate candidate) async {
    if (!_isRemoteDescriptionSet || _peerConnection == null) {
      _pendingRemoteCandidates.add(candidate);
      return;
    }
    await _peerConnection!.addCandidate(candidate);
  }

  Future<void> _flushPendingCandidates() async {
    if (_peerConnection == null || !_isRemoteDescriptionSet) return;
    for (final candidate in _pendingRemoteCandidates) {
      await _peerConnection!.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  @override
  void toggleAudio(bool enabled) {
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = enabled;
      }
    }
  }

  @override
  void toggleVideo(bool enabled) {
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = enabled;
      }
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks.first);
      }
    }
  }

  @override
  Future<void> setSpeakerphoneOn(bool speakerOn) async {
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (e) {
      debugPrint('[WebRtcPeerManager] setSpeakerphoneOn failed: $e');
    }
  }

  @override
  Future<void> setQualityPreset(VideoQualityPreset preset) async {
    if (_localStream == null || _peerConnection == null) return;

    if (preset == VideoQualityPreset.audioOnly) {
      toggleVideo(false);
      return;
    }

    toggleVideo(true);

    try {
      final senders = await _peerConnection!.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          final parameters = sender.parameters;
          if (parameters.encodings != null && parameters.encodings!.isNotEmpty) {
            for (var encoding in parameters.encodings!) {
              encoding.maxBitrate = preset.maxBitrateBps;
              encoding.maxFramerate = preset.targetFrameRate;
            }
            await sender.setParameters(parameters);
          }
        }
      }
    } catch (e) {
      debugPrint('[WebRtcPeerManager] setQualityPreset bitrate capping error: $e');
    }
  }

  @override
  Future<void> restartIce() async {
    _pendingRemoteCandidates.clear();
    await createOffer(iceRestart: true);
  }

  @override
  Future<void> dispose() async {
    _iceFailureDebounceTimer?.cancel();
    _isRemoteDescriptionSet = false;
    _pendingRemoteCandidates.clear();

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    if (_remoteStream != null) {
      for (final track in _remoteStream!.getTracks()) {
        await track.stop();
      }
      await _remoteStream!.dispose();
      _remoteStream = null;
    }

    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _peerConnection = null;

    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    _isInitialized = false;

    await _iceConnectionStateController.close();
    await _onLocalIceCandidateController.close();
    await _onRemoteStreamController.close();
  }
}

class MockMediaStream extends MediaStream {
  MockMediaStream(super.id, super.ownerTag);

  @override
  bool? get active => true;

  @override
  Future<void> addTrack(MediaStreamTrack track, {bool addToNative = true}) async {}

  @override
  Future<void> removeTrack(MediaStreamTrack track, {bool removeFromNative = true}) async {}

  @override
  List<MediaStreamTrack> getTracks() => [];

  @override
  List<MediaStreamTrack> getAudioTracks() => [];

  @override
  List<MediaStreamTrack> getVideoTracks() => [];

  @override
  @deprecated
  Future<void> getMediaTracks() async {}

  @override
  Future<MediaStream> clone() async => this;

  @override
  Future<void> dispose() async {}
}

class MockWebRtcPeerManager implements IWebRtcPeerManager {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  final _iceConnectionStateController = StreamController<RTCIceConnectionState>.broadcast();
  final _onLocalIceCandidateController = StreamController<RTCIceCandidate>.broadcast();
  final _onRemoteStreamController = StreamController<MediaStream>.broadcast();

  RTCIceConnectionState _currentState = RTCIceConnectionState.RTCIceConnectionStateConnected;
  bool _initialized = false;

  @override
  RTCVideoRenderer get localRenderer => _localRenderer;

  @override
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  @override
  bool get isInitialized => _initialized;

  @override
  RTCIceConnectionState get iceConnectionState => _currentState;

  @override
  Stream<RTCIceConnectionState> get iceConnectionStateStream => _iceConnectionStateController.stream;

  @override
  Stream<RTCIceCandidate> get onLocalIceCandidateStream => _onLocalIceCandidateController.stream;

  @override
  Stream<MediaStream> get onRemoteStreamStream => _onRemoteStreamController.stream;

  @override
  Future<void> initializeRenderers() async {
    _initialized = true;
  }

  @override
  Future<void> createPeerConnectionInstance({
    required List<IceServerConfig> iceServers,
    bool isOfferer = true,
  }) async {}

  @override
  Future<MediaStream> startLocalStream({
    bool audio = true,
    bool video = true,
    VideoQualityPreset quality = VideoQualityPreset.hd720p,
  }) async {
    return MockMediaStream('mock-stream-id', 'mock-owner');
  }

  @override
  Future<RTCSessionDescription> createOffer({bool iceRestart = false}) async {
    return RTCSessionDescription('v=0\r\no=mock 0 0 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n', 'offer');
  }

  @override
  Future<RTCSessionDescription> createAnswer() async {
    return RTCSessionDescription('v=0\r\no=mock 0 0 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n', 'answer');
  }

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {}

  @override
  Future<void> addRemoteCandidate(RTCIceCandidate candidate) async {}

  @override
  void toggleAudio(bool enabled) {}

  @override
  void toggleVideo(bool enabled) {}

  @override
  Future<void> switchCamera() async {}

  @override
  Future<void> setSpeakerphoneOn(bool speakerOn) async {}

  @override
  Future<void> setQualityPreset(VideoQualityPreset preset) async {}

  @override
  Future<void> restartIce() async {}

  @override
  Future<void> dispose() async {
    _initialized = false;
    await _iceConnectionStateController.close();
    await _onLocalIceCandidateController.close();
    await _onRemoteStreamController.close();
  }
}
