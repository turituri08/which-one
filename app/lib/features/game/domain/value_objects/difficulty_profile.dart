import 'shuffle_step_type.dart';

/// レベルごとの生成条件を表す値オブジェクト。
///
/// `DifficultyResolver`が解決した結果を保持するだけで、
/// 難易度帯の判定ロジック自体は持たない。
class DifficultyProfile {
  DifficultyProfile({
    required this.level,
    required this.performerCount,
    required this.allowedMoves,
  }) {
    if (level < 1) {
      throw ArgumentError('levelは1以上である必要がありますが、$levelが指定されました。');
    }
  }

  /// 対象のレベル番号（1始まり）。
  final int level;

  /// このレベルで登場する演者数。
  ///
  /// Phase 2では複数演者化を扱わないため、常に1になる。
  final int performerCount;

  /// このレベルの難易度帯で使用できる動作プリミティブの集合。
  final Set<ShuffleStepType> allowedMoves;

  @override
  bool operator ==(Object other) =>
      other is DifficultyProfile &&
      other.level == level &&
      other.performerCount == performerCount &&
      _setEquals(other.allowedMoves, allowedMoves);

  @override
  int get hashCode => Object.hash(level, performerCount, Object.hashAllUnordered(allowedMoves));

  @override
  String toString() =>
      'DifficultyProfile(level: $level, performerCount: $performerCount, '
      'allowedMoves: $allowedMoves)';

  static bool _setEquals(Set<ShuffleStepType> a, Set<ShuffleStepType> b) =>
      a.length == b.length && a.containsAll(b);
}
