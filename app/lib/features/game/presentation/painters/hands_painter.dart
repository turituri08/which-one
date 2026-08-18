import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/shuffle_plan.dart';
import '../../domain/entities/shuffle_step.dart';
import '../../domain/value_objects/shuffle_step_type.dart';

/// 手を円のプレースホルダーとして描画するPainter。
///
/// Phase 1では演者1人・手2本の固定位置のみを扱う。Phase 2ではこれに加え、
/// シャッフル中の経過時間から現在アクティブな`ShuffleStep`を求め、
/// その種別（move/pause/cross/transfer/feint）に応じて手の位置を変化させる。
///
/// `move`で移動した先や`cross`/`transfer`で入れ替わった位置は、次にその手の
/// 位置を変える動作（`move`/`cross`/`transfer`）が起きるまで、複数stepに
/// またがって持続する。`shuffling`フェーズが終わると、`returnProgress`に
/// 応じて基準位置（`stagePositionFor`）へ滑らかに戻る（＝プレイヤーに回答を
/// 求める瞬間、パッと消えず追える速さで元の位置へ戻る）。色・軌道の具体的な
/// 表現はRive導入前の暫定実装であり、Phase 3で作り直される前提とする。
class HandsPainter extends CustomPainter {
  const HandsPainter({
    required this.coinHolderHandIndex,
    this.plan,
    this.elapsed = Duration.zero,
    this.returnProgress = 0.0,
  });

  /// コインを保持している手のindex（0または1）。表示しない場合はnull。
  ///
  /// コイン確認フェーズ以外はnullを渡し、保持位置を隠す。
  final int? coinHolderHandIndex;

  /// アニメーションの基準にするシャッフル計画。
  ///
  /// `shuffling`中はそのままのプランを、`shuffling`終了直後の「基準位置へ
  /// 戻る」演出中は直前まで使っていたプランを渡し続ける（`returnProgress`で
  /// 見た目を基準位置側へ寄せる）。それ以外のフェーズではnull。
  final ShufflePlan? plan;

  /// シャッフル開始からの経過時間。`plan`がnullの場合は使われない。
  ///
  /// 「基準位置へ戻る」演出中は、シャッフル終了時点（`plan.totalDuration`）で
  /// 固定した値を渡す想定。
  final Duration elapsed;

  /// 基準位置へ戻る演出の進捗（0.0＝シャッフル中の位置のまま、1.0＝完全に
  /// 基準位置）。`shuffling`フェーズ中は常に0.0を渡す。
  final double returnProgress;

  static const double radiusRatio = 0.12;

  // moveで手が移動できるステージ範囲（画面端に寄りすぎないよう余白を持たせる）。
  // cross/transfer/feintの往復（2手の位置を結ぶ軌道）とは別に、画面全体を
  // 使って大きく動かすことで「意味のある動き」に見えるようにする。
  static const double _moveMinX = 0.12;
  static const double _moveMaxX = 0.88;
  static const double _moveMinY = 0.15;
  static const double _moveMaxY = 0.85;

  // feintが相手側へ近づく際の到達率（1.0で完全に重なる）。
  // 「重なる直前で引き返す」ことを表すため1.0未満にする。
  static const double _feintReachRatio = 0.7;

  // transferが中間地点（接触点）で静止する時間。「コインを渡している」ことを
  // 示す間。stepの所要時間が短い場合はこの値より短く自動的に切り詰められる。
  static const Duration _transferHoldDuration = Duration(milliseconds: 250);

  /// 手indexに対応する正規化ステージ座標（0.0〜1.0）。
  ///
  /// `shuffling`フェーズ以外（confirming/answering等）や、`shuffling`開始前は
  /// この位置を基準に描画・タップ判定を行う。
  static Offset stagePositionFor(int handIndex) =>
      handIndex == 0 ? const Offset(0.3, 0.5) : const Offset(0.7, 0.5);

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.shortestSide * radiusRatio;
    final Paint fillPaint = Paint()..color = Colors.white;

