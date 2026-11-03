import 'package:flutter_test/flutter_test.dart';

import 'package:eva_mobile/main.dart';



void main() {

  testWidgets('EvaApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EvaApp());
    expect(find.text('EVA'), findsWidgets);
  });

}

