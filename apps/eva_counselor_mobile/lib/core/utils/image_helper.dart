import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider? getProfileImageProvider(String? photoPath) {
  if (photoPath == null || photoPath.trim().isEmpty) return null;
  final path = photoPath.trim();
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  try {
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
  } catch (_) {
    // Graceful fallback for non-file or unsupported platforms
  }
  return null;
}
