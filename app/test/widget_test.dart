import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('WhichOneApp shows the placeholder title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WhichOneApp()));

    expect(find.text('どっち'), findsOneWidget);
  });
}
