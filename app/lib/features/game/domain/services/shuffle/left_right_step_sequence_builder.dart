import 'dart:math';

import '../../entities/shuffle_step.dart';
import '../../value_objects/difficulty_profile.dart';
import '../../value_objects/hand_id.dart';
import '../../value_objects/shuffle_step_type.dart';
import 'shuffle_hands.dart';
import 'shuffle_random_choices.dart';
import 'shuffle_step_sequence.dart';

/// Level 1〜3向け：一定速度の左右往復のみで構成する生成戦略。
///
/// 各往復ごとにコインを持ち替える（`transfer`）かどうかを抽選するため、
/// 終了時の保持手は開始時と同じ場合も異なる場合もあり得る。
/// 「開始手には戻らない」という固定パターンをプレイヤーに学習されると
/// 観察せずに正解できてしまうため、意図的に両方の結果を許容している。
/// ただし何も動かないと退屈なので、最低1回は`transfer`を発生させる。
class LeftRightStepSequenceBuilder {
  const LeftRightStepSequenceBuilder({
    this.baseRepetitions = 2,
    this.repetitionIncrementPerLevel = 1,
    this.repetitionDuration = const Duration(milliseconds: 600),
  });

  /// Level 1での左右往復回数。
  final int baseRepetitions;

  /// レベルが1上がるごとに増える往復回数。
  final int repetitionIncrementPerLevel;

  /// 1往復あたりの所要時間。
  final Duration repetitionDuration;

  ShuffleStepSequence build({required DifficultyProfile profile, required Random random}) {
    final HandId initialHolder = random.nextBool() ? ShuffleHands.hand0 : ShuffleHands.hand1;

    // 左右往復の回数。レベルが上がるほど増え、シャッフルの尺が伸びる。
    final int repetitions = baseRepetitions + (profile.level - 1) * repetitionIncrementPerLevel;

    // 各往復でコインを持ち替えるかどうかを個別に抽選する。
    final List<bool> transfersAtRepetition = ensureAtLeastOneTrue(
      <bool>[for (int i = 0; i < repetitions; i++) random.nextBool()],
      random,
    );

    final List<ShuffleStep> steps = <ShuffleStep>[];
    // 往復を進めながら、その時点の保持手を追跡する。
    HandId currentHolder = initialHolder;
    for (int i = 0; i < repetitions; i++) {
      if (transfersAtRepetition[i]) {
        final HandId nextHolder = currentHolder == ShuffleHands.hand0
            ? ShuffleHands.hand1
            : ShuffleHands.hand0;
        steps.add(
          ShuffleStep(
            start: repetitionDuration * i,
            duration: repetitionDuration,
            type: ShuffleStepType.transfer,
            actors: <HandId>[currentHolder, nextHolder],
          ),
        );
        currentHolder = nextHolder;
      } else {
        steps.add(
          ShuffleStep(
            start: repetitionDuration * i,
            duration: repetitionDuration,
            type: ShuffleStepType.move,
            actors: <HandId>[ShuffleHands.hand0, ShuffleHands.hand1],
          ),
        );
      }
    }

    return ShuffleStepSequence(
      initialHolder: initialHolder,
      steps: steps,
      finalHolder: currentHolder,
    );
  }
}
