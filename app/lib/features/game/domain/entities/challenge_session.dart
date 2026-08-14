import '../../domain/value_objects/game_phase.dart';
import 'shuffle_plan.dart';

/// 1回の連続チャレンジの実行状態。
class ChallengeSession {
  const ChallengeSession({
    required this.level,
    required this.highestLevel,
    required this.plan,
    required this.phase,
  });

  /// 現在挑戦中のレベル。
  final int level;

  /// このチャレンジでの最高到達レベル。初回のLevel 1で不正解の場合は0。
  final int highestLevel;

  /// 現在のレベルに対応するシャッフル計画。
  final ShufflePlan plan;

  /// 現在のゲーム進行フェーズ。
  final GamePhase phase;

  ChallengeSession copyWith({int? level, int? highestLevel, ShufflePlan? plan, GamePhase? phase}) {
    return ChallengeSession(
      level: level ?? this.level,
      highestLevel: highestLevel ?? this.highestLevel,
      plan: plan ?? this.plan,
      phase: phase ?? this.phase,
    );
  }
}
