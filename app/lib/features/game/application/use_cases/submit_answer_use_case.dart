import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/answer_result.dart';
import '../../domain/entities/challenge_session.dart';
import '../../domain/services/answer_judge.dart';
import '../../domain/services/shuffle_generator.dart';
import '../../domain/value_objects/game_phase.dart';
import '../../domain/value_objects/hand_id.dart';

/// `SubmitAnswerUseCase`をViewModelへ注入するためのProvider。
final Provider<SubmitAnswerUseCase> submitAnswerUseCaseProvider = Provider<SubmitAnswerUseCase>(
  (ref) => SubmitAnswerUseCase(),
);

/// プレイヤーの回答（または時間切れ）を判定し、チャレンジ状態を更新するユースケース。
class SubmitAnswerUseCase {
  SubmitAnswerUseCase({
    this.judge = const AnswerJudge(),
    this.generator = const ShuffleGenerator(),
    Random? random,
  }) : _random = random ?? Random();

  /// 正解判定を行うドメインサービス。
  final AnswerJudge judge;

  /// 正解時に次レベルのシャッフル計画を生成するために使うドメインサービス。
  final ShuffleGenerator generator;

  final Random _random;

  /// `selectedHand`が`null`の場合は時間切れとして扱う。
  ({ChallengeSession session, AnswerResult result}) call({
    required ChallengeSession session,
    required HandId? selectedHand,
  }) {
    final AnswerResult result = judge.judge(
      correctHand: session.plan.finalHolder,
      selectedHand: selectedHand,
    );

    if (!result.isCorrect) {
      // 不正解・時間切れではレベルを進めず、結果画面へ向かうフェーズにのみ遷移する。
      return (session: session.copyWith(phase: GamePhase.incorrect), result: result);
    }

    // 正解したレベルをクリア済みとして最高到達レベルへ反映してから次レベルへ進む。
    final int clearedLevel = session.level;
    final int nextLevel = clearedLevel + 1;
    final int nextHighestLevel = clearedLevel > session.highestLevel
        ? clearedLevel
        : session.highestLevel;
    final int seed = _random.nextInt(1 << 32);

    return (
      session: session.copyWith(
        level: nextLevel,
        highestLevel: nextHighestLevel,
        plan: generator.planFor(level: nextLevel, seed: seed),
        phase: GamePhase.correct,
      ),
      result: result,
    );
  }
}
