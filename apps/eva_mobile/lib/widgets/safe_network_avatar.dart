import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Resolves an avatar URL into a safe [ImageProvider].
///
/// Supports `http://` / `https://` URLs and `data:image/...;base64,...` data URIs.
/// Returns `null` for empty, malformed, or unsupported paths so callers never
/// trigger `NetworkImageLoadException` on invalid values.
ImageProvider? resolveSafeAvatarImageProvider(String? imageUrl) {
  if (imageUrl == null) return null;
  final trimmed = imageUrl.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('data:image/')) {
    final commaIndex = trimmed.indexOf(',');
    if (commaIndex == -1 || commaIndex + 1 >= trimmed.length) return null;
    try {
      final bytes = base64Decode(trimmed.substring(commaIndex + 1));
      if (bytes.isEmpty) return null;
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty) {
    return NetworkImage(trimmed);
  }

  return null;
}

/// A circular avatar that safely loads network or Base64 images and always
/// falls back to a default icon when the URL is empty, invalid, or fails to load.
class SafeNetworkAvatar extends StatefulWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;
  final IconData fallbackIcon;

  const SafeNetworkAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
    this.fallbackIcon = Icons.person_rounded,
  });

  @override
  State<SafeNetworkAvatar> createState() => _SafeNetworkAvatarState();
}

class _SafeNetworkAvatarState extends State<SafeNetworkAvatar> {
  bool _hasLoadError = false;

  @override
  void didUpdateWidget(covariant SafeNetworkAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _hasLoadError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        _hasLoadError ? null : resolveSafeAvatarImageProvider(widget.imageUrl);
    final showFallback = provider == null;

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? AppColors.primaryContainer,
      backgroundImage: provider,
      onBackgroundImageError: provider != null
          ? (_, _) {
              if (mounted && !_hasLoadError) {
                setState(() => _hasLoadError = true);
              }
            }
          : null,
      child: showFallback
          ? Icon(
              widget.fallbackIcon,
              size: widget.iconSize ?? widget.radius,
              color: widget.iconColor ?? AppColors.primary,
            )
          : null,
    );
  }
}
