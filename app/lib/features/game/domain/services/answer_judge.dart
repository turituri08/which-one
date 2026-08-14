import '../entities/answer_result.dart';
import '../value_objects/hand_id.dart';

/// 選択された手が正解かどうかを判定するドメインサービス。
class AnswerJudge {
  const AnswerJudge();

  /// `selectedHand`が`null`の場合は時間切れとして扱う。
  AnswerResult judge({required HandId correctHand, required HandId? selectedHand}) {
    final bool isTimedOut = selectedHand == null;
    return AnswerResult(
      selectedHand: selectedHand,
      correctHand: correctHand,
      isCorrect: !isTimedOut && selectedHand == correctHand,
      isTimedOut: isTimedOut,
    );
  }
}
