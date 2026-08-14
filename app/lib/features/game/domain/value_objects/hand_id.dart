import 'performer_position.dart';

/// 手を一意に識別する値オブジェクト。
///
/// 前景の演者は`handIndex` 0または1を持てるが、背後の演者は
/// `handIndex` 0のみを持つ。
class HandId {
  HandId({required this.performerPosition, required this.handIndex}) {
    if (performerPosition.isRear && handIndex != 0) {
      throw ArgumentError(
        '背後の演者はhandIndex 0のみ許可されますが、'
        '$performerPositionにhandIndex $handIndexが指定されました。',
      );
    }
    if (handIndex != 0 && handIndex != 1) {
      throw ArgumentError('handIndexは0または1である必要がありますが、$handIndexが指定されました。');
    }
  }

  final PerformerPosition performerPosition;

  /// 同じ演者内での手の番号。前景の演者は0または1、背後の演者は0のみ。
  final int handIndex;

  @override
  bool operator ==(Object other) =>
      other is HandId &&
      other.performerPosition == performerPosition &&
      other.handIndex == handIndex;

  @override
  int get hashCode => Object.hash(performerPosition, handIndex);

  @override
  String toString() => 'HandId($performerPosition, $handIndex)';
}
