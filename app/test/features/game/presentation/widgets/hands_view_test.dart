import 'package:app/features/game/domain/entities/shuffle_plan.dart';
import 'package:app/features/game/domain/services/shuffle_generator.dart';
import 'package:app/features/game/domain/value_objects/game_phase.dart';
import 'package:app/features/game/presentation/painters/hands_painter.dart';
import 'package:app/features/game/presentation/view_models/game_ui_state.dart';
import 'package:app/features/game/presentation/widgets/hands_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const ShuffleGenerator _generator = ShuffleGenerator();

Future<void> _pumpHandsView(WidgetTester tester, GameUiState state) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: HandsView(state: state, onHandTap: (_) {}))),
  );
}

/// ツリー内から`HandsPainter`を使っている`CustomPaint`を1つ見つける。
///
/// `MaterialApp`/`Scaffold`配下には他のウィジェットが使う`CustomPaint`も
/// 存在し得るため、型ではなく`painter`の実体で絞り込む。
HandsPainter _findHandsPainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((CustomPaint customPaint) => customPaint.painter)
      .whereType<HandsPainter>()
      .first;
}

void main() {
  group('HandsView', () {
    testWidgets('shuffling中でもクラッシュせず描画できる（Level 4：pause・緩急を含む）', (
      WidgetTester tester,
    ) async {
      final ShufflePlan plan = _generator.planFor(level: 4, seed: 1);
      final GameUiState state = GameUiState(phase: GamePhase.shuffling, level: 4, plan: plan);

      await _pumpHandsView(tester, state);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(plan.totalDuration);

      expect(tester.takeException(), isNull);
    });

    testWidgets('shuffling中でもクラッシュせず描画できる（Level 9：cross・feint・transferを含む）', (
      WidgetTester tester,
    ) async {
      final ShufflePlan plan = _generator.planFor(level: 9, seed: 3);
      final GameUiState state = GameUiState(phase: GamePhase.shuffling, level: 9, plan: plan);

      await _pumpHandsView(tester, state);
      // stepの途中を細かく刻んでpumpし、transferの接近・静止・復帰の
      // 各フェーズを通過してもクラッシュしないことを確認する。
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(plan.totalDuration);

      expect(tester.takeException(), isNull);
    });

    testWidgets('shuffling中は経過時間に応じてHandsPainterのelapsedが進む', (WidgetTester tester) async {
      final ShufflePlan plan = _generator.planFor(level: 1, seed: 1);
      final GameUiState state = GameUiState(phase: GamePhase.shuffling, level: 1, plan: plan);

      await _pumpHandsView(tester, state);
      await tester.pump();
      expect(_findHandsPainter(tester).elapsed, Duration.zero);

      await tester.pump(plan.totalDuration ~/ 2);
      final HandsPainter painterMidway = _findHandsPainter(tester);
      expect(painterMidway.elapsed, greaterThan(Duration.zero));
      expect(painterMidway.elapsed, lessThan(plan.totalDuration));
      expect(painterMidway.plan, same(plan));
    });

    testWidgets('shuffling以外ではelapsedが常にゼロで、planも渡されない', (WidgetTester tester) async {
      final ShufflePlan plan = _generator.planFor(level: 1, seed: 1);
      final GameUiState state = GameUiState(phase: GamePhase.confirming, level: 1, plan: plan);

      await _pumpHandsView(tester, state);
      await tester.pump(const Duration(milliseconds: 500));

      final HandsPainter painter = _findHandsPainter(tester);
      expect(painter.elapsed, Duration.zero);
      expect(painter.plan, isNull);
    });

    testWidgets('複数レベルにまたがってもクラッシュしない（Tickerの作り直しの確認）', (WidgetTester tester) async {
      final ShufflePlan level1Plan = _generator.planFor(level: 1, seed: 1);
      final ShufflePlan level2Plan = _generator.planFor(level: 2, seed: 1);

      await _pumpHandsView(
        tester,
        GameUiState(phase: GamePhase.shuffling, level: 1, plan: level1Plan),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // レベルが進み、confirmingを経て次のshufflingへ入る流れを再現する。
      await _pumpHandsView(
        tester,
        GameUiState(phase: GamePhase.confirming, level: 2, plan: level2Plan),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await _pumpHandsView(
        tester,
        GameUiState(phase: GamePhase.shuffling, level: 2, plan: level2Plan),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });
}
