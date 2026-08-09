import 'package:flutter/material.dart';

import '../../domain/value_objects/game_phase.dart';
import '../../domain/value_objects/hand_id.dart';
import '../../domain/value_objects/performer_position.dart';
import '../painters/hands_painter.dart';
import '../view_models/game_ui_state.dart';

/// 2手を描画し、`answering`フェーズでは直接タップで回答できるようにするView。
///
/// 文字ボタンではなく対象そのものをタップさせるため、GestureDetectorを
/// 円と同じステージ座標へ重ねる。
class HandsView extends StatelessWidget {
  const HandsView({super.key, required this.state, required this.onHandTap});

  final GameUiState state;
  final ValueChanged<HandId> onHandTap;

  /// 誤タップ防止のため、見た目の円より広いタップ領域を確保する（TDD 6.1）。
  static const double _tapAreaSize = 56;

  @override
  Widget build(BuildContext context) {
    final bool canAnswer = state.phase == GamePhase.answering;
    // コインの保持位置は確認フェーズだけ明示し、シャッフル・回答中は隠す。
    final int? coinHolderHandIndex = state.phase == GamePhase.confirming
        ? state.plan?.initialHolder.handIndex
        : null;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        return Stack(
          children: <Widget>[
            CustomPaint(size: size, painter: HandsPainter(coinHolderHandIndex: coinHolderHandIndex)),
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
      left: center.dx - _tapAreaSize / 2,
      top: center.dy - _tapAreaSize / 2,
      width: _tapAreaSize,
      height: _tapAreaSize,
      child: GestureDetector(
        key: ValueKey<String>('hand-tap-$handIndex'),
        behavior: HitTestBehavior.opaque,
        // answering以外はタップを受け付けない（装飾扱いにする）。
        onTap: canAnswer
            ? () => onHandTap(
                HandId(performerPosition: PerformerPosition.frontCenter, handIndex: handIndex),
              )
            : null,
        child: const SizedBox.shrink(),
      ),
    );
  }
}
