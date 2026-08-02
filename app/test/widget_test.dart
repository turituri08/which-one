import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/app.dart';

void main() {
  testWidgets('title screen navigates to game and back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: WhichOneApp()));

    expect(find.text('どっち'), findsOneWidget);

    await tester.tap(find.text('チャレンジ開始'));
    await tester.pumpAndSettle();
    expect(find.text('ゲーム画面（準備中）'), findsOneWidget);

    await tester.tap(find.text('タイトルへ戻る'));
    await tester.pumpAndSettle();
    expect(find.text('どっち'), findsOneWidget);
  });
}
