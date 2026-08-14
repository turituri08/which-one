import 'dart:math';

import 'package:app/features/game/application/use_cases/start_challenge_use_case.dart';
import 'package:app/features/game/application/use_cases/submit_answer_use_case.dart';
import 'package:app/features/game/domain/entities/challenge_session.dart';
import 'package:app/features/game/domain/value_objects/game_phase.dart';
import 'package:app/features/game/domain/value_objects/hand_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubmitAnswerUseCase', () {
    late ChallengeSession initialSession;

    setUp(() {
      initialSession = StartChallengeUseCase(random: Random(1))();
    });

    test('正解するとcorrectへ遷移し、レベルと最高到達レベルが更新される', () {
      final SubmitAnswerUseCase useCase = SubmitAnswerUseCase(random: Random(2));

      final result = useCase(
        session: initialSession,
        selectedHand: initialSession.plan.finalHolder,
      );

      expect(result.result.isCorrect, isTrue);
      expect(result.session.phase, GamePhase.correct);
      expect(result.session.level, initialSession.level + 1);
      expect(result.session.highestLevel, initialSession.level);
    });

    test('不正解の場合はincorrectへ遷移し、レベルは進まない', () {
      final SubmitAnswerUseCase useCase = SubmitAnswerUseCase();
      final HandId correctHand = initialSession.plan.finalHolder;
      final HandId wrongHand = HandId(
        performerPosition: correctHand.performerPosition,
        handIndex: correctHand.handIndex == 0 ? 1 : 0,
      );

      final result = useCase(session: initialSession, selectedHand: wrongHand);

      expect(result.result.isCorrect, isFalse);
      expect(result.result.isTimedOut, isFalse);
      expect(result.session.phase, GamePhase.incorrect);
      expect(result.session.level, initialSession.level);
      expect(result.session.highestLevel, initialSession.highestLevel);
    });

    test('時間切れの場合はincorrectへ遷移し、レベルは進まない', () {
      final SubmitAnswerUseCase useCase = SubmitAnswerUseCase();

      final result = useCase(session: initialSession, selectedHand: null);

      expect(result.result.isCorrect, isFalse);
      expect(result.result.isTimedOut, isTrue);
      expect(result.session.phase, GamePhase.incorrect);
      expect(result.session.level, initialSession.level);
      expect(result.session.highestLevel, initialSession.highestLevel);
    });
  });
}
