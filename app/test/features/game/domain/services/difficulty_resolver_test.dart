import 'package:app/features/game/domain/services/difficulty_resolver.dart';
import 'package:app/features/game/domain/value_objects/shuffle_step_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DifficultyResolver', () {
    const DifficultyResolver resolver = DifficultyResolver();

    test('Level 1〜3はmoveとtransferのみ許可する', () {
      for (final int level in <int>[1, 2, 3]) {
        final profile = resolver.resolve(level);

        expect(
          profile.allowedMoves,
          equals(<ShuffleStepType>{ShuffleStepType.move, ShuffleStepType.transfer}),
        );
      }
    });

    test('Level 4〜6はcross・pauseが加わる', () {
      for (final int level in <int>[4, 5, 6]) {
        final profile = resolver.resolve(level);

        expect(
          profile.allowedMoves,
          equals(<ShuffleStepType>{
            ShuffleStepType.move,
            ShuffleStepType.transfer,
            ShuffleStepType.cross,
            ShuffleStepType.pause,
          }),
        );
      }
    });

    test('Level 7〜9はfeintが加わる', () {
      for (final int level in <int>[7, 8, 9]) {
        final profile = resolver.resolve(level);

        expect(
          profile.allowedMoves,
          equals(<ShuffleStepType>{
            ShuffleStepType.move,
            ShuffleStepType.pause,
            ShuffleStepType.cross,
            ShuffleStepType.transfer,
            ShuffleStepType.feint,
          }),
        );
      }
    });

    test('Level 3と4の境界でallowedMovesが切り替わる', () {
      final level3 = resolver.resolve(3);
      final level4 = resolver.resolve(4);

      expect(level3.allowedMoves.contains(ShuffleStepType.pause), isFalse);
      expect(level3.allowedMoves.contains(ShuffleStepType.cross), isFalse);
      expect(level4.allowedMoves.contains(ShuffleStepType.pause), isTrue);
      expect(level4.allowedMoves.contains(ShuffleStepType.cross), isTrue);
    });

    test('Level 6と7の境界でallowedMovesが切り替わる', () {
      final level6 = resolver.resolve(6);
      final level7 = resolver.resolve(7);

      expect(level6.allowedMoves.contains(ShuffleStepType.feint), isFalse);
      expect(level7.allowedMoves.contains(ShuffleStepType.feint), isTrue);
    });

    test('Level 10以上はLevel 7〜9と同じallowedMovesを暫定的に返す', () {
      final level9 = resolver.resolve(9);
      final level10 = resolver.resolve(10);
      final level100 = resolver.resolve(100);

      expect(level10.allowedMoves, equals(level9.allowedMoves));
      expect(level100.allowedMoves, equals(level9.allowedMoves));
    });

    test('全レベルでperformerCountは1に固定される（Phase 2は複数演者を扱わない）', () {
      for (final int level in <int>[1, 3, 4, 6, 7, 9, 10, 50]) {
        expect(resolver.resolve(level).performerCount, equals(1));
      }
    });

    test('level未満1はArgumentErrorになる', () {
      expect(() => resolver.resolve(0), throwsArgumentError);
      expect(() => resolver.resolve(-1), throwsArgumentError);
    });
  });
}
