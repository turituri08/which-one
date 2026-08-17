import 'package:flutter/material.dart';

import '../../domain/entities/shuffle_plan.dart';
import '../../domain/value_objects/game_phase.dart';
import '../../domain/value_objects/hand_id.dart';
import '../../domain/value_objects/performer_position.dart';
import '../painters/hands_painter.dart';
import '../view_models/game_ui_state.dart';

/// 2手を描画し、`answering`フェーズでは直接タップで回答できるようにするView。
///
/// 文字ボタンではなく対象そのものをタップさせるため、GestureDetectorを
/// 円と同じステージ座標へ重ねる。`shuffling`フェーズ中は`AnimationController`で
/// `ShufflePlan`の経過時間を進め、`HandsPainter`に渡してアニメーションさせる
/// （初期実装ではFlutter標準の`AnimationController`/`CustomPainter`を使う）。
class HandsView extends StatefulWidget {
  const HandsView({super.key, required this.state, required this.onHandTap});

  final GameUiState state;
  final ValueChanged<HandId> onHandTap;

  /// 誤タップ防止のため、見た目の円より広いタップ領域を確保する。
  static const double _tapAreaSize = 56;

  @override
  State<HandsView> createState() => _HandsViewState();
}

class _HandsViewState extends State<HandsView> with TickerProviderStateMixin {
  // レベルが進むたびに新しいAnimationControllerを作り直すため、
  // 生涯で1個しかTickerを作れないSingleTickerProviderStateMixinは使えない。
  AnimationController? _controller;
  ShufflePlan? _animatingPlan;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant HandsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// `shuffling`フェーズに入ったら計画の尺で`AnimationController`を作って回し、
  /// それ以外のフェーズでは破棄する。同じ計画のまま再度呼ばれても作り直さない。
  void _syncController() {
    final GamePhase phase = widget.state.phase;
    final ShufflePlan? plan = widget.state.plan;

    if (phase != GamePhase.shuffling || plan == null) {
      _controller?.dispose();
      _controller = null;
      _animatingPlan = null;
      return;
    }

    if (identical(_animatingPlan, plan) && _controller != null) {
      return;
    }

    _controller?.dispose();
    final Duration duration = plan.totalDuration > Duration.zero
        ? plan.totalDuration
        : const Duration(milliseconds: 1);
    _controller = AnimationController(vsync: this, duration: duration)
      ..addListener(() => setState(() {}))
      ..forward();
    _animatingPlan = plan;
  }

  @override
  Widget build(BuildContext context) {
    final GameUiState state = widget.state;
    final bool canAnswer = state.phase == GamePhase.answering;
    // コインの保持位置は確認フェーズだけ明示し、シャッフル・回答中は隠す。
    final int? coinHolderHandIndex = state.phase == GamePhase.confirming
        ? state.plan?.initialHolder.handIndex
        : null;
    final bool isShuffling = state.phase == GamePhase.shuffling && _controller != null;
    final Duration elapsed = isShuffling
        ? state.plan!.totalDuration * _controller!.value
        : Duration.zero;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        return Stack(
          children: <Widget>[
            CustomPaint(
              size: size,
              painter: HandsPainter(
                coinHolderHandIndex: coinHolderHandIndex,
                plan: isShuffling ? state.plan : null,
                elapsed: elapsed,
              ),
            ),
            for (final int handIndex in <int>[0, 1]) _buildTapTarget(size, handIndex, canAnswer),
          ],
        );
      },
    );
  }

  Widget _buildTapTarget(Size size, int handIndex, bool canAnswer) {
    final Offset stagePosition = HandsPainter.stagePositionFor(handIndex);
    final Offset center = Offset(stagePosition.dx * size.width, stagePosition.dy * size.height);
    return Positioned(
      left: center.dx - HandsView._tapAreaSize / 2,
      top: center.dy - HandsView._tapAreaSize / 2,
      width: HandsView._tapAreaSize,
      height: HandsView._tapAreaSize,
      child: GestureDetector(
        key: ValueKey<String>('hand-tap-$handIndex'),
        behavior: HitTestBehavior.opaque,
        // answering以外はタップを受け付けない（装飾扱いにする）。
        onTap: canAnswer
            ? () => widget.onHandTap(
                HandId(performerPosition: PerformerPosition.frontCenter, handIndex: handIndex),
              )
            : null,
        child: const SizedBox.shrink(),
      ),
    );
  }
}
