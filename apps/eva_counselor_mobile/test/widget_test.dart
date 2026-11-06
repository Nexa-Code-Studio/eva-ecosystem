import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eva_counselor_mobile/main.dart';

void main() {
  testWidgets('EvaCounselorApp smoke test - renders login portal', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EvaCounselorApp()));
    await tester.pump();

    expect(find.text('Portal Psikolog EVA'), findsOneWidget);
    expect(find.text('Masuk Sebagai Psikolog'), findsOneWidget);
  });
}