    final int? activeStepIndex = _activeStepIndexAt(elapsed);
    final ShuffleStep? activeStep = activeStepIndex == null ? null : plan!.steps[activeStepIndex];
    final Duration elapsedInStep = activeStep == null ? Duration.zero : elapsed - activeStep.start;
    // activeStepIndexがnullなのは「planがない」か「シャッフルの尺を過ぎた」かの
    // どちらか。後者では、そこまでに持続していた位置（全stepを辿った結果）を
    // 使う必要があるため、単純に基準位置へフォールバックしてはいけない。
    final (Offset before0, Offset before1) = plan == null
        ? (stagePositionFor(0), stagePositionFor(1))
        : _positionsBeforeStep(activeStepIndex ?? plan!.steps.length);

    for (final int handIndex in <int>[0, 1]) {
      final Offset shuffleStagePosition = _animatedStagePosition(
        handIndex: handIndex,
        stepIndex: activeStepIndex,
        step: activeStep,
        elapsedInStep: elapsedInStep,
        before: handIndex == 0 ? before0 : before1,
        otherBefore: handIndex == 0 ? before1 : before0,
      );
      // returnProgressが0より大きい間は、シャッフル中の位置から基準位置へ
      // 滑らかに寄せる（「回答を求める瞬間にパッと消える」ことを防ぐ）。
      final Offset stagePosition = returnProgress <= 0
          ? shuffleStagePosition
          : Offset.lerp(shuffleStagePosition, stagePositionFor(handIndex), returnProgress)!;
      final Offset center = Offset(stagePosition.dx * size.width, stagePosition.dy * size.height);
      // デバッグ用に、どちらの手（actor）かを縁の色で区別する
      // （hand0=青、hand1=赤）。本番の見た目はRive導入後に作り直す。
      final Paint strokePaint = Paint()
        ..color = handIndex == 0 ? Colors.blue : Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius, strokePaint);

