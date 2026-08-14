import '../value_objects/hand_id.dart';
import 'shuffle_step.dart';

/// 1問分の再現可能な動作列。
class ShufflePlan {
  const ShufflePlan({
    required this.seed,
    required this.initialHolder,
    required this.steps,
    required this.finalHolder,
  });

  /// 再現テストと将来のオンライン検証に備えて保持する乱数シード。
  final int seed;

  /// シャッフル開始時点でコインを保持している手。
  final HandId initialHolder;

  /// タイムラインを構成する動作の並び。
  final List<ShuffleStep> steps;

  /// シャッフル終了時点でコインを保持している手。
  final HandId finalHolder;

  /// シャッフルタイムライン全体の所要時間。
  ///
  /// `shuffling`フェーズは、この時間が経過した時点で自動的に
  /// `answering`へ進む。
  Duration get totalDuration {
    if (steps.isEmpty) {
      return Duration.zero;
    }
    return steps
        .map((ShuffleStep step) => step.end)
        .reduce((Duration a, Duration b) => a > b ? a : b);
  }
}
