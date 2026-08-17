import 'dart:math';

import '../../entities/shuffle_step.dart';
import '../../value_objects/difficulty_profile.dart';
import '../../value_objects/hand_id.dart';
import '../../value_objects/shuffle_step_type.dart';
import 'shuffle_hands.dart';
import 'shuffle_step_sequence.dart';
import 'shuffle_tempo.dart';

/// Level 7以上向け：`feint`（見せかけの動き）を加える生成戦略。
///
/// `cross`・`pause`・緩急は`PauseTempoStepSequenceBuilder`と同様に維持したうえで、
/// フェイントを追加し、暗記だけでは突破できない難易度帯にする。
/// `feint`は実際の受け渡し（`transfer`）と紛らわしい動きを見せるが、
/// 保持手を変更しないという契約は厳守する。
class CrossFeintStepSequenceBuilder {
  const CrossFeintStepSequenceBuilder({
    this.baseRepetitions = 2,
    this.repetitionIncrementPerLevel = 1,
    this.repetitionDuration = const Duration(milliseconds: 600),
    this.tempoVariationRatio = 0.4,
    this.transferProbability = 0.28,
    this.crossProbability = 0.18,
    this.feintProbability = 0.1,
    this.pauseProbability = 0.06,
  });

  /// Level 1での左右往復回数。
  final int baseRepetitions;

  /// レベルが1上がるごとに増える往復回数。
  final int repetitionIncrementPerLevel;

  /// 1往復あたりの基準所要時間。`tempoVariationRatio`で実際の値を揺らす。
  final Duration repetitionDuration;

  /// `move`/`transfer`/`cross`/`feint`/`pause`の所要時間を基準値から
  /// どれだけ揺らすかの比率。値はプレイテストで調整する暫定値。
  final double tempoVariationRatio;

  /// 各往復を`transfer`にする確率（0.0〜1.0）。
  ///
  /// 出現頻度は`move` > `transfer` > `cross` > `feint` > `pause`の順を
  /// 意図しつつ、`transfer`自体は比較的高い確率で発生させる
  /// （値はプレイテストで調整する暫定値）。
  final double transferProbability;

  /// 各往復を`cross`にする確率（0.0〜1.0）。値はプレイテストで調整する暫定値。
  final double crossProbability;

  /// 各往復を`feint`にする確率（0.0〜1.0）。値はプレイテストで調整する暫定値。
  final double feintProbability;

  /// 各往復を`pause`にする確率（0.0〜1.0）。値はプレイテストで調整する暫定値。
  final double pauseProbability;

  ShuffleStepSequence build({required DifficultyProfile profile, required Random random}) {
    final HandId initialHolder = random.nextBool() ? ShuffleHands.hand0 : ShuffleHands.hand1;
    final int repetitions = baseRepetitions + (profile.level - 1) * repetitionIncrementPerLevel;

    // 各往復の主動作（move/transfer/cross/feint/pause）を、move > transfer >
    // cross > feint > pauseの順で出現頻度が下がるよう1回の抽選で決める。
    // いずれも演出であり、出現しない回があっても緩急や往復数で難易度は
    // 保たれるため、最低出現回数は保証しない（transferが1回もない回は、
    // 開始時の保持手がそのまま正解位置になる）。
    final List<ShuffleStepType> primaryTypeAtRepetition = <ShuffleStepType>[
      for (int i = 0; i < repetitions; i++) _rollPrimaryType(random),
    ];

    final List<ShuffleStep> steps = <ShuffleStep>[];
    HandId currentHolder = initialHolder;
    Duration elapsed = Duration.zero;

    for (int i = 0; i < repetitions; i++) {
      final Duration stepDuration = tempoVariedDuration(
        base: repetitionDuration,
        ratio: tempoVariationRatio,
        random: random,
      );

      switch (primaryTypeAtRepetition[i]) {
        case ShuffleStepType.transfer:
          final HandId nextHolder = currentHolder == ShuffleHands.hand0
              ? ShuffleHands.hand1
              : ShuffleHands.hand0;
          steps.add(
            ShuffleStep(
              start: elapsed,
              duration: stepDuration,
              type: ShuffleStepType.transfer,
              actors: <HandId>[currentHolder, nextHolder],
            ),
          );
          currentHolder = nextHolder;
        case ShuffleStepType.feint:
          // feintはtransferと同じ接触動作に見せるが、保持手は更新しない
          // （プレイヤーが事後に「本当の受け渡しではなかった」と理解できる動き）。
          final HandId other = currentHolder == ShuffleHands.hand0
              ? ShuffleHands.hand1
              : ShuffleHands.hand0;
          steps.add(
            ShuffleStep(
              start: elapsed,
              duration: stepDuration,
              type: ShuffleStepType.feint,
              actors: <HandId>[currentHolder, other],
            ),
          );
        case ShuffleStepType.cross:
          steps.add(
            ShuffleStep(
              start: elapsed,
              duration: stepDuration,
              type: ShuffleStepType.cross,
              actors: <HandId>[ShuffleHands.hand0, ShuffleHands.hand1],
            ),
          );
        case ShuffleStepType.pause:
          steps.add(
            ShuffleStep(
              start: elapsed,
              duration: stepDuration,
              type: ShuffleStepType.pause,
              actors: <HandId>[ShuffleHands.hand0, ShuffleHands.hand1],
            ),
          );
        case ShuffleStepType.move:
        case ShuffleStepType.exitStage:
        case ShuffleStepType.enterStage:
          steps.add(
            ShuffleStep(
              start: elapsed,
              duration: stepDuration,
              type: ShuffleStepType.move,
              actors: <HandId>[ShuffleHands.hand0, ShuffleHands.hand1],
            ),
          );
      }
      elapsed += stepDuration;
    }

    return ShuffleStepSequence(
      initialHolder: initialHolder,
      steps: steps,
      finalHolder: currentHolder,
    );
  }

  /// `move`/`transfer`/`cross`/`feint`/`pause`のいずれかを、指定の確率順で1つ選ぶ。
  ShuffleStepType _rollPrimaryType(Random random) {
    final double roll = random.nextDouble();
    if (roll < transferProbability) {
      return ShuffleStepType.transfer;
    }
    if (roll < transferProbability + crossProbability) {
      return ShuffleStepType.cross;
    }
    if (roll < transferProbability + crossProbability + feintProbability) {
      return ShuffleStepType.feint;
    }
    if (roll < transferProbability + crossProbability + feintProbability + pauseProbability) {
      return ShuffleStepType.pause;
    }
    return ShuffleStepType.move;
  }
}
