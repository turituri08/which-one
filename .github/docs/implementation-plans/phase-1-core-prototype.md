# Phase 1 — コア・プロトタイプ（ロジックのみ）

| 項目        | 内容                                                                                |
| ----------- | ----------------------------------------------------------------------------------- |
| ステータス  | Approved / In progress                                                              |
| 対象Roadmap | Phase 1（コア・プロトタイプ）                                                       |
| 関連設計    | vision.md / gdd.md（3, 4, 6, 7） / tdd.md（3〜6） / decisions/0001 / decisions/0002 |

## 目的

白い円または簡易的な手の表現だけで、観察ゲームの最小ループ（確認→シャッフル→回答→正誤→次レベル/結果）を成立させる。

## 対象範囲

- `GamePhase`を中心にした状態機械（`idle`、`confirming`、`shuffling`、`answering`、`correct`、`incorrect`、`result`）
- `StartChallengeUseCase`と`SubmitAnswerUseCase`の実装
- `HandId`、`ShufflePlan`、`ShuffleStep`、`AnswerResult`の実装
- `CustomPainter`による2手（または2円）描画と直接タップ回答
- Level 1の左右移動シャッフル
- 全レベル30秒の回答タイマー、残り時間表示
- 二重入力と時間切れ競合の防止
- アプリの非アクティブ化時にタイマーを一時停止しないことの確認（[ADR 0004](../decisions/0004-no-pause-on-inactive.md)）
- 保持手一意性のユニットテスト

## 対象外

- Phase 2以降の難易度拡張（`cross`/`feint`中心の本格生成、Level 4+）
- Riveアニメーション導入
- 広告・共有・音声SDKの実装
- 世界ランキングおよびオンライン機能

## 前提・依存関係

- Phase 0完了済みで、Feature-first + MVVMの骨組みが存在する。
- 依存方向は `View -> ViewModel -> UseCase -> Domain Service / Repository / Core Service` を厳守する。
- ゲームルール（保持手変更条件、判定、レベル進行）は `features/game/domain/` に置く。
- 検証運用はADR 0002に従い、コミット単位では最小検証、Phase完了時にフル検証（`dart format .`、`flutter analyze`、`flutter test`）を実施する。
- **Level構成（相談で確認済み）**：Phase 1ではLevel 1の左右移動パターンをレベル間で使い回す。コイン保持手の開始位置はレベルごとにランダム化し、暗記だけでの突破を避ける（GDD 7.2）。`cross`/`feint`等の複雑な動作はPhase 2以降で追加する。
- **プレイヤー向けタイマー（相談で確認済み）**：プレイヤーに見せる残り時間タイマーは`answering`の30秒のみとする。`confirming`と`shuffling`はカウントダウン表示を持たない内部待機で自動的に次フェーズへ進む。
- **`confirming`/`shuffling`の尺（相談で確認済み）**：`confirming`（コイン保持手を見せる時間）は全レベルで固定値とする。`shuffling`（シャッフルが動いている時間）はレベルに応じて可変とし、レベルが上がるほど長くする。Phase 1では左右移動パターンを維持したまま、往復回数や尺を伸ばすことで長さを変える（`cross`/`feint`等の新しい動作種別は追加しない）。

## 実装コミット

### Commit 1 — ドメイン基本モデルと状態定義の追加

- [x] `GamePhase`、`HandId`、`ShuffleStep`、`ShufflePlan`、`AnswerResult`を追加する。
- [x] `ShuffleStep`で保持手変更を許可する操作を`transfer`のみに限定する契約を明文化する。
- 対象ファイル：
  - `app/lib/features/game/domain/entities/**`
  - `app/lib/features/game/domain/value_objects/**`
  - `app/lib/features/game/presentation/view_models/game_ui_state.dart`
- 検証：
  - 差分レビュー
  - 追加した型のユニットテスト（最低1件）
- 完了条件：
  - ViewModelが参照可能な最小UI状態とドメイン型が揃っている。

### Commit 2 — チャレンジ開始UseCaseの実装

