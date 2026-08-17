# Phase 2 — シャッフルAIと難易度

| 項目        | 内容                                                                                          |
| ----------- | ----------------------------------------------------------------------------------------------- |
| ステータス  | Approved                                                                                         |
| 対象Roadmap | Phase 2（シャッフルAIと難易度）                                                                 |
| 関連設計    | vision.md（デザイン原則2, 7） / gdd.md（6, 7） / tdd.md（3, 5.2〜5.3） / decisions/0001 / decisions/0002 / decisions/0006 |

## 目的

速度だけに依存せず、リズム・軌道・停止・交差・フェイントで観察力を試すシャッフルを生成する。Level 1〜9で、暗記だけでは突破できない難易度上昇を成立させる。

## 対象範囲

- `DifficultyProfile`と`DifficultyResolver`の実装（レベル→難易度パラメータの解決）
- `ShuffleGenerator`の実装（`LevelShufflePlanner`を置き換え、シード付きで再現可能な生成を維持）
- `move`、`pause`、`cross`、`transfer`、`feint`の動作プリミティブを実際に使った生成ロジック
- Level 1〜3（左右移動）、Level 4〜6（上下・曲線・停止・交差を追加）、Level 7〜9（緩急・フェイントを追加）の難易度帯実装
- `ShuffleValidator`による公平性検証と、検証失敗時の別シードでの再生成
- 受け渡し・フェイントを視覚的に区別できるようにする、簡易描画（`CustomPainter`）の拡張
- プレイテストの実施と記録

## 対象外

- Level 10以降、複数演者、背後位置、画面外への移動（Phase 5）
- Riveアニメーション、SE等の本番演出（Phase 3）
- レベルごとのランダムな回答時間選択（`AnswerTimerConfig`の拡張。Roadmap P2のため本Phaseでは扱わない）
- 広告・共有・永続化・ランキング（Phase 4、Phase 6）
- 不正解時の広告視聴リトライ（Phase 4、ADR 0005）
- アプリの非アクティブ化時の挙動（Phase 1・ADR 0004で確定済み、本Phaseでは変更しない）

## 前提・依存関係

- Phase 1完了済み（コア・プロトタイプの状態機械、UseCase、回答タイマー、保持手一意性の契約テストが揃っている）。
- 依存方向は `View -> ViewModel -> UseCase -> Domain Service / Repository / Core Service` を厳守する。
- ゲームルール（シャッフル生成、公平性検証、難易度解決）は`features/game/domain/`に置く。
- 検証運用はADR 0002に従い、コミット単位では最小検証、Phase完了時にフル検証（`dart format .`、`flutter analyze`、`flutter test`）を実施する。
- **難易度帯（GDD 6.2が基準）**：Level 1〜3は演者1人・手2本の左右移動、Level 4〜6は同じ構成に上下・曲線・停止・交差を追加、Level 7〜9は横切り・緩急・フェイントを追加する（Commit 7.2でユーザーと相談し、交差の解禁をLevel 7〜9からLevel 4〜6へ前倒し）。Phase 2ではLevel 10以降の複数演者化は扱わない（`performerCount`は本Phase内では常に1）。
- **数値パラメータ**：`pause`の長さ、緩急の速度比、`feint`の発生確率などはPhase 1と同様に本Phaseでは確定しない。実装時は暫定値を置いて仮実装し、Roadmap 10章の方針に従い後続のプレイテストで調整する。
- 既存の`LevelShufflePlanner`は`ShuffleGenerator`へ置き換え、呼び出し元（`StartChallengeUseCase`、`SubmitAnswerUseCase`）を更新する。

## 実装コミット

### Commit 1 — DifficultyProfileとDifficultyResolverの追加

- [x] `DifficultyProfile`（`level`、`performerCount`、`allowedMoves`）を値オブジェクトとして追加する。
- [x] `DifficultyResolver`を実装し、GDD 6.2の難易度帯（Level 1〜3 / 4〜6 / 7〜9）に応じた`allowedMoves`を解決する。
- 対象ファイル：
  - `app/lib/features/game/domain/value_objects/difficulty_profile.dart`
  - `app/lib/features/game/domain/services/difficulty_resolver.dart`
- 検証：
  - `DifficultyResolver`のユニットテスト（各帯で`allowedMoves`が正しく解決されること、Level 3/4、Level 6/7の境界を含む）
