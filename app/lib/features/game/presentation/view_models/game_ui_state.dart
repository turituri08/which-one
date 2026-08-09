import '../../domain/entities/answer_result.dart';
import '../../domain/entities/shuffle_plan.dart';
import '../../domain/value_objects/game_phase.dart';

/// `GameViewModel`が公開する不変なUI状態の最小形。
///
/// フェーズが増えるごとに、Commit 4以降でフィールドを拡張する。
class GameUiState {
  const GameUiState({
    this.phase = GamePhase.idle,
    this.level = 0,
    this.highestLevel = 0,
    this.plan,
    this.lastAnswerResult,
  });

  /// 現在のゲーム進行フェーズ。
  final GamePhase phase;

  /// 現在挑戦中のレベル。チャレンジ開始前は0。
  final int level;

  /// このチャレンジでの最高到達レベル。チャレンジ開始前は0。
  final int highestLevel;

  /// 現在のレベルに対応するシャッフル計画。チャレンジ開始前は`null`。
  final ShufflePlan? plan;

  /// 直近の回答判定結果。まだ一度も回答していない場合は`null`。
  final AnswerResult? lastAnswerResult;

  GameUiState copyWith({
    GamePhase? phase,
    int? level,
    int? highestLevel,
    ShufflePlan? plan,
    AnswerResult? lastAnswerResult,
  }) {
    return GameUiState(
      phase: phase ?? this.phase,
      level: level ?? this.level,
      highestLevel: highestLevel ?? this.highestLevel,
      plan: plan ?? this.plan,
      lastAnswerResult: lastAnswerResult ?? this.lastAnswerResult,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameUiState &&
      other.phase == phase &&
      other.level == level &&
      other.highestLevel == highestLevel &&
      other.plan == plan &&
      other.lastAnswerResult == lastAnswerResult;

  @override
  int get hashCode => Object.hash(phase, level, highestLevel, plan, lastAnswerResult);
}