- [x] `StartChallengeUseCase`を実装し、Level 1開始時の初期状態を構築する。
- [x] Level共通の左右移動シャッフル計画を、コイン保持手の開始位置をランダム化しつつ返す最小構成を追加する（全レベルで同一パターンを再利用し、複雑な動作の追加はPhase 2以降とする）。
- [x] シャッフルの尺（往復回数・合計時間）をレベルに応じて伸ばす計算を追加する（`confirming`の尺はレベルに関係なく固定値とする）。
- 対象ファイル：
  - `app/lib/features/game/application/use_cases/start_challenge_use_case.dart`
  - `app/lib/features/game/domain/services/level_shuffle_planner.dart`
  - `app/lib/features/game/domain/entities/challenge_session.dart`
- 検証：
  - `StartChallengeUseCase`のユニットテスト（開始位置のランダム化、レベルによるシャッフル尺の伸長を含む）
- 完了条件：
  - 開始操作で`confirming`へ遷移するための初期データが一意に決まる。

### Commit 3 — 回答判定UseCaseの実装

- [x] `SubmitAnswerUseCase`を実装し、正解/不正解/時間切れの判定結果を返す。
- [x] 正解時の次レベル進行に必要な最小情報（現レベル、最高到達レベル）を更新する。
- 対象ファイル：
  - `app/lib/features/game/application/use_cases/submit_answer_use_case.dart`
  - `app/lib/features/game/domain/services/answer_judge.dart`
- 検証：
  - `SubmitAnswerUseCase`のユニットテスト（正解・不正解・時間切れ）
- 完了条件：
  - 判定ロジックがUI層に漏れず、UseCase単体で検証できる。

### Commit 4 — GameViewModelの状態機械実装

- [x] `GameViewModel`を追加し、開始・シャッフル完了・回答・正誤反映・結果遷移を管理する。
- [x] `StartChallengeUseCase`と`SubmitAnswerUseCase`をViewModelへ接続する。
- [x] `confirming`はコイン提示後の固定の内部待機（カウントダウン表示なし）で自動的に`shuffling`へ進める。
- [x] `shuffling`は`ShufflePlan.steps`の尺を消化した時点で自動的に`answering`へ進める（回答フェーズ以外はプレイヤー向けタイマーを持たない）。
- [x] `correct`は次レベルの`confirming`へ自動で戻り、`incorrect`は`result`へ自動で進む。
- 対象ファイル：
  - `app/lib/features/game/presentation/view_models/game_view_model.dart`
  - `app/lib/features/game/presentation/view_models/game_ui_state.dart`
  - `app/lib/features/game/application/use_cases/**`
- 検証：
  - ViewModelユニットテスト（主要フェーズ遷移、`confirming`/`shuffling`の自動遷移を含む）
- 完了条件：
  - `idle -> confirming -> shuffling -> answering -> correct/incorrect -> result` の基本遷移を再現できる。
  - `confirming`/`shuffling`は入力を受け付けず、プレイヤーへ表示するタイマーは`answering`のみである。

### Commit 5 — Game画面の簡易描画と直接タップ回答

- [x] `CustomPainter`で2手（または2円）を描画する。
- [x] 回答フェーズで対象を直接タップして回答できるようにする。
- [x] 回答確定後は再入力を無効化する。
- 対象ファイル：
  - `app/lib/features/game/presentation/game_screen.dart`
  - `app/lib/features/game/presentation/painters/**`
  - `app/lib/features/game/presentation/widgets/**`
- 検証：
  - Widgetテスト（タップで回答が1回だけ受理されること）
- 完了条件：
  - 文字ボタンではなく対象そのもののタップで判定まで進む。

### Commit 6 — 回答タイマーと競合防止

- [x] 全レベル30秒の回答タイマーを実装する。
- [x] 残り時間表示を追加する。
- [x] 時間切れとタップの同時発火時に最初の結果だけを受理する。
- 対象ファイル：
  - `app/lib/features/game/presentation/view_models/game_view_model.dart`
  - `app/lib/features/game/presentation/view_models/game_ui_state.dart`
  - `app/lib/features/game/application/use_cases/submit_answer_use_case.dart`
- 検証：
  - ViewModelユニットテスト（タイムアウト/タップ競合）
  - 必要に応じてWidgetテスト1件
