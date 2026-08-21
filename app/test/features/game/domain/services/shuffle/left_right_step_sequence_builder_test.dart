import 'dart:math';

import 'package:app/features/game/domain/entities/shuffle_step.dart';
import 'package:app/features/game/domain/services/shuffle/left_right_step_sequence_builder.dart';
import 'package:app/features/game/domain/services/shuffle/shuffle_step_sequence.dart';
import 'package:app/features/game/domain/value_objects/difficulty_profile.dart';
import 'package:app/features/game/domain/value_objects/hand_id.dart';
import 'package:app/features/game/domain/value_objects/shuffle_step_type.dart';
import 'package:flutter_test/flutter_test.dart';

DifficultyProfile _profileFor(int level) => DifficultyProfile(
  level: level,
  performerCount: 1,
  allowedMoves: const <ShuffleStepType>{ShuffleStepType.move, ShuffleStepType.transfer},
);

void main() {
  group('LeftRightStepSequenceBuilder', () {
    const LeftRightStepSequenceBuilder builder = LeftRightStepSequenceBuilder();

    test('同じレベル・シードなら同じ結果になる（再現性）', () {
      final ShuffleStepSequence a = builder.build(profile: _profileFor(1), random: Random(42));
      final ShuffleStepSequence b = builder.build(profile: _profileFor(1), random: Random(42));

      expect(a.initialHolder, equals(b.initialHolder));
      expect(a.finalHolder, equals(b.finalHolder));
      expect(a.steps.length, equals(b.steps.length));
    });

    test('transferは確率的に発生し、出現しない回・出現する回の両方があり得る', () {
      // transferはmove/pause/cross/feintと同様に最低出現回数を保証しないため、
      // 十分な数のシードを試したときに「一度も出ない」結果と「出る」結果の
      // 両方が観測されることを確認する。
      bool sawNoTransfer = false;
      bool sawTransfer = false;
      for (int seed = 0; seed < 50; seed++) {
        final ShuffleStepSequence sequence = builder.build(
          profile: _profileFor(1),
          random: Random(seed),
        );

        if (sequence.steps.where((s) => s.type == ShuffleStepType.transfer).isEmpty) {
          sawNoTransfer = true;
        } else {
          sawTransfer = true;
        }
      }

      expect(sawNoTransfer, isTrue);
      expect(sawTransfer, isTrue);
    });

    test('finalHolderはinitialHolderと同じ場合も異なる場合もあり得る', () {
      final Set<bool> outcomes = <bool>{};
      for (int seed = 0; seed < 50; seed++) {
        final ShuffleStepSequence sequence = builder.build(
          profile: _profileFor(1),
          random: Random(seed),
        );
        outcomes.add(sequence.finalHolder == sequence.initialHolder);
      }

      expect(outcomes, containsAll(<bool>{true, false}));
    });

    test('レベルが上がるほど往復回数（ステップ数）が増える', () {
      final ShuffleStepSequence level1 = builder.build(profile: _profileFor(1), random: Random(1));
      final ShuffleStepSequence level2 = builder.build(profile: _profileFor(2), random: Random(1));

      expect(level2.steps.length, greaterThan(level1.steps.length));
    });

    test('move/transfer以外の種別が含まれない', () {
      for (int level = 1; level <= 3; level++) {
        for (int seed = 0; seed < 20; seed++) {
          final ShuffleStepSequence sequence = builder.build(
            profile: _profileFor(level),
            random: Random(seed),
          );

          for (final ShuffleStep step in sequence.steps) {
            expect(step.type, anyOf(ShuffleStepType.move, ShuffleStepType.transfer));
          }
        }
      }
    });

    test('moveの出現頻度はtransferより高い', () {
      int moveCount = 0;
      int transferCount = 0;
      for (int seed = 0; seed < 200; seed++) {
        final ShuffleStepSequence sequence = builder.build(
          profile: _profileFor(9),
          random: Random(seed),
        );
        for (final ShuffleStep step in sequence.steps) {
          if (step.type == ShuffleStepType.move) {
            moveCount++;
          } else if (step.type == ShuffleStepType.transfer) {
            transferCount++;
          }
        }
      }

      expect(moveCount, greaterThan(transferCount));
    });

    test('保持手は常に1本であり、transfer以外の動作では保持手が変わらない', () {
      for (int level = 1; level <= 3; level++) {
        for (int seed = 0; seed < 20; seed++) {
          final ShuffleStepSequence sequence = builder.build(
            profile: _profileFor(level),
            random: Random(seed),
          );

          // initialHolderから各stepを順に適用し、transferだけが保持手を
          // 変更できるという契約を生成結果に対して検証する。
          HandId holder = sequence.initialHolder;
          for (final ShuffleStep step in sequence.steps) {
            if (step.type != ShuffleStepType.transfer) {
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
  });
}
