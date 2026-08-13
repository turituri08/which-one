import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/app.dart';
import 'package:app/features/game/presentation/view_models/game_view_model.dart';

void main() {
  testWidgets('title screen navigates to game and back', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // 実タイマーを進めず、確認フェーズの表示だけを検証する。
        overrides: [
          gameSchedulerProvider.overrideWithValue((Duration duration, void Function() callback) {}),
        ],
        child: const WhichOneApp(),
      ),
    );

    expect(find.text('どっち'), findsOneWidget);

    await tester.tap(find.text('チャレンジ開始'));
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 1'), findsOneWidget);

    await tester.tap(find.text('タイトルへ戻る'));
    await tester.pumpAndSettle();
    expect(find.text('どっち'), findsOneWidget);
  });
}