- 完了条件：
  - 任意のレベルに対し、GDD 6.2の難易度帯に対応する`allowedMoves`が一意に決まる。

### Commit 2 — ShuffleGeneratorへの置き換え（挙動変更なし）

- [x] `LevelShufflePlanner`を`ShuffleGenerator`に置き換える。Level 1〜3の生成は`DifficultyResolver`の出力を使うよう変更するが、生成される計画の性質（左右移動・シャッフル尺の伸長）はPhase 1完了時点の挙動を維持する。
- [x] `StartChallengeUseCase`、`SubmitAnswerUseCase`の呼び出し先を`ShuffleGenerator`へ更新する。
- 対象ファイル：
  - `app/lib/features/game/domain/services/shuffle_generator.dart`（新規。`level_shuffle_planner.dart`を置き換え、削除する）
  - `app/lib/features/game/application/use_cases/start_challenge_use_case.dart`
  - `app/lib/features/game/application/use_cases/submit_answer_use_case.dart`
  - 対応するテストファイル一式（`level_shuffle_planner_test.dart`を`shuffle_generator_test.dart`へ移行）
- 検証：
  - `flutter test`（既存テストの移行分がすべて緑であることを含む）
  - `flutter analyze`
- 完了条件：
  - `LevelShufflePlanner`が存在せず、`ShuffleGenerator`経由でLevel 1〜3の生成がPhase 1完了時点と同じ性質で動作する。

### Commit 3 — Level 4〜6：pauseと緩急の追加

- [x] `ShuffleGenerator`にLevel 4〜6向けの生成を追加し、`pause`ステップと速度の緩急（`duration`の変化）を組み込む。
- 対象ファイル：
  - `app/lib/features/game/domain/services/shuffle_generator.dart`
  - 対応するテスト
- 検証：
  - Level 4〜6の生成で`pause`が確率的に発生すること（最低出現回数は保証しない。出現しない計画・出現する計画の両方があり得ることを確認する）
  - 保持手一意性の契約（Phase 1 Commit 8のテストパターンを拡張）が、Level 4〜6でも成り立つこと
- 完了条件：
  - Level 4〜6の計画がLevel 1〜3と異なる構成（`pause`の可能性・緩急を含む）になり、保持手の一意性契約を満たす。

### Commit 4 — シャッフル生成ロジックのファイル分割（挙動変更なし）

- [x] Level 1〜3・Level 4〜6の生成戦略を`domain/services/shuffle/`配下の個別ファイル（`left_right_step_sequence_builder.dart`、`pause_tempo_step_sequence_builder.dart`）へ分割する。
- [x] 共通処理（手の定義、抽選のヘルパー、緩急計算）を`domain/services/shuffle/`配下の共有ファイルへ抽出する。
- [x] `ShuffleGenerator`は、難易度帯に応じて生成戦略を選び呼び出すだけの薄いオーケストレーターにする。
- 対象ファイル：
  - `app/lib/features/game/domain/services/shuffle_generator.dart`（オーケストレーターへ縮小）
  - `app/lib/features/game/domain/services/shuffle/shuffle_hands.dart`（新規）
  - `app/lib/features/game/domain/services/shuffle/shuffle_step_sequence.dart`（新規）
  - `app/lib/features/game/domain/services/shuffle/shuffle_random_choices.dart`（新規）
  - `app/lib/features/game/domain/services/shuffle/shuffle_tempo.dart`（新規）
  - `app/lib/features/game/domain/services/shuffle/left_right_step_sequence_builder.dart`（新規）
  - `app/lib/features/game/domain/services/shuffle/pause_tempo_step_sequence_builder.dart`（新規）
  - 対応するテストファイル一式（Level 1〜3・Level 4〜6のテストをband別ファイルへ移行し、`shuffle_generator_test.dart`はオーケストレーションの検証に縮小する）
  - `.github/docs/tdd.md`（3.2節のディレクトリ構成へ`domain/services/shuffle/`を反映）
  - `.github/docs/decisions/0006-shuffle-generation-file-split.md`（新規、方針をADRとして記録）
- 検証：
  - `flutter test`（Commit 2・3で書いたテストと同じ内容が、移行後も全て緑であること）
  - `flutter analyze`
- 完了条件：
  - Level 1〜6の生成結果がリファクタリング前と完全に一致し、挙動が変わっていないことをテストで示せる。
  - `shuffle_generator.dart`が難易度帯に応じた生成戦略の選択とdelegateのみを担い、band別の生成ロジックを含まない。

