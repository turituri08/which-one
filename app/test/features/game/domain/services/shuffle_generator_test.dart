import 'dart:math';

import 'package:app/features/game/domain/entities/shuffle_plan.dart';
import 'package:app/features/game/domain/entities/shuffle_step.dart';
import 'package:app/features/game/domain/services/difficulty_resolver.dart';
import 'package:app/features/game/domain/services/shuffle/left_right_step_sequence_builder.dart';
import 'package:app/features/game/domain/services/shuffle/pause_tempo_step_sequence_builder.dart';
import 'package:app/features/game/domain/services/shuffle/shuffle_step_sequence.dart';
import 'package:app/features/game/domain/services/shuffle_generator.dart';
import 'package:app/features/game/domain/value_objects/hand_id.dart';
import 'package:app/features/game/domain/value_objects/shuffle_step_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShuffleGenerator', () {
    const ShuffleGenerator generator = ShuffleGenerator();
    const DifficultyResolver resolver = DifficultyResolver();

    test('同じレベル・シードなら同じ計画になる（再現性）', () {
      final ShufflePlan a = generator.planFor(level: 1, seed: 42);
      final ShufflePlan b = generator.planFor(level: 1, seed: 42);

      expect(a.initialHolder, equals(b.initialHolder));
      expect(a.finalHolder, equals(b.finalHolder));
      expect(a.totalDuration, equals(b.totalDuration));
    });

    test('level未満1はArgumentErrorになる（DifficultyResolver経由の検証）', () {
      expect(() => generator.planFor(level: 0, seed: 1), throwsArgumentError);
    });

    test('Level 1〜3はLeftRightStepSequenceBuilderの結果とそのまま一致する（委譲の確認）', () {
      const LeftRightStepSequenceBuilder leftRightBuilder = LeftRightStepSequenceBuilder();

      for (final int level in <int>[1, 2, 3]) {
        final ShufflePlan plan = generator.planFor(level: level, seed: 7);
        final ShuffleStepSequence expected = leftRightBuilder.build(
          profile: resolver.resolve(level),
          random: Random(7),
        );

        expect(plan.initialHolder, equals(expected.initialHolder));
        expect(plan.finalHolder, equals(expected.finalHolder));
        expect(plan.steps.length, equals(expected.steps.length));
      }
    });

    test('Level 4以上はPauseTempoStepSequenceBuilderの結果とそのまま一致する（委譲の確認）', () {
      const PauseTempoStepSequenceBuilder pauseTempoBuilder = PauseTempoStepSequenceBuilder();

      for (final int level in <int>[4, 5, 6]) {
        final ShufflePlan plan = generator.planFor(level: level, seed: 7);
        final ShuffleStepSequence expected = pauseTempoBuilder.build(
          profile: resolver.resolve(level),
          random: Random(7),
        );

        expect(plan.initialHolder, equals(expected.initialHolder));
        expect(plan.finalHolder, equals(expected.finalHolder));
        expect(plan.steps.length, equals(expected.steps.length));
      }
    });

    test('Level 1〜3の生成にはpauseが含まれない（difficulty帯の切り替わり確認）', () {
      for (final int level in <int>[1, 2, 3]) {
        for (int seed = 0; seed < 20; seed++) {
          final ShufflePlan plan = generator.planFor(level: level, seed: seed);

          expect(plan.steps.where((s) => s.type == ShuffleStepType.pause).isEmpty, isTrue);
        }
      }
    });

    test('レベルが上がるほどシャッフルの尺が伸びる', () {
      final ShufflePlan level1 = generator.planFor(level: 1, seed: 1);
      final ShufflePlan level2 = generator.planFor(level: 2, seed: 1);

      expect(level2.totalDuration, greaterThan(level1.totalDuration));
    });

    test('保持手は常に1本であり、transfer以外の動作では保持手が変わらない（Level 1〜6の統合確認）', () {
      for (int level = 1; level <= 6; level++) {
        for (int seed = 0; seed < 20; seed++) {
          final ShufflePlan plan = generator.planFor(level: level, seed: seed);

          // initialHolderから各stepを順に適用し、transferだけが保持手を
          // 変更できるという契約を最終的な生成結果に対して検証する。
          HandId holder = plan.initialHolder;
          for (final ShuffleStep step in plan.steps) {
            if (step.type != ShuffleStepType.transfer) {
              continue;
            }
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
