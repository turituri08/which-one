import '../value_objects/difficulty_profile.dart';
import '../value_objects/shuffle_step_type.dart';

/// レベル番号から`DifficultyProfile`を解決するドメインサービス。
///
/// 難易度帯のたたき台（Level 1〜3 / 4〜6 / 7〜9）に基づき、
/// レベルが上がるほど解禁される動作プリミティブを段階的に広げる。
class DifficultyResolver {
  const DifficultyResolver();

  // Phase 2では複数演者化（Level 10以降）を扱わないため、
  // 全レベルで演者数を1に固定する。
  static const int _performerCount = 1;

  /// 指定レベルの`DifficultyProfile`を解決する。
  ///
  /// Level 10以上は、Phase 5で複数演者・新しい動作を追加するまでの
  /// 暫定措置として、Level 7〜9と同じ`allowedMoves`を返す。
  DifficultyProfile resolve(int level) {
    if (level < 1) {
      throw ArgumentError('levelは1以上である必要がありますが、$levelが指定されました。');
    }

    return DifficultyProfile(
      level: level,
      performerCount: _performerCount,
      allowedMoves: _allowedMovesFor(level),
    );
  }

  Set<ShuffleStepType> _allowedMovesFor(int level) {
    if (level <= 3) {
      // Level 1〜3：明快な左右移動のみ。一定のリズムで追跡を学ぶ帯。
      return const <ShuffleStepType>{ShuffleStepType.move, ShuffleStepType.transfer};
    }
    if (level <= 6) {
      // Level 4〜6：上下・曲線・短い停止に加え、交差も加える帯。
      return const <ShuffleStepType>{
        ShuffleStepType.move,
        ShuffleStepType.transfer,
        ShuffleStepType.cross,
        ShuffleStepType.pause,
      };
    }
    // Level 7以上：横切り、緩急、見せかけの動きを加える帯（交差はLevel 4〜6から持ち越し）。
    return const <ShuffleStepType>{
      ShuffleStepType.move,
      ShuffleStepType.transfer,
      ShuffleStepType.cross,
      ShuffleStepType.feint,
      ShuffleStepType.pause,
    };
  }
}
