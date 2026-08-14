import 'package:app/features/game/domain/value_objects/game_phase.dart';
import 'package:app/features/game/presentation/view_models/game_ui_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameUiState', () {
    test('デフォルトのフェーズはidleになる', () {
      const GameUiState state = GameUiState();

      expect(state.phase, GamePhase.idle);
    });

    test('copyWithで一部フィールドだけ更新できる', () {
      const GameUiState state = GameUiState();
      final GameUiState updated = state.copyWith(phase: GamePhase.confirming);

      expect(updated.phase, GamePhase.confirming);
      expect(state.phase, GamePhase.idle);
    });
  });
}
