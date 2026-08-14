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
    ShuffleStepType.pause,
    ShuffleStepType.transfer,
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

    test('pauseが最低1回含まれる', () {
      for (final int level in <int>[4, 5, 6]) {
        for (int seed = 0; seed < 20; seed++) {
          final ShuffleStepSequence sequence = builder.build(
            profile: _profileFor(level),
            random: Random(seed),
          );

          expect(sequence.steps.where((s) => s.type == ShuffleStepType.pause).isNotEmpty, isTrue);
        }
      }
    });

    test('move/transfer/pause以外の種別が含まれない', () {
      for (final int level in <int>[4, 5, 6]) {
        for (int seed = 0; seed < 20; seed++) {
          final ShuffleStepSequence sequence = builder.build(
            profile: _profileFor(level),
            random: Random(seed),
          );

          for (final ShuffleStep step in sequence.steps) {
            expect(
              step.type,
              anyOf(ShuffleStepType.move, ShuffleStepType.transfer, ShuffleStepType.pause),
            );
          }
        }
      }
    });

    test('move/transferのdurationに緩急（速度のばらつき）がある', () {
      final Set<Duration> observedDurations = <Duration>{};
      for (int seed = 0; seed < 20; seed++) {
        final ShuffleStepSequence sequence = builder.build(
          profile: _profileFor(4),
          random: Random(seed),
        );

        for (final ShuffleStep step in sequence.steps) {
          if (step.type == ShuffleStepType.move || step.type == ShuffleStepType.transfer) {
            observedDurations.add(step.duration);
          }
        }
      }

      // 一律のdurationしか出ないなら緩急がないということなので、
      // 複数の異なるdurationが観測されることを確認する。
      expect(observedDurations.length, greaterThan(1));
    });

    test('タイムラインはpause挿入後も単調増加する', () {
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