### Commit 5 — Level 7〜9：cross・feintの追加

- [x] `domain/services/shuffle/`配下にLevel 7〜9向けの生成戦略（`cross_feint_step_sequence_builder.dart`）を追加し、`cross`と`feint`ステップを組み込む。`feint`は保持手を変更しない契約を厳守する。
- [x] `ShuffleGenerator`に、`allowedMoves`が`cross`/`feint`を含む場合はこの戦略を選ぶ分岐を追加する。
- 対象ファイル：
  - `app/lib/features/game/domain/services/shuffle/cross_feint_step_sequence_builder.dart`（新規）
  - `app/lib/features/game/domain/services/shuffle_generator.dart`
  - 対応するテスト
- 検証：
  - `transfer`は最低1回含まれること（コインが実際に移動しないとシャッフルが成立しないため保証する）
  - Level 7〜9で`cross`/`feint`が確率的に発生すること（最低出現回数は保証しない。出現しない計画・出現する計画の両方があり得ることを確認する）
  - `feint`が保持手を変更しないこと、保持手一意性の契約が成り立つこと
- 完了条件：
  - Level 7〜9の計画が交差・フェイントを発生させ得る構成になり、`feint`が実際の受け渡し（`transfer`）とドメイン上区別される。

### Commit 6 — ShuffleValidatorと再生成

- [x] `ShuffleValidator`を実装し、保持手一意性、`transfer`以外での保持手不変を検証する（`transfer`は他の動作種別と同様に確率で発生するものとし、最低出現回数は検証しない。Commit 7時点でユーザーと確認済み）。
- [x] `ShuffleGenerator`が`ShuffleValidator`の検証に失敗した場合、別シードで再生成する（無限ループを防ぐ上限回数を設ける）。
- 対象ファイル：
  - `app/lib/features/game/domain/services/shuffle_validator.dart`
  - `app/lib/features/game/domain/services/shuffle_generator.dart`
  - 対応するテスト
- 検証：
  - `ShuffleValidator`の単体テスト（正常系・各不正系）
  - 検証失敗時に別シードで再生成されることを確認するテスト
- 完了条件：
  - 不正な計画がPresentation層へ渡らないことをテストで示せる。

### Commit 7 — 受け渡し・フェイントの視覚的手掛かり

- [x] `HandsPainter`/`HandsView`を拡張し、`ShufflePlan`の経過時間に応じて手の位置を変化させる（`move`/`pause`/`cross`/`transfer`/`feint`が視覚的に区別できるようにする）。Rive導入前の簡易表現（円のプレースホルダー）のままとする。
- 対象ファイル：
  - `app/lib/features/game/presentation/painters/hands_painter.dart`
  - `app/lib/features/game/presentation/widgets/hands_view.dart`
  - 対応するWidgetテスト
- 検証：
  - Widgetテスト（クラッシュしないこと、shuffling中に手の位置が経過時間に応じて更新されること）
  - 必要に応じて手動確認（実機・エミュレータでの見た目確認）
- 完了条件：
  - GDD 7.2「すべての受け渡しには、視覚または音による手掛かりを少なくとも1つ残す」を、受け渡しとフェイントについて満たす。

### Commit 8 — プレイテストとPhase 2完了ゲート

- [ ] プレイテストを実施し、正答率・見失う理由・再挑戦意欲を記録する。
- [ ] Phase 2のフル検証（`dart format .`、`flutter analyze`、`flutter test`）を実行する。
- [ ] 計画書のチェックボックスと実施記録を更新できる状態にする。
- 対象ファイル：
  - `.github/docs/implementation-plans/phase-2-shuffle-ai-difficulty.md`
  - 必要に応じてプレイテスト記録用のドキュメント
- 検証：
  - `dart format .`
  - `flutter analyze`
  - `flutter test`
- 完了条件：
  - Phase 2の完了条件（Roadmap記載）を満たす検証結果を提示できる。

## リスク・未決定事項

