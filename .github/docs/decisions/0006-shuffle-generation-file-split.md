# ADR 0006 — シャッフル生成ロジックのファイル分割方針

| 項目       | 内容                                                     |
| ---------- | -------------------------------------------------------- |
| ステータス | Accepted                                                 |
| 決定日     | 2026-08-14                                                |
| 関連文書   | [TDD](../tdd.md) 3.2 / [Phase 2実装計画](../implementation-plans/phase-2-shuffle-ai-difficulty.md) |

## 背景

`ShuffleGenerator`は、難易度帯が増えるたびに専用のprivateメソッドが追加される設計だった。Level 7〜9のcross/feint追加、`ShuffleValidator`との再生成ループを控えており、1ファイルに複数の生成戦略と横断的な処理が同居して肥大化する見込みとなった。

## 決定

- `ShuffleGenerator`は、`DifficultyResolver`の出力（`allowedMoves`）に応じて難易度帯別の生成戦略を選び呼び出す、薄いオーケストレーターとする。
- 難易度帯別の生成戦略は`domain/services/shuffle/`配下に個別ファイルとして配置する（例：`left_right_step_sequence_builder.dart`、`pause_tempo_step_sequence_builder.dart`）。
- 生成戦略間で共有する処理（手の定義、抽選ヘルパー、緩急計算）も`domain/services/shuffle/`配下の共有ファイルへ抽出する。
- `tdd.md` 3.2節のディレクトリ構成に`domain/services/shuffle/`を反映する。

## 影響

- ファイルが増える分、変更対象の把握には`domain/services/shuffle/`配下を横断的に見る必要がある。
- 各生成戦略を独立してユニットテストできるようになり、`shuffle_generator.dart`自体のテストはオーケストレーション（難易度帯に応じた戦略選択）の検証に絞れる。
- Phase 5で複数演者向けの生成戦略を追加する際も、同じ置き場所（`domain/services/shuffle/`）を再利用できる。
