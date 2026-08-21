import 'package:app/features/game/domain/entities/shuffle_plan.dart';
import 'package:app/features/game/domain/entities/shuffle_step.dart';
import 'package:app/features/game/domain/services/shuffle_generator.dart';
import 'package:app/features/game/domain/services/shuffle_validator.dart';
import 'package:app/features/game/domain/value_objects/hand_id.dart';
import 'package:app/features/game/domain/value_objects/performer_position.dart';
import 'package:app/features/game/domain/value_objects/shuffle_step_type.dart';
import 'package:flutter_test/flutter_test.dart';

final HandId _hand0 = HandId(performerPosition: PerformerPosition.frontCenter, handIndex: 0);
final HandId _hand1 = HandId(performerPosition: PerformerPosition.frontCenter, handIndex: 1);

void main() {
  group('ShuffleValidator', () {
    const ShuffleValidator validator = ShuffleValidator();

    test('正常系：ShuffleGeneratorが生成した計画は常に有効と判定される', () {
      const ShuffleGenerator generator = ShuffleGenerator();

      for (int level = 1; level <= 9; level++) {
        for (int seed = 0; seed < 10; seed++) {
          final ShufflePlan plan = generator.planFor(level: level, seed: seed);

          expect(validator.isValid(plan), isTrue);
        }
      }
    });

    test('正常系：transferが1回もない計画も有効（開始時の保持手がそのまま正解位置になる）', () {
      final ShufflePlan plan = ShufflePlan(
        seed: 1,
        initialHolder: _hand0,
        steps: <ShuffleStep>[
          ShuffleStep(
            start: Duration.zero,
            duration: const Duration(milliseconds: 600),
            type: ShuffleStepType.move,
            actors: <HandId>[_hand0, _hand1],
          ),
        ],
        finalHolder: _hand0,
      );

      expect(validator.isValid(plan), isTrue);
    });

    test('不正系：transferの当事者に現在の保持手が含まれない計画は無効', () {
      // initialHolderはhand0だが、transferの当事者にhand0が含まれていないため、
      // 「誰から誰へ渡ったのか」が特定できない不正な計画になっている。
      final ShufflePlan plan = ShufflePlan(
        seed: 1,
        initialHolder: _hand0,
        steps: <ShuffleStep>[
          ShuffleStep(
            start: Duration.zero,
            duration: const Duration(milliseconds: 600),
            type: ShuffleStepType.transfer,
            actors: <HandId>[_hand1, _hand1],
          ),
        ],
        finalHolder: _hand1,
      );

      expect(validator.isValid(plan), isFalse);
    });

    test('不正系：transferの連鎖をたどった結果とfinalHolderが一致しない計画は無効', () {
      final ShufflePlan plan = ShufflePlan(
        seed: 1,
        initialHolder: _hand0,
        steps: <ShuffleStep>[
          ShuffleStep(
            start: Duration.zero,
            duration: const Duration(milliseconds: 600),
            type: ShuffleStepType.transfer,
            actors: <HandId>[_hand0, _hand1],
          ),
        ],
        // 連鎖をたどるとhand1になるはずだが、finalHolderがhand0のままになっている。
        finalHolder: _hand0,
      );

      expect(validator.isValid(plan), isFalse);
    });
  });
}