- `pause`の長さ、緩急の速度比、`feint`の発生確率などの数値パラメータは本Phaseでは確定しない。暫定値で仮実装し、プレイテストで調整する（Roadmap 10章）。
- `ShuffleGenerator`の再生成上限回数、上限到達時のフォールバック挙動（例外を投げるか、検証を緩めた計画を許容するか）は未確定。
- レベルごとのランダムな回答時間選択（`AnswerTimerConfig`の拡張）はRoadmap P2のため、本Phaseでは着手しない。
- Commit 7の視覚的手掛かりの具体的な表現（色、軌道の形状等）は、Rive導入前の簡易実装であり、Phase 3で作り直される前提とする。
- プレイテストの実施方法・対象人数・記録フォーマットは未確定。

## 実施記録

| Commit | 内容 | 検証結果 |
| ------ | ---- | -------- |
| 1 | `DifficultyProfile`（`level`/`performerCount`/`allowedMoves`）と`DifficultyResolver`を追加。Level 10以上はLevel 7〜9と同じ`allowedMoves`を暫定的に返す方針をユーザーと確認した上で実装。 | `flutter test test/features/game/domain/services/difficulty_resolver_test.dart` 全8件成功、`flutter analyze` 指摘なし |
| 2 | `LevelShufflePlanner`を`ShuffleGenerator`へ置き換え。`DifficultyResolver`からレベルの`DifficultyProfile`を取得するが、生成アルゴリズム自体はPhase 1完了時点の左右移動パターンを全レベル共通で維持（pause/cross/feintの分岐は未実装、Commit 3・5で追加）。`StartChallengeUseCase`/`SubmitAnswerUseCase`のフィールド名を`planner`から`generator`へ変更。テストは`level_shuffle_planner_test.dart`を`shuffle_generator_test.dart`へ移行し、Level 1〜3がmove/transferのみで構成されることの確認を追加。 | `flutter test` 全44件成功、`flutter analyze` 指摘なし |
| 3 | `ShuffleGenerator`に`allowedMoves`に`pause`が含まれるレベル（4以上）向けの生成経路`_planWithPauseAndTempo`を追加。往復の合間に確率的な`pause`（最低1回は保証）を挿入し、`move`/`transfer`の`duration`を`tempoVariationRatio`で揺らして緩急を表現（下限200msで視認不能な速度化を防止）。`pauseDuration`/`pauseProbability`/`tempoVariationRatio`はプレイテストで調整する暫定値としてコメントで明記。テストにpause出現・durationのばらつき・タイムライン整合性・保持手一意性契約（Level 6まで拡張）を追加。 | `flutter test` 全48件成功、`flutter analyze` 指摘なし |
| 4 | Commit 4実装前にユーザーと相談し、今後cross/feint（Commit 5）・ShuffleValidator再生成（Commit 6）が加わると`shuffle_generator.dart`が肥大化する懸念からファイル分割を決定（ADR 0006）。`domain/services/shuffle/`を新設し、`shuffle_hands.dart`/`shuffle_step_sequence.dart`/`shuffle_random_choices.dart`/`shuffle_tempo.dart`（共通処理）と`left_right_step_sequence_builder.dart`/`pause_tempo_step_sequence_builder.dart`（band別戦略）へ分割。`shuffle_generator.dart`は`allowedMoves`に応じて戦略を選び`ShufflePlan`へ組み立てるオーケストレーターへ縮小。テストもband別ファイルへ移行し、`shuffle_generator_test.dart`はオーケストレーション（委譲の一致、band切り替え、level<1のエラー）の検証に絞った。挙動は変更していない（既存テストと同内容の移行分含め全て緑）。`tdd.md` 3.2節のディレクトリ構成も更新。以降のCommit番号を1つずつ繰り下げ（旧4→5、旧5→6、旧6→7、旧7→8）。 | `flutter test` 全56件成功、`flutter analyze` 指摘なし |
| 5 | `domain/services/shuffle/cross_feint_step_sequence_builder.dart`を新規追加。cross・feint・transferをそれぞれ別々の往復へ確定的に割り当てる方式（先にcross用・feint用の往復を無作為に1つずつ確保し、残りからtransferを最低1回抽選）を採用し、確率的な欠落（0にはならないが理論上起こり得る「一度も出ない」パターン）を排除。pause・緩急は`PauseTempoStepSequenceBuilder`と同じ設計を踏襲。`feint`はtransferと同じ接触に見える動作だが保持手を更新しないことをコードとテストの両方で保証。往復回数3回未満は`ArgumentError`（既定値ではLevel 7以上で常に8回以上のため到達しない）。`ShuffleGenerator`に`allowedMoves`が`cross`を含む場合の分岐を追加（pauseの判定より先に評価）。テストはbuilder単体（cross/feint/transferの最低出現、feintの保持手不変、当事者に現在の保持手が含まれること、種別の網羅性、タイムライン単調性、異常系）と、ShuffleGenerator側の委譲確認・band切り替え確認・保持手一意性の統合確認（Level 1〜9まで拡張）を追加。 | `flutter test` 全66件成功、`flutter analyze` 指摘なし |
| 5.1 | レビュー指摘を受け、cross・feintが往復回数によらず常にちょうど1回になっていた問題を修正。cross用・feint用に1往復ずつ確定的に確保する仕組みは維持しつつ、`transfer`に選ばれなかった残りの往復に対して`crossProbability`/`feintProbability`（既定0.25）による追加出現を組み込み、往復回数（＝レベル）が多いほどcross・feintの出現回数も増えるようにした。テストを「ちょうど1回」から「最低1回」の検証へ修正し、高レベル・多シードで2回以上出現するケースが実在することを確認するテストを追加。 | `flutter test` 全67件成功、`flutter analyze` 指摘なし |
| 5.2 | ユーザーと相談し、「シャッフルとして成立するにはtransferの発生が必須だが、pause・cross・feintは演出であり出現しない回があってもよい」という方針で合意（GDD 6.1「各レベルは新しい難しさを追加する」原則との整合は、緩急・往復数増加が常に効くため許容範囲と判断）。`PauseTempoStepSequenceBuilder`の`pause`と`CrossFeintStepSequenceBuilder`の`cross`/`feint`から「最低1回保証」の仕組み（`ensureAtLeastOneTrue`によるpause強制、cross/feintの確定枠予約、往復回数3回未満の`ArgumentError`ガード）をすべて削除し、`transfer`のみ引き続き最低1回を保証する形に単純化。`CrossFeintStepSequenceBuilder`は`PauseTempoStepSequenceBuilder`とほぼ同型の「1往復ごとに独立した確率で主動作を決める」ロジックになった。テストを「最低1回含まれる」から「出現しない計画・出現する計画の両方が観測される」という確率的な検証へ全面的に修正し、Commit 3・5の検証項目・完了条件も計画書上でこの仕様に合わせて更新した。 | `flutter test` 全67件成功、`flutter analyze` 指摘なし |
| 6 | `ShuffleValidator`を新規実装。検証項目は計画通り3点（最低1回のtransfer、transfer以外での保持手不変、transferの連鎖とfinalHolderの整合）に絞り、正解位置の偏りやフェイント量など他のGDD 7.4項目はPhase 2対象外のまま追加しないことをユーザーと確認。実装前に「Validatorが不正と判定する状況が現在のコードで実際に起こり得るか」を相談し、現行の生成戦略では発生し得ないが、tdd.md 5.3のパイプライン設計とPhase 5（複数演者化）以降の安全網として実装する方針で合意。`ShuffleGenerator`に検証・再生成ループを追加（同一`Random`インスタンスから引き続けることで(level, seed)ごとの再現性を維持）。上限到達時は`StateError`を投げる方針とし、上限回数は5回（実運用では到達しない想定）。過度に厳格な検証やコード複雑化を避けるよう指示を受け、チェック項目を最小限に留めた。テストは`ShuffleValidator`の正常系・不正系3パターンと、`ShuffleValidator`をテスト用にサブクラス化したフェイクによる再生成成功・再現性・上限到達時の`StateError`を追加。 | `flutter test` 全74件成功、`flutter analyze` 指摘なし |
| 7 | 初回実装（接触線での手掛かり表現、コイン可視化の検討）はユーザーとの相談の結果すべて取り消し。vision.md/gdd.mdは「コインは隠し、手の動きから保持手を推理する」という既存設計のままで正しいことを確認（ドキュメント変更なし）。ハンターハンター作中のコイン当てゲームを参考に、具体的な動きの仕様を相談して確定：`move`は自分の位置付近で小さくバウンス、`pause`は静止、`cross`は自分→相手→自分の位置と1step内で完結する往復、`transfer`は同じ往復だが相手側で重なった瞬間に0.2〜0.3秒（stepの尺が短い場合は所要時間の半分を上限に自動的に切り詰め）静止してから戻る、`feint`はcrossと同じ軌道だが重なる手前（到達率0.7）で引き返す。線による手掛かりは撤廃し、動きそのものを手掛かりとする方針に変更（GDD 7.2）。手の画面上の位置は常に固定（`stagePositionFor`）とし、累積的な位置入れ替えは持たない自己完結型のアニメーションにした。あわせて、生成頻度が`move > cross > feint > transfer`になるようユーザーと合意し、`LeftRightStepSequenceBuilder`/`PauseTempoStepSequenceBuilder`/`CrossFeintStepSequenceBuilder`のtransfer抽選を単純な50%から`transferProbability`（既定0.2、CrossFeintBuilderは0.08）による確率抽選へ変更、`pauseProbability`も0.35→0.15へ引き下げ。`HandsView`は`StatefulWidget`化して`AnimationController`でシャッフル中の経過時間を管理（`GameUiState`は変更しない）。前回発生した「レベルが進むたびに新しいAnimationControllerを作るとSingleTickerProviderStateMixinでは足りない」という不具合を踏まえ、最初から`TickerProviderStateMixin`を採用。テストは各builderに頻度順序の統計的検証を追加し、`hands_view_test.dart`でクラッシュしないこと・`elapsed`が経過時間に応じて更新されること・複数レベルにまたがってもTickerの作り直しでクラッシュしないことを確認。 | `flutter test` 全82件成功、`flutter analyze` 指摘なし |
| 7.1 | 動作確認を受けたユーザーからの3点のフィードバックを反映。(1) `transfer`の最低1回保証を撤廃し、`pause`/`cross`/`feint`と同じ単純な確率抽選に統一（`ensureAtLeastOneTrue`を使う箇所がなくなったため`shuffle_random_choices.dart`を削除）。`ShuffleValidator`からも「最低1回のtransfer」の検証を外し、Commit 6の検証項目を計画書上で修正（transfer 0回の計画も有効）。(2) `move`の見た目を、GDDの「直線、曲線、円弧、上下移動」という定義幅により近づけるため、上下バウンスに加えて小さな左右のドリフトを組み合わせた弧を描く動きに拡張。(3) `cross`/`transfer`で入れ替わった左右の位置は、1step内で自分の位置へ戻るのではなく、次にcross/transferが起きるまで（または`shuffling`フェーズが終わるまで）複数stepにまたがって持続する仕様に修正（`HandsPainter`にstepインデックスを渡し、それ以前のcross/transfer回数の偶奇から「今どちら側にいるか」を都度計算する方式にした）。`transfer`の接触点も「相手側で静止」から「中間地点で静止してから相手側へ完了する」に変更。`shuffling`フェーズが終われば`plan`がnullになり自動的に基準位置表示へ戻るため、「レベルが終われば元に戻る」は従来通り満たされる。 | `flutter test` 全82件成功、`flutter analyze` 指摘なし |
| 7.2 | ユーザーからの難易度帯・出現頻度の仕様変更依頼を受け、ドキュメントと実装の両方を更新。**難易度帯構成の変更**：Level 4〜6に`cross`を追加（従来はLevel 7〜9でのみ解禁）。`gdd.md` 6.2の難易度帯表と、本計画書の「対象範囲」「前提・依存関係」を合わせて修正。`DifficultyResolver`のLevel 4〜6判定に`cross`を追加し、`ShuffleGenerator`の帯判定を「`cross`の有無」から「`feint`の有無」（Level 7〜9にしか存在しない）へ変更（`cross`だけではLevel 4〜6と7〜9を判別できなくなったため）。**出現頻度順序の変更**：全帯で`move > transfer > cross > feint > pause`の順に統一（従来は`move > cross > feint > transfer`で`transfer`が最も低頻度だったが、`transfer`を高頻度側へ変更）。`pause`も他の動作と同じ「往復の主動作を1つ選ぶ」抽選に統合し、独立した「往復の前に挿入する」方式（`pausesBeforeRepetition`、固定`pauseDuration`）を廃止（`pause`が選ばれた往復は、その往復の尺全体が静止になる）。`PauseTempoStepSequenceBuilder`は`cross`対応と統合抽選に合わせて全面的に書き直したが、クラス名・ファイル名は変更していない（`cross`を扱うようになった点でやや実態と乖離するが、リネームによる差分拡大を避けた。必要であれば別途リネームを検討する）。`CrossFeintStepSequenceBuilder`も同様に`pause`を統合抽選へ組み込んだ。`HandsPainter`は`ShuffleStepType`ごとに描画を分岐するだけで、生成元がどのbuilderかを問わないため無変更。テストは`DifficultyResolver`のband境界（cross:Level3/4、feint:Level6/7）、各builderの新しい頻度順序、`ShuffleGenerator`のband切り替わりを更新。 | `flutter test` 全82件成功、`flutter analyze` 指摘なし |
| 7.3 | `PauseTempoStepSequenceBuilder`が`cross`も扱うようになった実態に合わせ、`CrossPauseStepSequenceBuilder`へリネーム（`pause_tempo_step_sequence_builder.dart`→`cross_pause_step_sequence_builder.dart`）。ロジック変更はなく、クラス名・ファイル名・`ShuffleGenerator`のフィールド名（`pauseTempoBuilder`→`crossPauseBuilder`）・関連テスト・`tdd.md`・ADR 0006の例示のみを更新。7.2の内容とは無関係な純粋なリファクタのため、別コミットとして分離した（7.2はCommit Aとして先にコミット済み、本リネームはCommit Bとして提案）。 | `flutter test` 全82件成功、`flutter analyze` 指摘なし |
| 7.4 | 動作確認したユーザーから、線を撤廃したtransfer/crossは改善したが、`move`が「小さく円を描いて自分の位置に戻るだけ」で意味のない動きに見えるとの指摘を受けた。`move`も`cross`/`transfer`と同様に位置を持続させ、画面全体を使って大きく動くように変更（`shuffling`が終われば`plan`がnullになり自動的に基準位置へ戻る既存の仕組みは変更不要で、「回答を求める瞬間に元の位置へ戻る」という要望をそのまま満たす）。実装は、`cross`/`transfer`の偶奇カウント方式だった位置管理を、2手それぞれの持続する位置（pos0/pos1）を履歴から都度再計算する方式へ一般化し、`move`もこの持続する位置を更新できるようにした（`move`の移動先は`plan.seed`とstep・手のインデックスから決める再現可能な疑似乱数）。`cross`/`transfer`は「2手の位置を入れ替える」処理に単純化された（従来の左右2固定スロットのswap判定は不要になった）。テストは既存のクラッシュ確認・elapsed確認・複数レベルにまたがる確認を再実行し、全て緑であることを確認（位置計算そのものを直接検証するテストは追加していない。手動でのシミュレータ確認を推奨）。 | `flutter test` 全82件成功、`flutter analyze` 指摘なし |
| 7.5 | 動作確認したユーザーから、`shuffling`終了時に手がパッと基準位置へ瞬間移動し、保持手を追えなくなるとの指摘を受けた。`shuffling`→`answering`遷移直後に、直前の位置から基準位置へ0.5秒かけて滑らかに戻る演出を追加。`HandsPainter`に`returnProgress`（0.0〜1.0）を追加し、シャッフル中の位置から`stagePositionFor`へ`Offset.lerp`で寄せるようにした。あわせて、`activeStepIndex`がnull（シャッフルの尺を過ぎた状態）のときに持続していた位置を無視して基準位置へ即座にフォールバックしていた既存のバグも修正（`_positionsBeforeStep`を全step数で呼ぶよう変更）。`HandsView`に2つ目の`AnimationController`（`_returnController`、0.5秒、`Curves.easeOut`）を追加し、shuffling終了を検知した時点で開始、完了したら自動的に破棄してplan=nullフォールバックへ戻す。テストに戻りアニメーションの進捗（0→中間→1で完了しplanがnullに戻る）を検証するケースを追加。 | `flutter test` 全83件成功、`flutter analyze` 指摘なし |
| 7.6 | 動作確認したユーザーから好意的な評価を得た（細かな調整は後続Phaseで実施）。あわせて、左右の手が両方とも白丸で見分けがつかず、`move`で自由に動き回るようになったことで不必要に難しくなっているとの指摘を受け、デバッグ用に縁の色でhand0/hand1を区別できるようにした（hand0=青、hand1=赤）。ゲームルール・保持手の判定には一切影響しない純粋な描画上の変更（本番の見た目はPhase 3のRive導入時に作り直す前提）。コメント・書式に近い小さな変更のためフルテストは省略し、`hands_view_test.dart`のみ再実行して緑であることを確認。 | `flutter test`（`hands_view_test.dart`）全6件成功、`flutter analyze` 指摘なし |
