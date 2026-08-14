import '../value_objects/hand_id.dart';
import '../value_objects/shuffle_step_type.dart';

/// シャッフルタイムライン上の原子的な動作。
class ShuffleStep {
  const ShuffleStep({
    required this.start,
    required this.duration,
    required this.type,
    required this.actors,
    this.parameters = const <String, Object?>{},
  });

  /// タイムライン開始からの経過時間。
  final Duration start;

  /// この動作の所要時間。
  final Duration duration;

  /// この動作の種別。
  final ShuffleStepType type;

  /// この動作に関与する手。
  final List<HandId> actors;

  /// 軌道の形状など、動作固有の追加パラメータ。
  final Map<String, Object?> parameters;

  Duration get end => start + duration;
}
