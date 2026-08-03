import 'package:app/features/game/domain/value_objects/hand_id.dart';
import 'package:app/features/game/domain/value_objects/performer_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HandId', () {
    test('前景の演者はhandIndex 0/1を持てる', () {
      final HandId left = HandId(performerPosition: PerformerPosition.frontCenter, handIndex: 0);
      final HandId right = HandId(performerPosition: PerformerPosition.frontCenter, handIndex: 1);

      expect(left, isNot(equals(right)));
    });

    test('背後の演者はhandIndex 1を持てない', () {
      expect(
        () => HandId(performerPosition: PerformerPosition.rearCenter, handIndex: 1),
        throwsArgumentError,
      );
    });

    test('同じ位置・同じhandIndexは等価になる', () {
      final HandId a = HandId(performerPosition: PerformerPosition.frontLeft, handIndex: 0);
      final HandId b = HandId(performerPosition: PerformerPosition.frontLeft, handIndex: 0);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
