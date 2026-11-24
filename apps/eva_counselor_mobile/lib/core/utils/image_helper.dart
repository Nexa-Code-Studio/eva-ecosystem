import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

ImageProvider? getProfileImageProvider(String? photoPath) {
  if (photoPath == null || photoPath.trim().isEmpty) return null;
  final path = photoPath.trim();
  if (path.startsWith('data:image/')) {
    try {
      final commaIndex = path.indexOf(',');
      if (commaIndex != -1) {
        final base64String = path.substring(commaIndex + 1);
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      }
    } catch (_) {
      return null;
    }
  }
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (!kIsWeb) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {
      // Graceful fallback for non-file or unsupported platforms
    }
  }
  return null;
}
