import 'dart:math';

/// 抽選結果のリストに最低1回は`true`を含めるためのヘルパー。
///
/// 「一度もtransferが発生しない」「一度もpauseが発生しない」といった、
/// シャッフルとして機能しない結果を避けるために各生成戦略から共通で使う。
List<bool> ensureAtLeastOneTrue(List<bool> choices, Random random) {
  if (choices.contains(true)) {
    return choices;
  }
  final List<bool> result = List<bool>.of(choices);
  result[random.nextInt(result.length)] = true;
  return result;
}
