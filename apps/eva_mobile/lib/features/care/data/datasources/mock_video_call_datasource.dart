import 'dart:async';
import 'package:webrtc_client/webrtc_client.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../models/consultation_session_model.dart';
import '../models/extension_availability_dto.dart';
import '../models/psychologist_model.dart';
import '../models/video_call_session_dto.dart';
import 'video_call_datasource.dart';

class MockVideoCallDataSource implements VideoCallDataSource {
  @override
  Future<VideoCallSessionDto> joinRoom(String sessionId) async {
    return VideoCallSessionDto(
      sessionId: sessionId,
      roomId: 'eva-room-$sessionId',
      token:
          'mock-webrtc-token-$sessionId-${DateTime.now().millisecondsSinceEpoch}',
      participantId: 'user-patient-eva',
      status: 'active',
      iceServers: const [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
      ],
      iceServerConfigs: const [
        IceServerConfig(urls: [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ]),
      ],
      wsUrl: 'ws://localhost:8888/api/v1/care/ws/$sessionId?token=mock-token',
    );
  }

  @override
  Future<void> leaveRoom(String sessionId) async {}

  @override
  Future<ExtensionAvailabilityDto> checkExtensionAvailability(
      String sessionId) async {
    return ExtensionAvailabilityDto(
      sessionId: sessionId,
      canExtend: true,
      extensionDurationMinutes: 30,
      extensionPrice: 50,
      reason:
          'Slot 30 menit berikutnya tersedia. Sesi dapat diperpanjang tanpa memutus panggilan.',
    );
  }

  @override
  Future<ConsultationSessionModel> extendSession(String sessionId) async {
    return ConsultationSessionModel(
      id: sessionId,
      psychologist: const PsychologistModel(
        id: 'psy_mock',
        name: 'Psikolog Eva',
        title: 'Psikolog Klinis',
        registrationNumber: '',
        avatarUrl: '',
        rating: 5.0,
        reviewCount: 0,
        experienceYears: 1,
        specialties: [],
        bio: '',
        practitionerType: PractitionerType.professional,
      ),
      sessionDateTime: DateTime.now(),
      status: ConsultationStatus.upcoming,
      durationMinutes: 60,
      isExtended: true,
    );
  }
}
