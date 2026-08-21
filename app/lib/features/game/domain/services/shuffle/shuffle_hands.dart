import '../../value_objects/hand_id.dart';
import '../../value_objects/performer_position.dart';

/// Phase 2で使う演者1人・手2本の固定ハンド定義。
///
/// 複数演者化を扱うまでは、シャッフル生成戦略はすべてこの2本の手だけを操作する。
class ShuffleHands {
  ShuffleHands._();

  static final HandId hand0 = HandId(
    performerPosition: PerformerPosition.frontCenter,
    handIndex: 0,
  );

  static final HandId hand1 = HandId(
    performerPosition: PerformerPosition.frontCenter,
    handIndex: 1,
  );
}
