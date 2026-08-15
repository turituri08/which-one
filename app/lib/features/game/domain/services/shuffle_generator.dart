import 'dart:math';

import '../entities/shuffle_plan.dart';
import '../value_objects/difficulty_profile.dart';
import '../value_objects/shuffle_step_type.dart';
import 'difficulty_resolver.dart';
import 'shuffle/cross_feint_step_sequence_builder.dart';
import 'shuffle/left_right_step_sequence_builder.dart';
import 'shuffle/pause_tempo_step_sequence_builder.dart';
import 'shuffle/shuffle_step_sequence.dart';

/// レベルに応じたシャッフル計画を生成するドメインサービス。
///
/// `DifficultyResolver`からレベルごとの`DifficultyProfile`を取得し、
/// `allowedMoves`に応じて`domain/services/shuffle/`配下の生成戦略へ委譲する。
/// 難易度帯別の生成ロジック自体はここに置かず、`ShuffleGenerator`は
/// 戦略の選択とシード付き`ShufflePlan`への組み立てだけを担う。
class ShuffleGenerator {
  const ShuffleGenerator({
    this.resolver = const DifficultyResolver(),
    this.leftRightBuilder = const LeftRightStepSequenceBuilder(),
    this.pauseTempoBuilder = const PauseTempoStepSequenceBuilder(),
    this.crossFeintBuilder = const CrossFeintStepSequenceBuilder(),
  });

  /// レベルごとの生成条件（`allowedMoves`等）を解決するドメインサービス。
  final DifficultyResolver resolver;

  /// Level 1〜3向け：左右往復のみの生成戦略。
  final LeftRightStepSequenceBuilder leftRightBuilder;

  /// Level 4以上向け：`pause`と緩急を加えた生成戦略。
  final PauseTempoStepSequenceBuilder pauseTempoBuilder;

  /// Level 7以上向け：`cross`・`feint`を加えた生成戦略。
  final CrossFeintStepSequenceBuilder crossFeintBuilder;

  /// 指定したレベル・シードに対応する`ShufflePlan`を生成する。
  ShufflePlan planFor({required int level, required int seed}) {
    final DifficultyProfile profile = resolver.resolve(level);
    final Random random = Random(seed);

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
