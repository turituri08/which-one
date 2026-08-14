/// 演者の立ち位置。前景は最大3人、背後は最大3人まで想定する。
enum PerformerPosition {
  /// 前景・左。
  frontLeft,

  /// 前景・中央。
  frontCenter,

  /// 前景・右。
  frontRight,

  /// 背後・左後ろ。
  rearLeft,

  /// 背後・真後ろ。
  rearCenter,

  /// 背後・右後ろ。
  rearRight;

  /// 背後位置かどうか。背後の演者は手を1本しか持たない制約がある。
  bool get isRear => this == rearLeft || this == rearCenter || this == rearRight;
}
