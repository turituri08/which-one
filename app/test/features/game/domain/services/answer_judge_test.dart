import 'package:app/features/game/domain/services/answer_judge.dart';
import 'package:app/features/game/domain/value_objects/hand_id.dart';
import 'package:app/features/game/domain/value_objects/performer_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnswerJudge', () {
    const AnswerJudge judge = AnswerJudge();
    final HandId correctHand = HandId(
      performerPosition: PerformerPosition.frontCenter,
      handIndex: 0,
    );
    final HandId wrongHand = HandId(performerPosition: PerformerPosition.frontCenter, handIndex: 1);

    test('選択した手が正解の手と一致すれば正解になる', () {
      final result = judge.judge(correctHand: correctHand, selectedHand: correctHand);

      expect(result.isCorrect, isTrue);
      expect(result.isTimedOut, isFalse);
    });

    test('選択した手が正解の手と異なれば不正解になる', () {
      final result = judge.judge(correctHand: correctHand, selectedHand: wrongHand);

      expect(result.isCorrect, isFalse);
      expect(result.isTimedOut, isFalse);
    });

    test('選択がnullなら時間切れとして不正解になる', () {
      final result = judge.judge(correctHand: correctHand, selectedHand: null);

      expect(result.isCorrect, isFalse);
      expect(result.isTimedOut, isTrue);
    });
  });
}
