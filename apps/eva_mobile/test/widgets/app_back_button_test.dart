import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eva_mobile/widgets/app_back_button.dart';

void main() {
  group('AppBackButton Widget Tests', () {
    testWidgets('renders default AppBackButton with rounded back icon and circle shape', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBackButton(),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.arrow_back_rounded);
      expect(iconFinder, findsOneWidget);

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      final containerWidget = tester.widget<Container>(
        find.descendant(of: find.byType(AppBackButton), matching: find.byType(Container)),
      );
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);

      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.size, 20.0);
    });

    testWidgets('calls Navigator.maybePop when tapped without custom onPressed', (tester) async {
      bool didPop = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onDidRemovePage: (page) {
              didPop = true;
            },
            pages: const [
              MaterialPage(child: Scaffold(body: Text('Page 1'))),
              MaterialPage(child: Scaffold(body: AppBackButton())),
            ],
          ),
        ),
      );

      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(didPop, isTrue);
    });

    testWidgets('calls custom onPressed callback when supplied', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppBackButton(
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppBackButton));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('AppBackButton.dark renders with white icon and appropriate dark decoration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBackButton.dark(),
          ),
        ),
      );

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.arrow_back_rounded));
      expect(iconWidget.color, Colors.white);

      final containerWidget = tester.widget<Container>(
        find.descendant(of: find.byType(AppBackButton), matching: find.byType(Container)),
      );
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('respects custom size, icon, and tooltip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBackButton(
              size: 48.0,
              iconSize: 24.0,
              icon: Icons.close_rounded,
              tooltip: 'Tutup',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byTooltip('Tutup'), findsOneWidget);

      final containerWidget = tester.widget<Container>(
        find.descendant(of: find.byType(AppBackButton), matching: find.byType(Container)),
      );
      expect(containerWidget.constraints?.maxWidth, 48.0);
      expect(containerWidget.constraints?.maxHeight, 48.0);
    });
  });
}
