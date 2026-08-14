import 'dart:math';

import '../entities/shuffle_plan.dart';
import '../entities/shuffle_step.dart';
import '../value_objects/hand_id.dart';
import '../value_objects/performer_position.dart';
import '../value_objects/shuffle_step_type.dart';

/// Level共通の左右移動シャッフルを生成するドメインサービス。
///
/// Phase 1では演者1人・手2本の左右移動パターンのみを扱い、
/// レベルが上がるほど往復回数（シャッフルの尺）を伸ばす。
/// 終了時の保持手は開始時と同じ／異なるの両方があり得るようにし、
/// 「開始手には戻らない」といった固定パターンを学習されないようにする。
/// `cross`や`feint`などの複雑な動作種別はPhase 2以降で追加する。
class LevelShufflePlanner {
  const LevelShufflePlanner({
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

  /// 指定したレベル・シードに対応する`ShufflePlan`を生成する。
  ///
  /// 各往復ごとにコインを持ち替える（`transfer`）かどうかを抽選するため、
  /// 終了時の保持手は開始時と同じ場合も異なる場合もあり得る。
  /// 「開始手には戻らない」という固定パターンをプレイヤーに学習されると
  /// 観察せずに正解できてしまうため、意図的に両方の結果を許容している。
  /// ただし何も動かないと退屈なので、最低1回は`transfer`を発生させる。
  ShufflePlan planFor({required int level, required int seed}) {
    final HandId hand0 = HandId(performerPosition: PerformerPosition.frontCenter, handIndex: 0);
    final HandId hand1 = HandId(performerPosition: PerformerPosition.frontCenter, handIndex: 1);

    final Random random = Random(seed);
    final HandId initialHolder = random.nextBool() ? hand0 : hand1;

    // 左右往復の回数。レベルが上がるほど増え、シャッフルの尺が伸びる。
    final int repetitions = baseRepetitions + (level - 1) * repetitionIncrementPerLevel;

    // 各往復でコインを持ち替えるかどうかを個別に抽選する。
    final List<bool> transfersAtRepetition = <bool>[
      for (int i = 0; i < repetitions; i++) random.nextBool(),
    ];
    // 一度も持ち替えないとシャッフルとして機能しないため、最低1回は保証する。
    if (!transfersAtRepetition.contains(true)) {
      transfersAtRepetition[random.nextInt(repetitions)] = true;
    }

    final List<ShuffleStep> steps = <ShuffleStep>[];
    // 往復を進めながら、その時点の保持手を追跡する。
    HandId currentHolder = initialHolder;
    for (int i = 0; i < repetitions; i++) {
      if (transfersAtRepetition[i]) {
        final HandId nextHolder = currentHolder == hand0 ? hand1 : hand0;
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
            actors: <HandId>[hand0, hand1],
          ),
        );
      }
    }

    return ShufflePlan(
      seed: seed,
      initialHolder: initialHolder,
      steps: steps,
      finalHolder: currentHolder,
    );
  }
}
