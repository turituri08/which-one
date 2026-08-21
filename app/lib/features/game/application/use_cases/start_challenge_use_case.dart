import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/challenge_session.dart';
import '../../domain/services/shuffle_generator.dart';
import '../../domain/value_objects/game_phase.dart';

/// `StartChallengeUseCase`をViewModelへ注入するためのProvider。
final Provider<StartChallengeUseCase> startChallengeUseCaseProvider =
    Provider<StartChallengeUseCase>((ref) => StartChallengeUseCase());

/// Level 1からのチャレンジ開始を行うユースケース。
class StartChallengeUseCase {
  StartChallengeUseCase({this.generator = const ShuffleGenerator(), Random? random})
    : _random = random ?? Random();

  /// レベルに応じたシャッフル計画を生成するドメインサービス。
  final ShuffleGenerator generator;

  final Random _random;

  static const int _initialLevel = 1;
  static const int _initialHighestLevel = 0;

  /// Level 1の初期状態（`confirming`へ遷移するための`ChallengeSession`）を構築する。
  ChallengeSession call() {
    final int seed = _random.nextInt(1 << 32);
    return ChallengeSession(
      level: _initialLevel,
      highestLevel: _initialHighestLevel,
      plan: generator.planFor(level: _initialLevel, seed: seed),
      phase: GamePhase.confirming,
    );
  }
}
