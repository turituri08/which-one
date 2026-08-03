import '../../domain/value_objects/game_phase.dart';

/// `GameViewModel`が公開する不変なUI状態の最小形。
///
/// フェーズが増えるごとに、Commit 4以降でフィールドを拡張する。
class GameUiState {
  const GameUiState({this.phase = GamePhase.idle});

  /// 現在のゲーム進行フェーズ。
  final GamePhase phase;

  GameUiState copyWith({GamePhase? phase}) {
    return GameUiState(phase: phase ?? this.phase);
  }

  @override
  bool operator ==(Object other) => other is GameUiState && other.phase == phase;

  @override
  int get hashCode => phase.hashCode;
}
