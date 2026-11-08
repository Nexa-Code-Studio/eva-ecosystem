import 'package:flutter/foundation.dart';

@immutable
class CommunityStatusEntity {
  final bool isMember;
  final bool isVipActive;
  final int vipRemainingDays;
  final DateTime? joinedAt;
  final String serverName;
  final String inviteUrl;
  final int memberCount;

  const CommunityStatusEntity({
    required this.isMember,
    required this.isVipActive,
    this.vipRemainingDays = 0,
    this.joinedAt,
    this.serverName = 'Eva Safe Space ID',
    this.inviteUrl = 'https://discord.gg/evasafespace',
    this.memberCount = 1420,
  });

  CommunityStatusEntity copyWith({
    bool? isMember,
    bool? isVipActive,
    int? vipRemainingDays,
    DateTime? joinedAt,
    String? serverName,
    String? inviteUrl,
    int? memberCount,
  }) {
    return CommunityStatusEntity(
      isMember: isMember ?? this.isMember,
      isVipActive: isVipActive ?? this.isVipActive,
      vipRemainingDays: vipRemainingDays ?? this.vipRemainingDays,
      joinedAt: joinedAt ?? this.joinedAt,
      serverName: serverName ?? this.serverName,
      inviteUrl: inviteUrl ?? this.inviteUrl,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}
