import '../entities/shuffle_plan.dart';
import '../value_objects/hand_id.dart';
import '../value_objects/shuffle_step_type.dart';

/// `ShufflePlan`が最低限のゲームルールを満たしているかを検証するドメインサービス。
///
/// 検証するのは、ゲームが成立するために欠かせない次の2点だけに絞る。
/// - `transfer`以外の動作では保持手が変わらないこと
/// - `transfer`の連鎖をたどった結果が`finalHolder`と一致すること（保持手一意性）
///
/// `transfer`は`pause`/`cross`/`feint`と同様に確率で発生する演出であり、
/// 1回も発生しない計画（開始時の保持手がそのまま正解位置になる）も正当な結果
/// として許容するため、最低出現回数は検証しない。
///
/// 現在の生成戦略（`domain/services/shuffle/`配下の各Builder）は、これらの条件を
/// 常に満たすように作られているため、本来ここで不正と判定されることはない。
/// 将来の生成戦略の追加・変更（Phase 5の複数演者化等）で契約が壊れた場合に
/// 検知するための安全網として位置づける。
class ShuffleValidator {
  const ShuffleValidator();

  /// `plan`が最低限のゲームルールを満たしていれば`true`を返す。
  bool isValid(ShufflePlan plan) {
    HandId holder = plan.initialHolder;
    for (final step in plan.steps) {
      if (step.type != ShuffleStepType.transfer) {
        continue;
      }
      // transferの当事者に現在の保持手が含まれない場合、
      // 誰から誰へコインが渡ったのか特定できず、保持手の連鎖が破綻している。
      if (step.actors.length != 2 || !step.actors.contains(holder)) {
        return false;
      }
      holder = step.actors.firstWhere((actor) => actor != holder);
    }

    // transferの連鎖をたどった結果と、計画が記録するfinalHolderが
    // 一致しない場合も不整合とみなす。
    return holder == plan.finalHolder;
  }
}
