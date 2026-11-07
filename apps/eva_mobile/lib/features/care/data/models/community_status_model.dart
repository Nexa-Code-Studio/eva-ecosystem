import '../../domain/entities/community_status_entity.dart';

class CommunityStatusModel extends CommunityStatusEntity {
  const CommunityStatusModel({
    required super.isMember,
    required super.isVipActive,
    super.vipRemainingDays = 0,
    super.joinedAt,
    super.serverName = 'Eva Safe Space ID',
    super.inviteUrl = 'https://discord.gg/evasafespace',
    super.memberCount = 1420,
  });

  factory CommunityStatusModel.fromJson(Map<String, dynamic> json) {
    return CommunityStatusModel(
      isMember: json['is_member'] as bool? ?? false,
      isVipActive: json['is_vip_active'] as bool? ?? false,
      vipRemainingDays: (json['vip_remaining_days'] as num?)?.toInt() ?? 0,
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'] as String)
          : null,
      serverName: json['server_name'] as String? ?? 'Eva Safe Space ID',
      inviteUrl: json['invite_url'] as String? ?? 'https://discord.gg/evasafespace',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1420,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_member': isMember,
      'is_vip_active': isVipActive,
      'vip_remaining_days': vipRemainingDays,
      'joined_at': joinedAt?.toIso8601String(),
      'server_name': serverName,
      'invite_url': inviteUrl,
      'member_count': memberCount,
    };
  }
}
