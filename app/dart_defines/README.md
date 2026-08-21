# dart-define設定

VSCodeのデバッグ設定（`.vscode/launch.json`）は、`--dart-define-from-file=dart_defines/local.json`でビルド時変数を渡す。

- `local.example.json`：コミット対象のテンプレート。キーを追加する際はここにも（値は空またはダミーで）追記し、必要な変数を可視化する。
- `local.json`：実際に使う値を書く、各自の手元ファイル。`.gitignore`で除外しているため、広告ユニットIDなどの秘匿値を含めてもコミットされない。

## 使い方

まだ利用しているコードはないが（2026-08時点）、Phase 4以降で広告ユニットID等を追加する際は、`String.fromEnvironment('KEY')`で読み取り、`local.example.json`と`local.json`の両方にキーを追加する。TDD 8.1の方針（本番用広告IDはソースコードに直接書かない）に従うこと。

初めてこのリポジトリをcloneした場合は、`local.example.json`を`local.json`へコピーしてから値を埋めること（`local.json`自体は新規cloneには含まれない）。
