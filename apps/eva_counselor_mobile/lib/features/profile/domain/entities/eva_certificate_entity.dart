import 'package:flutter/material.dart';

@immutable
class EvaCertificateEntity {
  final String id;
  final String title;
  final String subtitle;
  final String recipientName;
  final String milestoneCriteria;
  final String certificateNumber;
  final String issueDate;
  final String categoryLabel;
  final String description;
  final Color badgeColor;
  final String status;
  final String? strNumber;
  final String? triggerSource;
  final DateTime? issuedAt;
  final DateTime? revokedAt;
  final String? revocationReason;

  const EvaCertificateEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.recipientName,
    required this.milestoneCriteria,
    required this.certificateNumber,
    required this.issueDate,
    required this.categoryLabel,
    required this.description,
    this.badgeColor = const Color(0xFFD97706),
    this.status = 'active',
    this.strNumber,
    this.triggerSource,
    this.issuedAt,
    this.revokedAt,
    this.revocationReason,
  });

  bool get isActive => status == 'active';
  bool get isRevoked => status == 'revoked';

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFFD97706);
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      } else if (clean.length == 8) {
        return Color(int.parse('0x$clean'));
      }
    } catch (_) {}
    return const Color(0xFFD97706);
  }

  factory EvaCertificateEntity.fromJson(Map<String, dynamic> json) {
    final issuedAtRaw = json['issued_at']?.toString();
    final issuedAt = issuedAtRaw != null ? DateTime.tryParse(issuedAtRaw) : null;
    final revokedAtRaw = json['revoked_at']?.toString();
    final revokedAt = revokedAtRaw != null ? DateTime.tryParse(revokedAtRaw) : null;

    final issueDate = json['issue_date_label']?.toString() ??
        json['issue_date']?.toString() ??
        (issuedAt != null ? '${issuedAt.day} ${_monthName(issuedAt.month)} ${issuedAt.year}' : 'Terbit');

    return EvaCertificateEntity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sertifikat Penghargaan',
      subtitle: json['subtitle']?.toString() ?? 'Penghargaan Resmi Eva AI Platform',
      recipientName: json['recipient_name']?.toString() ?? '',
      milestoneCriteria: json['milestone_criteria']?.toString() ?? '',
      certificateNumber: json['certificate_number']?.toString() ?? '',
      issueDate: issueDate,
      categoryLabel: json['category_label']?.toString() ?? 'Psikolog Mandiri',
      description: json['description']?.toString() ?? '',
      badgeColor: _parseColor(json['badge_color']?.toString()),
      status: json['status']?.toString() ?? 'active',
      strNumber: json['str_number']?.toString(),
      triggerSource: json['trigger_source']?.toString(),
      issuedAt: issuedAt,
      revokedAt: revokedAt,
      revocationReason: json['revocation_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'recipient_name': recipientName,
      'milestone_criteria': milestoneCriteria,
      'certificate_number': certificateNumber,
      'issue_date_label': issueDate,
      'category_label': categoryLabel,
      'description': description,
      'badge_color': '#${badgeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      'status': status,
      'str_number': strNumber,
      'trigger_source': triggerSource,
      'issued_at': issuedAt?.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
      'revocation_reason': revocationReason,
    };
  }

  static String _monthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }
}
