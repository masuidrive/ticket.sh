# Work Notes for 260807-141649-drop-push-on-start

## 変更内容

- `record_start_on_base` から push ブロックを削除。引数から `auto_push` / `repository` を落とし
  11 → 9 引数に。push しない理由は関数コメントに残した（`start` は publish 操作ではない、
  base に載っている他人の未 push commit を巻き込む、base は close でリモートに出る）。
- `cmd_start` の `--no-push` を削除。`auto_push` の読み出しも不要になったので削除。
  引数パースの unknown-flag ケースにコメントを足し、古い呼び出しに残った `--no-push` が
  無害に無視されることを明示した。
- ヘルプ `## Push Control` を close 中心の記述に戻し、`start` が push しない理由を1項目追加。
- 設定テンプレートと init の案内から「start と close で push」の表現を close のみに戻した。

## ドキュメントで見つかった別件

`spec.md` / `spec.ja.md` の `start` の実行例が **旧版から間違っていた**。
`Example Output (auto_push: true)` として `git push -u origin feature/...` が出力される例と、
`--no-push` 版の2本が載っていたが、feature branch は旧版でも push されていない
（`5b98102` の `cmd_start` にあるのは "Note: Branch created locally." の案内だけ）。

今回 `--no-push` を消すと例の前提そのものが無くなるため、実際の出力に合わせた1本に統合した。
`[start]` commit と `Recorded start time on 'main'.` を含む現行の形。

USAGE 行の `./ticket.sh start <ticket-name> [--no-push]` からもフラグを削除。

## テスト

`test/test-start-base-sync.sh` セクション7 を差し替え:

- `auto_push: true` でも `push origin` が出力に現れないこと
- それでも `Recorded start time` は出ること（push を消しても記録は残る）
- 古い呼び出しに残った `--no-push` を渡しても `start` が成功すること

結果: 当該スイート 26/26、`test/run-all.sh` 273/273、
`test/run-all-on-docker.sh` は Ubuntu / Alpine とも 254/254。
