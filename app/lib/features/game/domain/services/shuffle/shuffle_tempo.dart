import 'dart:math';

// 緩急で速度を上げすぎて視認不能にならないよう、下限を設ける
// （速度だけで難易度を上げないという体験原則を生成側でも守るため）。
const int _minStepMillis = 200;

/// `base`を`ratio`の範囲でランダムに揺らした所要時間を返す。
///
/// 一律に速くするのではなく、往復ごとに速い・遅いを混在させることで
/// 「速さだけに依存しない難易度」（緩急）を表現する。値は暫定であり、
/// プレイテストで調整する。
Duration tempoVariedDuration({required Duration base, required double ratio, required Random random}) {
  final double variation = (random.nextDouble() * 2 - 1) * ratio;
  final int variedMillis = (base.inMilliseconds * (1 + variation)).round();
  return Duration(milliseconds: max(variedMillis, _minStepMillis));
}
