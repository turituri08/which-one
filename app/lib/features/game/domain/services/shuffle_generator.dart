import 'dart:math';

import '../entities/shuffle_plan.dart';
import '../value_objects/difficulty_profile.dart';
import '../value_objects/shuffle_step_type.dart';
import 'difficulty_resolver.dart';
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
  });

  /// レベルごとの生成条件（`allowedMoves`等）を解決するドメインサービス。
  final DifficultyResolver resolver;

  /// Level 1〜3向け：左右往復のみの生成戦略。
  final LeftRightStepSequenceBuilder leftRightBuilder;

  /// Level 4以上向け：`pause`と緩急を加えた生成戦略。
  final PauseTempoStepSequenceBuilder pauseTempoBuilder;

  /// 指定したレベル・シードに対応する`ShufflePlan`を生成する。
  ShufflePlan planFor({required int level, required int seed}) {
    final DifficultyProfile profile = resolver.resolve(level);
    final Random random = Random(seed);

    // pauseが解禁されている難易度帯（Level 4以上）かどうかで生成戦略を切り替える。
    // cross/feintを使う戦略は後続のコミットで同様に分岐を追加する。
    final ShuffleStepSequence sequence = profile.allowedMoves.contains(ShuffleStepType.pause)
        ? pauseTempoBuilder.build(profile: profile, random: random)
        : leftRightBuilder.build(profile: profile, random: random);

    return ShufflePlan(
      seed: seed,
      initialHolder: sequence.initialHolder,
      steps: sequence.steps,
      finalHolder: sequence.finalHolder,
    );
  }
}
