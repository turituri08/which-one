# Phase 2 — シャッフルAIと難易度

| 項目        | 内容                                                                                          |
| ----------- | ----------------------------------------------------------------------------------------------- |
| ステータス  | Approved                                                                                         |
| 対象Roadmap | Phase 2（シャッフルAIと難易度）                                                                 |
| 関連設計    | vision.md（デザイン原則2, 7） / gdd.md（6, 7） / tdd.md（3, 5.2〜5.3） / decisions/0001 / decisions/0002 |

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

- [ ] `DifficultyProfile`（`level`、`performerCount`、`allowedMoves`）を値オブジェクトとして追加する。
- [ ] `DifficultyResolver`を実装し、GDD 6.2の難易度帯（Level 1〜3 / 4〜6 / 7〜9）に応じた`allowedMoves`を解決する。
- 対象ファイル：
  - `app/lib/features/game/domain/value_objects/difficulty_profile.dart`
  - `app/lib/features/game/domain/services/difficulty_resolver.dart`
- 検証：
  - `DifficultyResolver`のユニットテスト（各帯で`allowedMoves`が正しく解決されること、Level 3/4、Level 6/7の境界を含む）
- 完了条件：
  - 任意のレベルに対し、GDD 6.2の難易度帯に対応する`allowedMoves`が一意に決まる。

### Commit 2 — ShuffleGeneratorへの置き換え（挙動変更なし）

- [ ] `LevelShufflePlanner`を`ShuffleGenerator`に置き換える。Level 1〜3の生成は`DifficultyResolver`の出力を使うよう変更するが、生成される計画の性質（左右移動・シャッフル尺の伸長）はPhase 1完了時点の挙動を維持する。
- [ ] `StartChallengeUseCase`、`SubmitAnswerUseCase`の呼び出し先を`ShuffleGenerator`へ更新する。
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

- [ ] `ShuffleGenerator`にLevel 4〜6向けの生成を追加し、`pause`ステップと速度の緩急（`duration`の変化）を組み込む。
- 対象ファイル：
  - `app/lib/features/game/domain/services/shuffle_generator.dart`
  - 対応するテスト
- 検証：
  - Level 4〜6の生成で`pause`が最低1回含まれること
  - 保持手一意性の契約（Phase 1 Commit 8のテストパターンを拡張）が、Level 4〜6でも成り立つこと
- 完了条件：
  - Level 4〜6の計画がLevel 1〜3と異なる構成（`pause`・緩急を含む）になり、保持手の一意性契約を満たす。

### Commit 4 — Level 7〜9：cross・feintの追加

- [ ] `ShuffleGenerator`にLevel 7〜9向けの生成を追加し、`cross`と`feint`ステップを組み込む。`feint`は保持手を変更しない契約を厳守する。
- 対象ファイル：
  - `app/lib/features/game/domain/services/shuffle_generator.dart`
  - 対応するテスト
- 検証：
  - Level 7〜9で`cross`/`feint`が最低1回含まれること
  - `feint`が保持手を変更しないこと、保持手一意性の契約が成り立つこと
- 完了条件：
  - Level 7〜9の計画が交差・フェイントを含み、`feint`が実際の受け渡し（`transfer`）とドメイン上区別される。

### Commit 5 — ShuffleValidatorと再生成

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

### Commit 6 — 受け渡し・フェイントの視覚的手掛かり

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

### Commit 7 — プレイテストとPhase 2完了ゲート

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
- Commit 6の視覚的手掛かりの具体的な表現（色、軌道の形状等）は、Rive導入前の簡易実装であり、Phase 3で作り直される前提とする。
- プレイテストの実施方法・対象人数・記録フォーマットは未確定。

## 実施記録

| Commit | 内容 | 検証結果 |
| ------ | ---- | -------- |
