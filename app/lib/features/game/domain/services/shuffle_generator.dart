import 'dart:math';

import '../entities/shuffle_plan.dart';
import '../value_objects/difficulty_profile.dart';
import '../value_objects/shuffle_step_type.dart';
import 'difficulty_resolver.dart';
import 'shuffle/cross_feint_step_sequence_builder.dart';
import 'shuffle/left_right_step_sequence_builder.dart';
import 'shuffle/pause_tempo_step_sequence_builder.dart';
import 'shuffle/shuffle_step_sequence.dart';
import 'shuffle_validator.dart';

/// レベルに応じたシャッフル計画を生成するドメインサービス。
///
/// `DifficultyResolver`からレベルごとの`DifficultyProfile`を取得し、
/// `allowedMoves`に応じて`domain/services/shuffle/`配下の生成戦略へ委譲する。
/// 難易度帯別の生成ロジック自体はここに置かず、`ShuffleGenerator`は
/// 戦略の選択、`ShuffleValidator`による検証、シード付き`ShufflePlan`への
/// 組み立てだけを担う。
class ShuffleGenerator {
  const ShuffleGenerator({
    this.resolver = const DifficultyResolver(),
    this.leftRightBuilder = const LeftRightStepSequenceBuilder(),
    this.pauseTempoBuilder = const PauseTempoStepSequenceBuilder(),
    this.crossFeintBuilder = const CrossFeintStepSequenceBuilder(),
    this.validator = const ShuffleValidator(),
    this.maxRegenerationAttempts = 5,
  });

  /// レベルごとの生成条件（`allowedMoves`等）を解決するドメインサービス。
  final DifficultyResolver resolver;

  /// Level 1〜3向け：左右往復のみの生成戦略。
  final LeftRightStepSequenceBuilder leftRightBuilder;

  /// Level 4以上向け：`pause`と緩急を加えた生成戦略。
  final PauseTempoStepSequenceBuilder pauseTempoBuilder;

  /// Level 7以上向け：`cross`・`feint`を加えた生成戦略。
  final CrossFeintStepSequenceBuilder crossFeintBuilder;

  /// 生成した計画が最低限のゲームルールを満たしているかを検証するドメインサービス。
  final ShuffleValidator validator;

  /// 検証に失敗した場合の再生成の試行回数上限。
  ///
  /// 現在の生成戦略は常に検証を満たすように作られているため、通常はこの上限に
  /// 到達しない。無限ループを防ぐための保険として設けている。
  final int maxRegenerationAttempts;

  /// 指定したレベル・シードに対応する、検証済みの`ShufflePlan`を生成する。
  ShufflePlan planFor({required int level, required int seed}) {
    final DifficultyProfile profile = resolver.resolve(level);
    final Random random = Random(seed);

    ShufflePlan plan = _buildPlan(profile: profile, seed: seed, random: random);
    // 同じRandomインスタンスから続けて引くことで、(level, seed)が同じなら
    // 再生成の系列も常に同じになり、再現性を保ったまま別の結果を試せる。
    int attempt = 1;
    while (!validator.isValid(plan) && attempt < maxRegenerationAttempts) {
      plan = _buildPlan(profile: profile, seed: seed, random: random);
      attempt++;
    }

    if (!validator.isValid(plan)) {
      // 通常は生成戦略側の実装が正しい限り到達しない。ここに到達した場合は
      // 生成戦略にバグがあるということなので、不正な計画をPresentation層へ
      // 渡すより早期に気付けるよう例外を投げる。
      throw StateError(
        'ShuffleGenerator: $maxRegenerationAttempts回再生成しても有効なShufflePlanを'
        '生成できませんでした（level: $level, seed: $seed）。生成戦略の実装を確認してください。',
      );
    }

    return plan;
  }

  ShufflePlan _buildPlan({
    required DifficultyProfile profile,
    required int seed,
    required Random random,
  }) {
    // 難易度帯が広い順（cross > pause > 左右移動のみ）に判定する。
    // Level 7以上はpauseも含むため、crossの判定を先に行う必要がある。
    final ShuffleStepSequence sequence;
    if (profile.allowedMoves.contains(ShuffleStepType.cross)) {
      sequence = crossFeintBuilder.build(profile: profile, random: random);
    } else if (profile.allowedMoves.contains(ShuffleStepType.pause)) {
      sequence = pauseTempoBuilder.build(profile: profile, random: random);
    } else {
      sequence = leftRightBuilder.build(profile: profile, random: random);
    }

    return ShufflePlan(
      seed: seed,
      initialHolder: sequence.initialHolder,
      steps: sequence.steps,
      finalHolder: sequence.finalHolder,
    );
  }
}
