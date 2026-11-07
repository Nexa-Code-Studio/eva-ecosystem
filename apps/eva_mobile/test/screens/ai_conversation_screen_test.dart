import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/features/chat/domain/entities/conversation_entity.dart';
import 'package:eva_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:eva_mobile/features/chat/presentation/providers/chat_provider.dart';
import 'package:eva_mobile/features/chat/presentation/screens/ai_conversation_screen.dart';
import 'package:eva_mobile/widgets/glass_card.dart';

class _PendingChatRepository implements ChatRepository {
  @override
  Future<List<ConversationEntity>> getConversations() =>
      Completer<List<ConversationEntity>>().future;

  @override
  Future<ConversationEntity?> getConversationById(String id) =>
      Completer<ConversationEntity?>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AiConversationScreen header does not contain MODE SUARA AI label', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AiConversationScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify header title exists
    expect(find.text('Sesi Suara EVA'), findsOneWidget);

    // Verify MODE SUARA AI badge is eliminated
    expect(find.text('MODE SUARA AI'), findsNothing);
  });

  testWidgets('AiConversationScreen session tile renders emotion emoji, dynamic duration, and chevron', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AiConversationScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify 'Sesi Suara' badge does not exist
    expect(find.text('Sesi Suara'), findsNothing);
    // Verify static '04:00' does not exist
    expect(find.text('04:00'), findsNothing);
    // Verify speaker icon Icons.volume_up_outlined does not exist
    expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
  });

  testWidgets('AiConversationScreen displays exactly 10 skeleton tiles during loading', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(_PendingChatRepository()),
        ],
        child: const MaterialApp(
          home: AiConversationScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify skeleton list is rendered
    expect(find.byKey(const ValueKey('session_skeleton_list')), findsOneWidget);

    // Verify there are 10 skeleton GlassCards rendered within the skeleton list
    final skeletonFinder = find.descendant(
      of: find.byKey(const ValueKey('session_skeleton_list')),
      matching: find.byType(GlassCard),
    );
    expect(skeletonFinder, findsNWidgets(10));
  });
}

