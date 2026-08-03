import '../value_objects/hand_id.dart';

/// 回答判定の不変な結果。
class AnswerResult {
  const AnswerResult({
    required this.selectedHand,
    required this.correctHand,
    required this.isCorrect,
    required this.isTimedOut,
  });

  /// プレイヤーが選択した手。時間切れの場合は`null`。
  final HandId? selectedHand;

  /// 実際にコインを保持していた手。
  final HandId correctHand;

  /// 選択した手が正解だったかどうか。
  final bool isCorrect;

  /// 制限時間内に選択されなかったかどうか。
  final bool isTimedOut;
}