- 完了条件：
  - 二重結果遷移が発生せず、残り時間表示が回答フェーズで更新される。

### Commit 7 — バックグラウンド移行時にタイマーを止めない方針の確定

当初は`tdd.md`の記述通り、非アクティブ化時に`paused`へ遷移してタイマーを一時停止し、復帰後に再開する実装（`pause`/`resume`、`GamePhase.paused`）を行ったが、実装検討の過程で次の2つの抜け道が見つかったため方針を転換した（詳細は[ADR 0004](../decisions/0004-no-pause-on-inactive.md)、旧方針は[ADR 0003](../decisions/0003-pause-resume-precision.md)としてSupersededで記録）。

- shuffling中にアプリを切り替えて戻ると、同じシャッフルが最初から再生され、何度でも見返せてしまう。
- answering中にアプリをバックグラウンドへ置くと回答タイマーが凍結され、実質無制限に考える時間を確保できてしまう。

「意図的な操作」と「意図しない中断（着信等）」をFlutterのライフサイクルAPIから区別する信頼できる手段がないため、理由を問わずタイマーは常に進み続ける方針とした。

- [x] 一時停止・復帰の実装（`pause`/`resume`、`GamePhase.paused`、`WidgetsBindingObserver`配線）を撤回し、Commit 6時点の実装に戻す。
- [x] `tdd.md`の状態遷移図・ライフサイクル表・テスト戦略から`paused`関連の記述を削除し、非アクティブ化時もタイマーを止めない方針を明記する。
- [x] 方針転換の経緯と理由をADR化する。
- 対象ファイル：
  - `app/lib/features/game/presentation/game_screen.dart`
  - `app/lib/features/game/presentation/view_models/game_view_model.dart`
  - `app/lib/features/game/domain/value_objects/game_phase.dart`
  - `app/test/features/game/presentation/view_models/game_view_model_test.dart`
  - `.github/docs/tdd.md`
  - `.github/docs/roadmap.md`
  - `.github/docs/decisions/0003-pause-resume-precision.md`（Superseded化）
  - `.github/docs/decisions/0004-no-pause-on-inactive.md`（新規）
- 検証：
  - `flutter test`（Commit 6時点の状態へ戻したことを確認）
  - `flutter analyze`
- 完了条件：
  - `GamePhase.paused`・`pause`/`resume`関連コードが存在せず、非アクティブ化時にタイマーへ一切干渉しないこと。
  - 文書（`tdd.md`/`roadmap.md`/ADR）が新方針と一致していること。

### Commit 8 — 保持手一意性テストとPhase 1完了ゲート

- [ ] `ShufflePlan`について「保持手は常に1本」「`transfer`以外で保持手が変わらない」をユニットテストで検証する。
- [ ] Phase 1のフル検証（`dart format .`、`flutter analyze`、`flutter test`）を実行する。
- [ ] 計画書のチェックボックスと実施記録を更新できる状態にする。
- 対象ファイル：
  - `app/test/features/game/domain/**`
  - `app/test/features/game/application/**`
  - `app/test/features/game/presentation/view_models/**`
  - `app/test/widget_test.dart`（必要な範囲で更新）
- 検証：
  - `dart format .`
  - `flutter analyze`
  - `flutter test`
- 完了条件：
  - Phase 1の完了条件（Roadmap記載）を満たす検証結果を提示できる。

## リスク・未決定事項

- `ChallengeSession`やRepository責務をPhase 1でどこまで導入するか（最小実装か、Phase 2前提の拡張余地を先に作るか）。
- タイマー実装方式（`Timer`主体かTicker主体か）によるテスト容易性の差。
- **アプリ非アクティブ化時のタイマー扱い（相談で確認済み・[ADR 0004](../decisions/0004-no-pause-on-inactive.md)）**：一時停止はせず、`confirming`/`shuffling`/`answering`いずれのタイマーも実時間で進行し続ける。理由を問わず離れた分だけ不利になる（旧方針の`paused`遷移・残り時間の凍結はADR 0003としてSupersededに変更）。
- Level 2以降をPhase 1でどこまで仮実装するか（固定パターンのみ / 生成の前段まで）。
- **数値パラメータ（相談で確認済み）**：`confirming`の固定秒数、`shuffling`のレベルごとの伸長式（初期値・増分）は本Phaseでは確定しない。実装時は暫定値を置いて仮実装を進め、Roadmap 10章の方針に従い後続フェーズのプレイテストで正式に調整する。

