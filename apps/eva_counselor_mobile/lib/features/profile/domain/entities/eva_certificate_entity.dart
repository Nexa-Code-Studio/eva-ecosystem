import 'package:flutter/material.dart';

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
  });
}
