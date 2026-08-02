# Phase 0 — 開発基盤

| 項目        | 内容                                                              |
| ----------- | ----------------------------------------------------------------- |
| ステータス  | Approved                                                          |
| 対象Roadmap | Phase 0（開発基盤）                                               |
| 関連設計    | vision.md / gdd.md / tdd.md（3.2 ディレクトリ構成、3.3 責務区分） |

## 目的

将来の拡張を妨げず、ゲームロジックを安全に検証できるFlutterプロジェクトの土台を用意する。Roadmap Phase 0のタスクをそのまま1コミット単位として扱う。

## 対象範囲

- Riverpod・テスト・静的解析・フォーマットの基本設定確認
- TDD 3.2のFeature-first + MVVMディレクトリ骨組みの作成
- `game` Featureの`presentation`/`application`/`domain`/`repositories`/`data`配置
- `core/services`・`core/storage`の抽象定義（実装なし）
- 白・黒・グレー基調のテーマと最小限のタイトル画面
- `flutter test`のローカル検証手順の明文化

## 対象外

- Phase 1以降のゲームロジック（`GamePhase`、`ShufflePlan`等）の実装
- Rive・広告・音声・共有SDKの実装（Core Serviceは抽象のみ）
- CI（GitHub Actions等）の構築（ローカル検証手順の整備までとする）

## 前提・依存関係

- `flutter create`実行済み（iOS/Android）
- `flutter_riverpod`、`go_router`導入済み

## 実装コミット

### Commit 1 — Riverpod・テスト・静的解析・フォーマットの基本設定

- [x] `main.dart`を`ProviderScope`でラップし、プロジェクト名に沿った最小のプレースホルダー画面に置き換える
- [x] デフォルトのカウンターデモとそのテストを撤去する
- 対象ファイル：`app/lib/main.dart`、`app/test/widget_test.dart`
- 検証：`flutter analyze`、`dart format --output=none --set-exit-if-changed .`、`flutter test`
- 完了条件：3つの検証コマンドがエラーなく完了する

### Commit 2 — Feature-first + MVVM構成の骨組み作成

- [x] `lib/app/`、`lib/core/`、`lib/features/`、`lib/shared/`のディレクトリ骨組みを作成する
- 対象ファイル：`app/lib/app/**`、`app/lib/core/**`、`app/lib/shared/**`
- 検証：差分確認（フル検証はPhase完了時）
- 完了条件：TDD 3.2の構成と一致する

### Commit 3 — `game` Featureの層配置

- [ ] `lib/features/game/`配下に`presentation`/`application`/`domain`/`repositories`/`data`を作成する
- 対象ファイル：`app/lib/features/game/**`
- 検証：差分確認（フル検証はPhase完了時）
- 完了条件：空層も含め、TDDの`game` Feature構成と一致する

### Commit 4 — `core/services`と`core/storage`の抽象

- [ ] `InterstitialAdService`、`AudioService`、`ShareService`の抽象クラスを`core/services`へ追加する
- [ ] `LocalProfileStore`の抽象クラスを`core/storage`へ追加する
- 対象ファイル：`app/lib/core/services/**`、`app/lib/core/storage/**`
- 検証：差分確認（変更量が多い場合のみ部分検証）
- 完了条件：抽象定義のみで実装を持たない

### Commit 5 — テーマと最小タイトル画面

- [ ] 白・黒・グレー基調の`AppTheme`を追加する
- [ ] `home` Featureに最小限のタイトル画面を追加し、`go_router`で空のゲーム画面へ遷移できるようにする
- 対象ファイル：`app/lib/app/app_theme.dart`、`app/lib/app/**`、`app/lib/features/home/**`
- 検証：必要に応じて部分`flutter test`（フル検証はPhase完了時）
- 完了条件：タイトル画面からゲーム画面への遷移、ゲーム画面からタイトルへ戻る導線が動作する

### Commit 6 — ローカル検証手順の明文化

- [ ] README等に`flutter test`・`flutter analyze`・`dart format`のローカル実行手順を追記する
- 対象ファイル：`app/README.md`
- 検証：手順に従いローカルで再現できることを確認（Phase完了時にフル検証）
- 完了条件：手順を初見で実行できる

## リスク・未決定事項

- CI構築の要否・実行環境は本Phaseでは決定しない（必要なら別途相談）

## 実施記録

| Commit | 内容                                                                                  | 検証結果                                                                                                 |
| ------ | ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| 1      | `main.dart`を`ProviderScope`+最小プレースホルダーへ置換、カウンターデモとテストを撤去 | `flutter analyze`: No issues found / `dart format`: 1 file changed（適用済み）/ `flutter test`: 1 passed |
| 2      | `lib/app`、`lib/core`、`lib/features`、`lib/shared` の骨組みを `.gitkeep` で作成      | 差分確認のみ（検証方針変更によりフル `format` / `analyze` / `test` はPhase完了時に実施）                 |
