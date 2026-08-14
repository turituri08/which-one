import 'dart:math';

import '../../entities/shuffle_step.dart';
import '../../value_objects/difficulty_profile.dart';
import '../../value_objects/hand_id.dart';
import '../../value_objects/shuffle_step_type.dart';
import 'shuffle_hands.dart';
import 'shuffle_random_choices.dart';
import 'shuffle_step_sequence.dart';
import 'shuffle_tempo.dart';

/// Level 4以上向け：`pause`による静止と、`duration`を揺らす緩急を加える生成戦略。
///
/// 一定速度・一定リズムのままだと暗記されやすいため、往復の合間に
/// 短い静止を挟み、移動速度も揺らすことでリズムを読みにくくする。
/// 停止・緩急を加えても、保持手を変更できるのは`transfer`のみという
/// 契約は`LeftRightStepSequenceBuilder`と変わらない。
class PauseTempoStepSequenceBuilder {
  const PauseTempoStepSequenceBuilder({
    this.baseRepetitions = 2,
    this.repetitionIncrementPerLevel = 1,
    this.repetitionDuration = const Duration(milliseconds: 600),
    this.pauseDuration = const Duration(milliseconds: 300),
    this.pauseProbability = 0.35,
    this.tempoVariationRatio = 0.4,
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

  /// `move`/`transfer`の所要時間を基準値からどれだけ揺らすかの比率。
  ///
  /// 例えば0.4なら、基準値の60%〜140%の範囲で速度が変化する。
  /// 値はプレイテストで調整する暫定値であり、本コミットでは確定しない。
  final double tempoVariationRatio;

  ShuffleStepSequence build({required DifficultyProfile profile, required Random random}) {
    final HandId initialHolder = random.nextBool() ? ShuffleHands.hand0 : ShuffleHands.hand1;
    final int repetitions = baseRepetitions + (profile.level - 1) * repetitionIncrementPerLevel;

    final List<bool> transfersAtRepetition = ensureAtLeastOneTrue(
      <bool>[for (int i = 0; i < repetitions; i++) random.nextBool()],
      random,
    );

    // pauseを挟むかどうかも往復ごとに抽選するが、Level 4以上の難易度帯である
    // ことを保証するため最低1回は発生させる。
    final List<bool> pausesBeforeRepetition = ensureAtLeastOneTrue(
      <bool>[for (int i = 0; i < repetitions; i++) random.nextDouble() < pauseProbability],
      random,
    );

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
}
