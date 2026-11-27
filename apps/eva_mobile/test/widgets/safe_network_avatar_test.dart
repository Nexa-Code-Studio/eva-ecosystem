import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/widgets/safe_network_avatar.dart';

void main() {
  // 1x1 transparent PNG
  const validBase64Png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

  group('resolveSafeAvatarImageProvider', () {
    test('returns null for null, empty, whitespace, or non-URL paths', () {
      expect(resolveSafeAvatarImageProvider(null), isNull);
      expect(resolveSafeAvatarImageProvider(''), isNull);
      expect(resolveSafeAvatarImageProvider('   '), isNull);
      expect(resolveSafeAvatarImageProvider('/local/device/avatar.png'), isNull);
      expect(resolveSafeAvatarImageProvider('https://'), isNull);
    });

    test('returns MemoryImage for valid data:image Base64 URI and null for corrupt Base64', () {
      final provider =
          resolveSafeAvatarImageProvider('data:image/png;base64,$validBase64Png');
      expect(provider, isA<MemoryImage>());
      expect((provider as MemoryImage).bytes, equals(base64Decode(validBase64Png)));

      expect(resolveSafeAvatarImageProvider('data:image/png;base64,not-valid!@#'), isNull);
      expect(resolveSafeAvatarImageProvider('data:image/png;base64,'), isNull);
    });

    test('returns NetworkImage for valid http/https URLs', () {
      final provider =
          resolveSafeAvatarImageProvider('https://eva.nexacode.dev/api/v1/avatars/1.png');
      expect(provider, isA<NetworkImage>());
    });
  });

  group('SafeNetworkAvatar widget', () {
    testWidgets('renders default person icon when imageUrl is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeNetworkAvatar(imageUrl: ''),
          ),
        ),
      );

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isNull);
      expect(avatar.onBackgroundImageError, isNull);
    });

    testWidgets('renders MemoryImage without fallback icon for valid Base64 URI', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeNetworkAvatar(
              imageUrl: 'data:image/png;base64,$validBase64Png',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person_rounded), findsNothing);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<MemoryImage>());
    });

    testWidgets('switches to fallback icon when onBackgroundImageError fires', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeNetworkAvatar(
              imageUrl: 'https://example.com/missing.png',
            ),
          ),
        ),
      );

      final avatarBefore = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatarBefore.backgroundImage, isA<NetworkImage>());
      expect(avatarBefore.onBackgroundImageError, isNotNull);

      avatarBefore.onBackgroundImageError!(Exception('404'), StackTrace.empty);
      await tester.pump();

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      final avatarAfter = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatarAfter.backgroundImage, isNull);
    });
  });
}
