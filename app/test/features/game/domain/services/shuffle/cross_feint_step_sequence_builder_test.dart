import 'dart:math';

import 'package:app/features/game/domain/entities/shuffle_step.dart';
import 'package:app/features/game/domain/services/shuffle/cross_feint_step_sequence_builder.dart';
import 'package:app/features/game/domain/services/shuffle/shuffle_step_sequence.dart';
import 'package:app/features/game/domain/value_objects/difficulty_profile.dart';
import 'package:app/features/game/domain/value_objects/hand_id.dart';
import 'package:app/features/game/domain/value_objects/shuffle_step_type.dart';
import 'package:flutter_test/flutter_test.dart';

DifficultyProfile _profileFor(int level) => DifficultyProfile(
  level: level,
  performerCount: 1,
  allowedMoves: const <ShuffleStepType>{
    ShuffleStepType.move,
    ShuffleStepType.pause,
    ShuffleStepType.cross,
    ShuffleStepType.transfer,
    ShuffleStepType.feint,
  },
);

void main() {
  group('CrossFeintStepSequenceBuilder', () {
    const CrossFeintStepSequenceBuilder builder = CrossFeintStepSequenceBuilder();

    test('同じレベル・シードなら同じ結果になる（再現性）', () {
      final ShuffleStepSequence a = builder.build(profile: _profileFor(7), random: Random(42));
      final ShuffleStepSequence b = builder.build(profile: _profileFor(7), random: Random(42));

      expect(a.initialHolder, equals(b.initialHolder));
      expect(a.finalHolder, equals(b.finalHolder));
      expect(a.steps.length, equals(b.steps.length));
    });

    test('transferは最低1回含まれる（コインが実際に移動しないとシャッフルが成立しないため）', () {
      for (final int level in <int>[7, 8, 9]) {
        for (int seed = 0; seed < 20; seed++) {
          final ShuffleStepSequence sequence = builder.build(
            profile: _profileFor(level),
            random: Random(seed),
          );

          expect(sequence.steps.where((s) => s.type == ShuffleStepType.transfer).isNotEmpty, isTrue);
        }
      }
    });

    test('cross・feintは確率的に発生し、出現しないケース・出現するケースの両方があり得る', () {
      // cross・feintはpauseと同様に最低出現回数を保証しないため、十分な数の
      // シードを試したときに「一度も出ない」結果と「出る」結果の両方が観測されることを確認する。
      bool sawNoCross = false;
      bool sawCross = false;
      bool sawNoFeint = false;
      bool sawFeint = false;
      for (int seed = 0; seed < 50; seed++) {
        final ShuffleStepSequence sequence = builder.build(
          profile: _profileFor(7),
          random: Random(seed),
        );

        if (sequence.steps.where((s) => s.type == ShuffleStepType.cross).isEmpty) {
          sawNoCross = true;
        } else {
          sawCross = true;
        }
        if (sequence.steps.where((s) => s.type == ShuffleStepType.feint).isEmpty) {
          sawNoFeint = true;
        } else {
          sawFeint = true;
        }
      }

      expect(sawNoCross, isTrue);
      expect(sawCross, isTrue);
      expect(sawNoFeint, isTrue);
      expect(sawFeint, isTrue);
    });

    test('往復回数が多いレベルほど、cross・feintが複数回発生し得る', () {
      // 往復回数が少ないと複数回出現しにくいため、十分に往復回数が多いレベルで
      // 多数のシードを試し、2回以上出現するケースが実際に存在することを確認する。
      // 「多い場合は複数回、少ない場合は1回でもよい」という要件の確認であり、
      // 全シードで複数回になることまでは要求しない。
      int maxCrossCount = 0;
      int maxFeintCount = 0;
      for (int seed = 0; seed < 200; seed++) {
        final ShuffleStepSequence sequence = builder.build(
          profile: _profileFor(30),
          random: Random(seed),
        );

        final int crossCount = sequence.steps.where((s) => s.type == ShuffleStepType.cross).length;
        final int feintCount = sequence.steps.where((s) => s.type == ShuffleStepType.feint).length;
        maxCrossCount = max(maxCrossCount, crossCount);
        maxFeintCount = max(maxFeintCount, feintCount);
      }

      expect(maxCrossCount, greaterThan(1));
      expect(maxFeintCount, greaterThan(1));
    });

    test('feintは保持手を変更しない', () {
      for (final int level in <int>[7, 8, 9]) {
        for (int seed = 0; seed < 20; seed++) {
          final ShuffleStepSequence sequence = builder.build(
            profile: _profileFor(level),
            random: Random(seed),
          );

          // initialHolderから各stepを順に適用し、feintを含むtransfer以外の動作では
          // 保持手が変わらないという契約を確認する。
          HandId holder = sequence.initialHolder;
          for (final ShuffleStep step in sequence.steps) {
            if (step.type != ShuffleStepType.transfer) {
              // feintもここに含まれる：接触に見えても保持手は変わらない。
              continue;
            }
            expect(step.actors.length, 2);
            expect(step.actors, contains(holder));
            holder = step.actors.firstWhere((HandId actor) => actor != holder);
          }

          expect(holder, sequence.finalHolder);
        }
      }
    });

    test('feintの当事者には現在の保持手が含まれる（受け渡しに見せかけるため）', () {
      for (int seed = 0; seed < 20; seed++) {
        final ShuffleStepSequence sequence = builder.build(
          profile: _profileFor(7),
          random: Random(seed),
        );

        HandId holder = sequence.initialHolder;
        for (final ShuffleStep step in sequence.steps) {
          if (step.type == ShuffleStepType.feint) {
            expect(step.actors, contains(holder));
          }
          if (step.type == ShuffleStepType.transfer) {
            holder = step.actors.firstWhere((HandId actor) => actor != holder);
          }
        }
      }
    });

    test('move/pause/cross/transfer/feint以外の種別が含まれない', () {
      for (final int level in <int>[7, 8, 9]) {
        for (int seed = 0; seed < 20; seed++) {
          final ShuffleStepSequence sequence = builder.build(
            profile: _profileFor(level),
            random: Random(seed),
          );

          for (final ShuffleStep step in sequence.steps) {
            expect(
              step.type,
              anyOf(
                ShuffleStepType.move,
                ShuffleStepType.pause,
                ShuffleStepType.cross,
                ShuffleStepType.transfer,
                ShuffleStepType.feint,
              ),
            );
          }
        }
      }
    });

    test('タイムラインは単調増加する', () {
      for (final int level in <int>[7, 8, 9]) {
        for (int seed = 0; seed < 20; seed++) {
          final ShuffleStepSequence sequence = builder.build(
            profile: _profileFor(level),
            random: Random(seed),
          );

          Duration previousEnd = Duration.zero;
          for (final ShuffleStep step in sequence.steps) {
            expect(step.start, greaterThanOrEqualTo(previousEnd));
            previousEnd = step.end;
          }
        }
      }
    });
  });
}