      if (coinHolderHandIndex == handIndex) {
        // コイン確認フェーズでのみ保持手を明示する。
        canvas.drawCircle(center, radius * 0.3, Paint()..color = Colors.black87);
      }
    }
  }

  Offset _animatedStagePosition({
    required int handIndex,
    required int? stepIndex,
    required ShuffleStep? step,
    required Duration elapsedInStep,
    required Offset before,
    required Offset otherBefore,
  }) {
    switch (step?.type) {
      case null:
      case ShuffleStepType.pause:
        // 停止：何も動かさず、リズムを切ることを表す。
        return before;
      case ShuffleStepType.move:
        // 移動：画面内の新しい位置まで大きく動く。到達した位置は、次に
        // その手が動く（move/cross/transfer）まで持続する。
        final Offset target = _moveTargetFor(stepIndex: stepIndex!, handIndex: handIndex);
        final double progress = _progress(step!, elapsedInStep);
        return Offset.lerp(before, target, progress)!;
      case ShuffleStepType.cross:
        // 交差：相手の位置まで進み、そのまま入れ替わって終わる。
        // 入れ替わった位置は次にその手が動くまで、または今回のshuffling
        // フェーズが終わるまで持続する。
        final double progress = _progress(step!, elapsedInStep);
        return Offset.lerp(before, otherBefore, progress)!;
      case ShuffleStepType.feint:
        // フェイント：crossと同じ軌道だが、重なる手前（_feintReachRatio）で
        // 自分の位置へ引き返す。位置は入れ替わらない
        // （「本当の受け渡しではなかった」と事後に理解できる動き）。
        final double progress = _progress(step!, elapsedInStep);
        return Offset.lerp(before, otherBefore, _pingPong(progress) * _feintReachRatio)!;
      case ShuffleStepType.transfer:
        // 受け渡し：中間地点（接触点）まで進んで少し静止し
        // （コインを渡している間を表す）、その後相手の位置まで進んで終わる
        // （位置が入れ替わる）。
        return _transferPosition(step!, elapsedInStep, before, otherBefore);
      case ShuffleStepType.exitStage:
      case ShuffleStepType.enterStage:
        // Phase 2では未使用（画面外移動はPhase 5で扱う）。
        return before;
    }
  }

  /// stepIndex番目のstepが始まる直前の、hand0・hand1の位置を求める。
  ///
  /// `move`は新しい位置へ、`cross`/`transfer`は2手の位置を入れ替える形で
  /// 持続的に位置を変えるため、履歴を先頭から辿って再現する。
  (Offset, Offset) _positionsBeforeStep(int stepIndex) {
    Offset pos0 = stagePositionFor(0);
    Offset pos1 = stagePositionFor(1);
    for (int i = 0; i < stepIndex; i++) {
      switch (plan!.steps[i].type) {
        case ShuffleStepType.move:
          pos0 = _moveTargetFor(stepIndex: i, handIndex: 0);
          pos1 = _moveTargetFor(stepIndex: i, handIndex: 1);
        case ShuffleStepType.cross:
        case ShuffleStepType.transfer:
          final Offset swapped = pos0;
          pos0 = pos1;
          pos1 = swapped;
        case ShuffleStepType.pause:
        case ShuffleStepType.feint:
        case ShuffleStepType.exitStage:
        case ShuffleStepType.enterStage:
        // 位置を変えない動作。
      }
    }
    return (pos0, pos1);
  }

  /// `stepIndex`番目の`move`で`handIndex`が向かう先のステージ座標。
  ///
  /// `plan.seed`とstep・手のインデックスから決めるため、同じ計画なら
  /// 常に同じ位置になる（再現性を保ちつつ、往復ごとに異なる位置へ動く）。
  Offset _moveTargetFor({required int stepIndex, required int handIndex}) {
    final Random random = Random(plan!.seed ^ (stepIndex * 31 + handIndex));
    final double x = _moveMinX + random.nextDouble() * (_moveMaxX - _moveMinX);
    final double y = _moveMinY + random.nextDouble() * (_moveMaxY - _moveMinY);
    return Offset(x, y);
  }

  /// `transfer`の3段階（接近・接触点で静止・完了）の位置を、実時間に沿って求める。
  Offset _transferPosition(
    ShuffleStep step,
    Duration elapsedInStep,
    Offset before,
    Offset otherBefore,
  ) {
    final Offset contactPoint = Offset.lerp(before, otherBefore, 0.5)!;

    // stepが短い場合に静止時間だけで使い切ってしまわないよう、
    // stepの所要時間の半分を上限にして切り詰める。
    final int cappedHoldMicros = min(
      _transferHoldDuration.inMicroseconds,
      step.duration.inMicroseconds ~/ 2,
    );
    final Duration cappedHold = Duration(microseconds: cappedHoldMicros);
    final Duration remaining = step.duration - cappedHold;
    final Duration approachDuration = remaining ~/ 2;
    final Duration completeDuration = remaining - approachDuration;

    if (elapsedInStep < approachDuration) {
      return Offset.lerp(before, contactPoint, _ratio(elapsedInStep, approachDuration))!;
    }
    if (elapsedInStep < approachDuration + cappedHold) {
      return contactPoint;
    }
    final Duration intoComplete = elapsedInStep - approachDuration - cappedHold;
    return Offset.lerp(contactPoint, otherBefore, _ratio(intoComplete, completeDuration))!;
  }

  /// 0→1→0（往復）の三角波。`progress`が0.5のとき最大値1.0になる。
  double _pingPong(double progress) => 1 - (progress * 2 - 1).abs();

  double _progress(ShuffleStep step, Duration elapsedInStep) =>
      _ratio(elapsedInStep, step.duration);

  double _ratio(Duration elapsed, Duration total) {
    if (total <= Duration.zero) {
      return 1;
    }
    return (elapsed.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
  }

  int? _activeStepIndexAt(Duration time) {
    final List<ShuffleStep>? steps = plan?.steps;
    if (steps == null) {
      return null;
    }
    for (int i = 0; i < steps.length; i++) {
      final ShuffleStep step = steps[i];
      if (time >= step.start && time < step.end) {
        return i;
      }
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant HandsPainter oldDelegate) =>
      oldDelegate.coinHolderHandIndex != coinHolderHandIndex ||
      oldDelegate.plan != plan ||
      oldDelegate.elapsed != elapsed ||
      oldDelegate.returnProgress != returnProgress;
}
