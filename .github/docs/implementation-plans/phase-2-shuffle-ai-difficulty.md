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
- Level 1〜3（左右移動）、Level 4〜6（上下・曲線・停止を追加）、Level 7〜9（交差・緩急・フェイントを追加）の難易度帯実装
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
- **難易度帯（GDD 6.2が基準）**：Level 1〜3は演者1人・手2本の左右移動、Level 4〜6は同じ構成に上下・曲線・停止を追加、Level 7〜9は交差・横切り・緩急・フェイントを追加する。Phase 2ではLevel 10以降の複数演者化は扱わない（`performerCount`は本Phase内では常に1）。
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

- [ ] `ShuffleValidator`を実装し、保持手一意性、`transfer`以外での保持手不変、最低1回の`transfer`を検証する。
- [ ] `ShuffleGenerator`が`ShuffleValidator`の検証に失敗した場合、別シードで再生成する（無限ループを防ぐ上限回数を設ける）。
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

- [ ] `HandsPainter`/`HandsView`を拡張し、`ShufflePlan`の経過時間に応じて手の位置を変化させる（`move`/`pause`/`cross`/`transfer`/`feint`が視覚的に区別できるようにする）。Rive導入前の簡易表現（円のプレースホルダー）のままとする。
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
