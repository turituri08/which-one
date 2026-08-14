import 'package:app/features/game/domain/entities/shuffle_plan.dart';
import 'package:app/features/game/domain/entities/shuffle_step.dart';
import 'package:app/features/game/domain/value_objects/hand_id.dart';
import 'package:app/features/game/domain/value_objects/performer_position.dart';
import 'package:app/features/game/domain/value_objects/shuffle_step_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShufflePlan', () {
    test('totalDurationはstepsの終了時刻の最大値になる', () {
      final HandId left = HandId(performerPosition: PerformerPosition.frontCenter, handIndex: 0);
      final HandId right = HandId(performerPosition: PerformerPosition.frontCenter, handIndex: 1);
      final ShufflePlan plan = ShufflePlan(
        seed: 1,
        initialHolder: left,
        finalHolder: right,
        steps: <ShuffleStep>[
          ShuffleStep(
            start: Duration.zero,
            duration: const Duration(milliseconds: 800),
            type: ShuffleStepType.move,
            actors: <HandId>[left],
          ),
          ShuffleStep(
            start: const Duration(milliseconds: 800),
            duration: const Duration(milliseconds: 400),
            type: ShuffleStepType.transfer,
            actors: <HandId>[left, right],
          ),
        ],
      );

      expect(plan.totalDuration, const Duration(milliseconds: 1200));
    });

    test('stepsが空の場合はtotalDurationがゼロになる', () {
      final HandId holder = HandId(performerPosition: PerformerPosition.frontCenter, handIndex: 0);
      final ShufflePlan plan = ShufflePlan(
        seed: 1,
        initialHolder: holder,
        finalHolder: holder,
        steps: const <ShuffleStep>[],
      );

      expect(plan.totalDuration, Duration.zero);
    });
  });
}
