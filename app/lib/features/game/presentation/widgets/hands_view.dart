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
/// `shuffling`が終わった直後は、別の`AnimationController`で基準位置へ
/// 滑らかに戻す演出を挟む（パッと消えると保持手を追えなくなるため）。
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

  // shuffling終了直後に、基準位置へ戻る演出を担うController。
  AnimationController? _returnController;
  ShufflePlan? _returningFromPlan;

  static const Duration _returnDuration = Duration(milliseconds: 500);

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
    _returnController?.dispose();
    super.dispose();
  }

  /// `shuffling`フェーズに入ったら計画の尺で`AnimationController`を作って回し、
  /// それ以外のフェーズへ遷移した直後は、直前の計画を使って基準位置へ戻る
  /// 演出を開始する。同じ計画のまま再度呼ばれても作り直さない。
  void _syncController() {
    final GamePhase phase = widget.state.phase;
    final ShufflePlan? plan = widget.state.plan;

    if (phase == GamePhase.shuffling && plan != null) {
      // 新しいシャッフルが始まったら、進行中の「戻る」演出は打ち切る。
      _returnController?.dispose();
      _returnController = null;
      _returningFromPlan = null;

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
      return;
    }

    // shuffling以外へ遷移した。直前までシャッフルしていた計画があれば、
    // 基準位置へ滑らかに戻る演出を開始する。
    if (_controller != null && _animatingPlan != null) {
      _returningFromPlan = _animatingPlan;
      _returnController?.dispose();
      _returnController = AnimationController(vsync: this, duration: _returnDuration)
        ..addListener(() => setState(() {}))
        ..addStatusListener(_onReturnStatusChanged)
        ..forward();
    }
    _controller?.dispose();
    _controller = null;
    _animatingPlan = null;
  }

  void _onReturnStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    // 戻り演出が完了したら、以降はHandsPainterのplan=nullフォールバック
    // （常に基準位置）に任せてよいので、Controllerを片付ける。
    setState(() {
      _returnController?.dispose();
      _returnController = null;
      _returningFromPlan = null;
    });
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
    final bool isReturning = _returnController != null && _returningFromPlan != null;

    final ShufflePlan? animatedPlan = isShuffling
        ? state.plan
        : (isReturning ? _returningFromPlan : null);
    final Duration elapsed = isShuffling
        ? state.plan!.totalDuration * _controller!.value
        : (isReturning ? _returningFromPlan!.totalDuration : Duration.zero);
    final double returnProgress = isReturning
        ? Curves.easeOut.transform(_returnController!.value)
        : 0.0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        return Stack(
          children: <Widget>[
            CustomPaint(
              size: size,
              painter: HandsPainter(
                coinHolderHandIndex: coinHolderHandIndex,
                plan: animatedPlan,
                elapsed: elapsed,
                returnProgress: returnProgress,
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
