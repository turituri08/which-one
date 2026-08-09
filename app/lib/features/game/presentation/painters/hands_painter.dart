import 'package:flutter/material.dart';

/// 手を円のプレースホルダーとして描画するPainter。
///
/// Phase 1では演者1人・手2本の固定位置のみを扱う（TDD 6.1）。
class HandsPainter extends CustomPainter {
  const HandsPainter({required this.coinHolderHandIndex});

  /// コインを保持している手のindex（0または1）。表示しない場合はnull。
  ///
  /// コイン確認フェーズ以外はnullを渡し、保持位置を隠す。
  final int? coinHolderHandIndex;

  static const double radiusRatio = 0.12;

  /// 手indexに対応する正規化ステージ座標（0.0〜1.0）。
  ///
  /// 描画とタップ判定の両方でこの座標を基準にすることで、
  /// 見えている円と実際のタップ領域がずれないようにする。
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

    for (final int handIndex in <int>[0, 1]) {
      final Offset stagePosition = stagePositionFor(handIndex);
      final Offset center = Offset(stagePosition.dx * size.width, stagePosition.dy * size.height);
      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius, strokePaint);

      if (coinHolderHandIndex == handIndex) {
        // コイン確認フェーズでのみ保持手を明示する（GDD 4.2）。
        canvas.drawCircle(center, radius * 0.3, Paint()..color = Colors.black87);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HandsPainter oldDelegate) =>
      oldDelegate.coinHolderHandIndex != coinHolderHandIndex;
}
