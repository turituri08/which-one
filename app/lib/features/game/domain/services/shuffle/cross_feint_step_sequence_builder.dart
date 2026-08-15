import 'dart:math';

import '../../entities/shuffle_step.dart';
import '../../value_objects/difficulty_profile.dart';
import '../../value_objects/hand_id.dart';
import '../../value_objects/shuffle_step_type.dart';
import 'shuffle_hands.dart';
import 'shuffle_random_choices.dart';
import 'shuffle_step_sequence.dart';
import 'shuffle_tempo.dart';

/// Level 7以上向け：`cross`（交差）と`feint`（見せかけの動き）を加える生成戦略。
///
/// `pause`・緩急は`PauseTempoStepSequenceBuilder`と同様に維持したうえで、
/// 交差とフェイントを追加し、暗記だけでは突破できない難易度帯にする。
/// `feint`は実際の受け渡し（`transfer`）と紛らわしい動きを見せるが、
/// 保持手を変更しないという契約は厳守する。
class CrossFeintStepSequenceBuilder {
  const CrossFeintStepSequenceBuilder({
    this.baseRepetitions = 2,
    this.repetitionIncrementPerLevel = 1,
    this.repetitionDuration = const Duration(milliseconds: 600),
    this.pauseDuration = const Duration(milliseconds: 300),
    this.pauseProbability = 0.35,
    this.tempoVariationRatio = 0.4,
    this.crossProbability = 0.25,
    this.feintProbability = 0.25,
  });

  /// Level 1での左右往復回数。
  final int baseRepetitions;

  /// レベルが1上がるごとに増える往復回数。
  final int repetitionIncrementPerLevel;

  /// 1往復あたりの基準所要時間。`tempoVariationRatio`で実際の値を揺らす。
  final Duration repetitionDuration;

  /// `pause`ステップ1回あたりの静止時間。
  ///
  /// 値はプレイテストで調整する暫定値であり、本コミットでは確定しない。
  final Duration pauseDuration;

  /// 各往復の直前に`pause`を挿入する確率（0.0〜1.0）。
  ///
  /// 値はプレイテストで調整する暫定値であり、本コミットでは確定しない。
  final double pauseProbability;

  /// `move`/`transfer`/`cross`/`feint`の所要時間を基準値からどれだけ揺らすかの比率。
  ///
  /// 値はプレイテストで調整する暫定値であり、本コミットでは確定しない。
  final double tempoVariationRatio;

  /// `transfer`にならなかった往復のうち、`cross`にする確率（0.0〜1.0）。
  ///
  /// 往復回数が多いレベルほど、この確率に応じて`cross`の出現回数も増える。
  /// `feint`と異なり出現しない回があってもよい（値はプレイテストで調整する暫定値）。
  final double crossProbability;

  /// `transfer`にならなかった往復のうち、`feint`にする確率（0.0〜1.0）。
  ///
  /// 往復回数が多いレベルほど、この確率に応じて`feint`の出現回数も増える。
  /// `cross`と同様、出現しない回があってもよい（値はプレイテストで調整する暫定値）。
  final double feintProbability;

  ShuffleStepSequence build({required DifficultyProfile profile, required Random random}) {
    final HandId initialHolder = random.nextBool() ? ShuffleHands.hand0 : ShuffleHands.hand1;
    final int repetitions = baseRepetitions + (profile.level - 1) * repetitionIncrementPerLevel;

    // transferはコインを実際に移動させる、シャッフルの根幹となる動作なので
    // 最低1回は発生させる。一方でcross・feint・pauseはあくまで難易度を
    // 高める演出であり、出現しない回があっても緩急や往復数で難易度は保たれるため、
    // 最低出現回数は保証せず、往復ごとに独立した確率だけで発生させる。
    final List<bool> transfersAtRepetition = ensureAtLeastOneTrue(
      <bool>[for (int i = 0; i < repetitions; i++) random.nextBool()],
      random,
    );

    final List<bool> pausesBeforeRepetition = <bool>[
      for (int i = 0; i < repetitions; i++) random.nextDouble() < pauseProbability,
    ];

    final List<ShuffleStep> steps = <ShuffleStep>[];
    HandId currentHolder = initialHolder;
    Duration elapsed = Duration.zero;

    for (int i = 0; i < repetitions; i++) {
      if (pausesBeforeRepetition[i]) {
        steps.add(
          ShuffleStep(
            start: elapsed,
            duration: pauseDuration,
            type: ShuffleStepType.pause,
            actors: <HandId>[ShuffleHands.hand0, ShuffleHands.hand1],
          ),
        );
        elapsed += pauseDuration;
      }

      final Duration stepDuration = tempoVariedDuration(
        base: repetitionDuration,
        ratio: tempoVariationRatio,
        random: random,
      );

      if (transfersAtRepetition[i]) {
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
      } else {
        // transferでない往復は、feint・cross・moveのいずれかを確率で選ぶ。
        // feint判定を先に行うことで、同じ往復がcross・feint両方になることはない。
        final double roll = random.nextDouble();
        if (roll < feintProbability) {
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
        } else if (roll < feintProbability + crossProbability) {
          steps.add(
            ShuffleStep(
              start: elapsed,
              duration: stepDuration,
              type: ShuffleStepType.cross,
              actors: <HandId>[ShuffleHands.hand0, ShuffleHands.hand1],
            ),
          );
        } else {
          steps.add(
            ShuffleStep(
              start: elapsed,
              duration: stepDuration,
              type: ShuffleStepType.move,
              actors: <HandId>[ShuffleHands.hand0, ShuffleHands.hand1],
            ),
          );
        }
      }
      elapsed += stepDuration;
    }

    return ShuffleStepSequence(
      initialHolder: initialHolder,
      steps: steps,
      finalHolder: currentHolder,
    );
  }
}
