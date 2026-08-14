import 'package:app/features/game/domain/entities/shuffle_plan.dart';
import 'package:app/features/game/domain/entities/shuffle_step.dart';
import 'package:app/features/game/domain/services/level_shuffle_planner.dart';
import 'package:app/features/game/domain/value_objects/hand_id.dart';
import 'package:app/features/game/domain/value_objects/shuffle_step_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelShufflePlanner', () {
    const LevelShufflePlanner planner = LevelShufflePlanner();

    test('同じレベル・シードなら同じ計画になる（再現性）', () {
      final ShufflePlan a = planner.planFor(level: 1, seed: 42);
      final ShufflePlan b = planner.planFor(level: 1, seed: 42);

      expect(a.initialHolder, equals(b.initialHolder));
      expect(a.finalHolder, equals(b.finalHolder));
      expect(a.totalDuration, equals(b.totalDuration));
    });

    test('最低1回はtransferが発生し、シャッフルとして機能する', () {
      for (int seed = 0; seed < 10; seed++) {
        final ShufflePlan plan = planner.planFor(level: 1, seed: seed);

        expect(plan.steps.where((s) => s.type == ShuffleStepType.transfer).isNotEmpty, isTrue);
      }
    });

    test('finalHolderはinitialHolderと同じ場合も異なる場合もあり得る', () {
      final Set<bool> outcomes = <bool>{};
      for (int seed = 0; seed < 50; seed++) {
        final ShufflePlan plan = planner.planFor(level: 1, seed: seed);
        outcomes.add(plan.finalHolder == plan.initialHolder);
      }

      expect(outcomes, containsAll(<bool>{true, false}));
    });

    test('レベルが上がるほどシャッフルの尺が伸びる', () {
      final ShufflePlan level1 = planner.planFor(level: 1, seed: 1);
      final ShufflePlan level2 = planner.planFor(level: 2, seed: 1);

      expect(level2.totalDuration, greaterThan(level1.totalDuration));
    });

    test('保持手は常に1本であり、transfer以外の動作では保持手が変わらない', () {
      for (int level = 1; level <= 5; level++) {
        for (int seed = 0; seed < 20; seed++) {
          final ShufflePlan plan = planner.planFor(level: level, seed: seed);

          // initialHolderから各stepを順に適用し、transferだけが保持手を
          // 変更できるという契約をplanner生成結果に対して検証する。
          HandId holder = plan.initialHolder;
          for (final ShuffleStep step in plan.steps) {
            if (step.type != ShuffleStepType.transfer) {
              // transfer以外は保持手を変更しない（何もしない）。
              continue;
            }
            // transferの当事者は必ず「現在の保持手」と「次の保持手」の2本だけである。
            expect(step.actors.length, 2);
            expect(step.actors, contains(holder));
            holder = step.actors.firstWhere((HandId actor) => actor != holder);
          }

          expect(holder, plan.finalHolder);
        }
      }
    });
  });
}
