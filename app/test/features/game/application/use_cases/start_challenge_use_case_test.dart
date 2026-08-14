import 'dart:math';

import 'package:app/features/game/application/use_cases/start_challenge_use_case.dart';
import 'package:app/features/game/domain/entities/challenge_session.dart';
import 'package:app/features/game/domain/value_objects/game_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartChallengeUseCase', () {
    test('Level 1・highestLevel 0・confirmingで開始する', () {
      final StartChallengeUseCase useCase = StartChallengeUseCase(random: Random(1));

      final ChallengeSession session = useCase();

      expect(session.level, 1);
      expect(session.highestLevel, 0);
      expect(session.phase, GamePhase.confirming);
      expect(session.plan.steps, isNotEmpty);
    });

    test('同じシードのRandomを渡すと同じ計画が再現される', () {
      final ChallengeSession a = StartChallengeUseCase(random: Random(7))();
      final ChallengeSession b = StartChallengeUseCase(random: Random(7))();

      expect(a.plan.initialHolder, equals(b.plan.initialHolder));
      expect(a.plan.finalHolder, equals(b.plan.finalHolder));
    });
  });
}
