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
/// `cross`/`transfer`で入れ替わった左右の位置は、次に`cross`/`transfer`が
/// 起きるまで（＝複数stepにまたがって）維持される。`shuffling`フェーズが
/// 終わる（`plan`がnullになる）と、必ず`stagePositionFor`の基準位置の表示に
/// 戻る。色・軌道の具体的な表現はRive導入前の暫定実装であり、Phase 3で
/// 作り直される前提とする。
class HandsPainter extends CustomPainter {
  const HandsPainter({required this.coinHolderHandIndex, this.plan, this.elapsed = Duration.zero});

  /// コインを保持している手のindex（0または1）。表示しない場合はnull。
  ///
  /// コイン確認フェーズ以外はnullを渡し、保持位置を隠す。
  final int? coinHolderHandIndex;

  /// アニメーションの基準にするシャッフル計画。`shuffling`フェーズ中以外はnull。
  final ShufflePlan? plan;

  /// シャッフル開始からの経過時間。`plan`がnullの場合は使われない。
  final Duration elapsed;

  static const double radiusRatio = 0.12;

  // moveの上下バウンス幅・左右の弧の幅（ステージ座標比）。
  // cross/transfer/feintの往復幅よりずっと小さくし、交差とは紛れないようにする。
  static const double _moveBounceAmplitude = 0.03;
  static const double _moveDriftAmplitude = 0.02;

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
    final Paint strokePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final int? activeStepIndex = _activeStepIndexAt(elapsed);
    final ShuffleStep? activeStep = activeStepIndex == null ? null : plan!.steps[activeStepIndex];
    final Duration elapsedInStep = activeStep == null ? Duration.zero : elapsed - activeStep.start;

    for (final int handIndex in <int>[0, 1]) {
      final Offset center = _animatedCenter(handIndex, size, activeStepIndex, activeStep, elapsedInStep);
      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius, strokePaint);

      if (coinHolderHandIndex == handIndex) {
        // コイン確認フェーズでのみ保持手を明示する。
        canvas.drawCircle(center, radius * 0.3, Paint()..color = Colors.black87);
      }
    }
  }

  Offset _animatedCenter(
    int handIndex,
    Size size,
    int? activeStepIndex,
    ShuffleStep? step,
    Duration elapsedInStep,
  ) {
    // その時点までにcross/transferが何回起きたかを積み上げ、
    // 「今、画面のどちら側にいるか」を求める（複数stepにまたがって持続する）。
    final bool swapped = activeStepIndex == null ? false : _isSwappedBefore(activeStepIndex);
    final int effectiveIndex = swapped ? 1 - handIndex : handIndex;
    final Offset base = stagePositionFor(effectiveIndex);
    final Offset other = stagePositionFor(1 - effectiveIndex);

    Offset stagePosition;
    switch (step?.type) {
      case null:
      case ShuffleStepType.pause:
        // 停止：何も動かさず、リズムを切ることを表す。
        stagePosition = base;
      case ShuffleStepType.move:
        // 移動：小さな弧を描くように上下・左右へ揺らし、
        // 「停止ではなく動いている」ことを示す（直線・曲線・上下移動の暫定表現）。
        final double progress = _progress(step!, elapsedInStep);
        final double bounce = sin(pi * progress) * _moveBounceAmplitude;
        final double drift = sin(2 * pi * progress) * _moveDriftAmplitude;
        stagePosition = Offset(base.dx + drift, base.dy - bounce);
      case ShuffleStepType.cross:
        // 交差：相手側まで進み、そのまま重なって終わる（左右が入れ替わる）。
        // 入れ替わった位置は次のcross/transferまで、または今回のshuffling
        // フェーズが終わるまで持続する。
        final double progress = _progress(step!, elapsedInStep);
        stagePosition = Offset.lerp(base, other, progress)!;
      case ShuffleStepType.feint:
        // フェイント：crossと同じ軌道だが、重なる手前（_feintReachRatio）で
        // 自分の位置へ引き返す。位置は入れ替わらない
        // （「本当の受け渡しではなかった」と事後に理解できる動き）。
        final double progress = _progress(step!, elapsedInStep);
        stagePosition = Offset.lerp(base, other, _pingPong(progress) * _feintReachRatio)!;
      case ShuffleStepType.transfer:
        // 受け渡し：中間地点（接触点）まで進んで少し静止し
        // （コインを渡している間を表す）、その後相手側まで進んで終わる
        // （左右が入れ替わる）。
        stagePosition = _transferPosition(step!, elapsedInStep, base, other);
      case ShuffleStepType.exitStage:
      case ShuffleStepType.enterStage:
        // Phase 2では未使用（画面外移動はPhase 5で扱う）。
        stagePosition = base;
    }
    return Offset(stagePosition.dx * size.width, stagePosition.dy * size.height);
  }

  /// `transfer`の3段階（接近・接触点で静止・完了）の位置を、実時間に沿って求める。
  Offset _transferPosition(ShuffleStep step, Duration elapsedInStep, Offset base, Offset other) {
    final Offset contactPoint = Offset.lerp(base, other, 0.5)!;

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
      return Offset.lerp(base, contactPoint, _ratio(elapsedInStep, approachDuration))!;
    }
    if (elapsedInStep < approachDuration + cappedHold) {
      return contactPoint;
    }
    final Duration intoComplete = elapsedInStep - approachDuration - cappedHold;
    return Offset.lerp(contactPoint, other, _ratio(intoComplete, completeDuration))!;
  }

  /// stepインデックス`stepIndex`より前に、cross/transferが奇数回起きていれば
  /// 左右が入れ替わった状態になっている。
  bool _isSwappedBefore(int stepIndex) {
    final List<ShuffleStep> steps = plan!.steps;
    bool swapped = false;
    for (int i = 0; i < stepIndex; i++) {
      final ShuffleStepType type = steps[i].type;
      if (type == ShuffleStepType.cross || type == ShuffleStepType.transfer) {
        swapped = !swapped;
      }
    }
    return swapped;
  }

  /// 0→1→0（往復）の三角波。`progress`が0.5のとき最大値1.0になる。
  double _pingPong(double progress) => 1 - (progress * 2 - 1).abs();

  double _progress(ShuffleStep step, Duration elapsedInStep) => _ratio(elapsedInStep, step.duration);

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
      oldDelegate.elapsed != elapsed;
}
