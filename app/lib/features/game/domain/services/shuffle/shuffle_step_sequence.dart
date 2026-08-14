import '../../entities/shuffle_step.dart';
import '../../value_objects/hand_id.dart';

/// 難易度帯ごとの生成戦略が返す、1問分の動作列と開始・終了時の保持手。
///
/// `ShuffleGenerator`がこれを`ShufflePlan`（シードを含む）へ組み立て直す。
class ShuffleStepSequence {
  const ShuffleStepSequence({
    required this.initialHolder,
    required this.steps,
    required this.finalHolder,
  });

  /// シャッフル開始時点でコインを保持している手。
  final HandId initialHolder;

  /// タイムラインを構成する動作の並び。
  final List<ShuffleStep> steps;

  /// シャッフル終了時点でコインを保持している手。
  final HandId finalHolder;
}
