import 'dart:math';

import 'package:app/features/game/domain/entities/shuffle_step.dart';
import 'package:app/features/game/domain/services/shuffle/pause_tempo_step_sequence_builder.dart';
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
    ShuffleStepType.transfer,
    ShuffleStepType.cross,
    ShuffleStepType.pause,
  },
);

void main() {
  group('PauseTempoStepSequenceBuilder', () {
    const PauseTempoStepSequenceBuilder builder = PauseTempoStepSequenceBuilder();

    test('同じレベル・シードなら同じ結果になる（再現性）', () {
      final ShuffleStepSequence a = builder.build(profile: _profileFor(4), random: Random(42));
      final ShuffleStepSequence b = builder.build(profile: _profileFor(4), random: Random(42));

      expect(a.initialHolder, equals(b.initialHolder));
      expect(a.finalHolder, equals(b.finalHolder));
      expect(a.steps.length, equals(b.steps.length));
    });

    test('pause・cross・transferは確率的に発生し、出現しない回・出現する回の両方があり得る', () {
      // いずれも最低出現回数を保証しないため、十分な数のシードを試したときに
      // 「一度も出ない」結果と「出る」結果の両方が観測されることを確認する。
      bool sawNoPause = false;
      bool sawPause = false;
      bool sawNoCross = false;
      bool sawCross = false;
      bool sawNoTransfer = false;
      bool sawTransfer = false;
      for (int seed = 0; seed < 50; seed++) {
        final ShuffleStepSequence sequence = builder.build(
          profile: _profileFor(4),
          random: Random(seed),
        );

        if (sequence.steps.where((s) => s.type == ShuffleStepType.pause).isEmpty) {
          sawNoPause = true;
        } else {
          sawPause = true;
        }
        if (sequence.steps.where((s) => s.type == ShuffleStepType.cross).isEmpty) {
          sawNoCross = true;
        } else {
          sawCross = true;
        }
        if (sequence.steps.where((s) => s.type == ShuffleStepType.transfer).isEmpty) {
          sawNoTransfer = true;
        } else {
          sawTransfer = true;
        }
      }

      expect(sawNoPause, isTrue);
      expect(sawPause, isTrue);
      expect(sawNoCross, isTrue);
      expect(sawCross, isTrue);
      expect(sawNoTransfer, isTrue);
      expect(sawTransfer, isTrue);
    });

    test('move/transfer/cross/pause以外の種別が含まれない', () {
      for (final int level in <int>[4, 5, 6]) {
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
                ShuffleStepType.transfer,
                ShuffleStepType.cross,
                ShuffleStepType.pause,
              ),
            );
          }
        }
      }
    });

    test('move/transfer/crossのdurationに緩急（速度のばらつき）がある', () {
      final Set<Duration> observedDurations = <Duration>{};
      for (int seed = 0; seed < 20; seed++) {
        final ShuffleStepSequence sequence = builder.build(
          profile: _profileFor(4),
          random: Random(seed),
        );

        for (final ShuffleStep step in sequence.steps) {
          if (step.type != ShuffleStepType.pause) {
            observedDurations.add(step.duration);
          }
        }
      }

      // 一律のdurationしか出ないなら緩急がないということなので、
      // 複数の異なるdurationが観測されることを確認する。
      expect(observedDurations.length, greaterThan(1));
    });

    test('主動作の出現頻度はmove > transfer > cross > pauseの順になる', () {
      // 統計的な傾向の確認であり、個々のシードのばらつきを吸収するため
      // 十分に多いレベル・シード数で集計する。
      final Map<ShuffleStepType, int> counts = <ShuffleStepType, int>{
        ShuffleStepType.move: 0,
        ShuffleStepType.transfer: 0,
        ShuffleStepType.cross: 0,
        ShuffleStepType.pause: 0,
      };
      for (int seed = 0; seed < 300; seed++) {
        final ShuffleStepSequence sequence = builder.build(
          profile: _profileFor(6),
          random: Random(seed),
        );
        for (final ShuffleStep step in sequence.steps) {
          if (counts.containsKey(step.type)) {
            counts[step.type] = counts[step.type]! + 1;
          }
        }
      }

      expect(counts[ShuffleStepType.move]!, greaterThan(counts[ShuffleStepType.transfer]!));
      expect(counts[ShuffleStepType.transfer]!, greaterThan(counts[ShuffleStepType.cross]!));
      expect(counts[ShuffleStepType.cross]!, greaterThan(counts[ShuffleStepType.pause]!));
    });

    test('タイムラインは単調増加する', () {
      for (final int level in <int>[4, 5, 6]) {
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

    test('保持手は常に1本であり、transfer以外の動作では保持手が変わらない', () {
      for (final int level in <int>[4, 5, 6]) {
        for (int seed = 0; seed < 20; seed++) {
          final ShuffleStepSequence sequence = builder.build(
            profile: _profileFor(level),
            random: Random(seed),
          );

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