## 実施記録

| Commit | 内容                                                                                                                                                                                                                                                                                      | 検証結果                                                                                                               |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| 1      | `GamePhase`、`PerformerPosition`、`HandId`、`ShuffleStepType`を値オブジェクトとして、`ShuffleStep`、`ShufflePlan`、`AnswerResult`をエンティティとして追加。最小の`GameUiState`を追加                                                                                                      | `flutter test test/features/game`: 7 passed / `flutter analyze lib/features/game test/features/game`: No issues found  |
| 2      | `LevelShufflePlanner`（Domain Service）、`ChallengeSession`（エンティティ）、`StartChallengeUseCase`を追加。Level1の左右移動パターンを全レベルで再利用し、開始保持手のランダム化とレベルによるシャッフル尺の伸長を実装。Phase1では永続化を行わないため`ChallengeRepository`は作成を見送り | `flutter test test/features/game`: 13 passed / `flutter analyze lib/features/game test/features/game`: No issues found |
| 3      | `AnswerJudge`（Domain Service）で正解判定ロジックを切り出し、`SubmitAnswerUseCase`で判定結果と次レベル進行（現レベル・最高到達レベルの更新）を実装。不正解・時間切れはレベルを進めず`incorrect`へ遷移                                                                                     | `flutter test test/features/game`: 19 passed / `flutter analyze lib/features/game test/features/game`: No issues found |
| 4      | `GameViewModel`（Riverpodの`Notifier`）を追加し、`GameUiState`へ`level`/`highestLevel`/`plan`/`lastAnswerResult`を拡張。`confirming`/`shuffling`/`correct`/`incorrect`の自動遷移を、実時間非依存でテストできる`GameScheduler`差し替え機構で実装                                           | `flutter test test/features/game`: 25 passed / `flutter analyze lib/features/game test/features/game`: No issues found |
| 5      | `HandsPainter`（`CustomPainter`）と`HandsView`を追加し、`GameScreen`から2手の円を描画。`answering`フェーズのみ手そのものへの直接タップで`submitAnswer`を呼び、それ以外のフェーズはタップを受け付けない。UseCase/ SchedulerをRiverpod Providerからの`ref.watch`注入へ変更し、Widget/Mock双方でテスト可能にした                | `flutter test`: 27 passed / `flutter analyze lib/features/game lib/core/constants test/widget_test.dart test/features/game`: No issues found |
| 6      | `GameUiState`に`remainingSeconds`を追加し、`GameViewModel`に全レベル固定30秒の回答タイマーを実装（既存の`GameScheduler`抽象を使い、1秒ごとに自身を再予約する自己再帰で残り時間を減算）。残り0秒到達時は`submitAnswer(null)`へ委譲し、時間切れ判定の経路を1本化。競合防止は既存の`submitAnswer`の「answering以外は無視する」ガードを流用し、タップ・時間切れのどちらが先に成立しても後発側は無視される。`GameScreen`に`answering`中のみ残り時間表示を追加            | `flutter test`: 33 passed / `flutter analyze lib/features/game lib/core/constants test/widget_test.dart test/features/game`: No issues found |
| 7      | 当初`GameScreen`に`WidgetsBindingObserver`を追加し、非アクティブ化時に`GameViewModel.pause()`/`resume()`で`paused`へ一時停止・復帰する実装を行ったが（ADR 0003）、shuffling再視聴・answering思考時間無制限の2つの抜け道が判明したため撤回。Commit 6時点の実装へ戻し、`GamePhase`から`paused`を削除。非アクティブ化時もタイマーを一切止めない方針をADR 0004として記録し、`tdd.md`/`roadmap.md`の該当記述を更新 | `flutter test`: 33 passed / `flutter analyze lib/features/game lib/core/constants test/widget_test.dart test/features/game`: No issues found |
