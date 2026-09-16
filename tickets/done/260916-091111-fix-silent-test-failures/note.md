# Work Notes for 260916-091111-fix-silent-test-failures

## 発端

直前のチケット（gh #11 / #12）で `test-worktree.sh` の結果が run-all の集計に
乗っていないことに気づいた。開発者の指示は「全部修正」。

## 1. `run-all.sh` がテストの失敗を見落とす

`run-all.sh` は各テストの出力から `✓` / `✗` を数え、無ければ `Summary - Passed:` 行を見る。
`test-worktree.sh` は `PASS:` / `FAIL:` を出し、結果行も `  Passed: N, Failed: M` なので
どちらにも該当しない。加えて exit code を `|| true` で捨てていた。

実証（修正前）: `test-worktree.sh` に故意の失敗を 1 件仕込む → `479/479 / All tests passed / exit 0`。

### 修正

- **backstop**: 各テストの exit code を保持し、non-zero かつ失敗マークが 0 件なら
  1 failure として数える。出力形式に依存しない最後の砦
- `test-worktree.sh` の `PASS:` / `FAIL:` を `✓` / `✗` に揃え、集計に乗せた

実証（修正後）: 同じ故意の失敗 → `exit 1 / Some tests failed.`

## 2. backstop が暴いたもの: 6 スイートが壊れていた

backstop を入れた瞬間、**故意の失敗とは無関係に 6 スイートで発火**した。
いずれも成功しているように見えて、実際は `set -e` で途中中断していた。
run-all が exit code を捨てていたため、中断までに出た `✓` だけが集計され、
**誰も気づいていなかった。**

| スイート | 原因 | いつから壊れたか |
|---|---|---|
| test-simple | `git checkout -b main` が「既にある」で失敗 | git の init.defaultBranch が main になってから |
| test-basic | `ls tickets/*.md` が `tickets/README.md` を拾う | per-ticket dir 移行時 |
| test-close-after-commit-bug | 同上 + `new` 直後に commit せず `start` | 同上 + clean-tree 検査の追加時 |
| test-close-error-recovery | 同上 | 同上 |
| test-done-folder | `cp "../ticket.sh"` が repo 自身（ディレクトリ）を指す、`"$TICKET_SH"` を丸ごと 1 コマンドとして実行、`ls tickets/*.md` | 複数 |
| test-epic-management | `start` が `[start]` を commit するようになり、直後の `git commit` が「何も無い」で失敗 | 74faa01 以降 |

`test-epic-management` は **Test 1 の 5 assertion で死んでいた**（本来 22 assertion）。

### 修正方針

- レイアウト依存は `safe_get_ticket_name` / `ticket_body_path`（両レイアウト対応の既存ヘルパー）に寄せた
- `start` 後の「何も無い commit」は `|| true` で無害化
- `git checkout -b main` は既存なら checkout にフォールバック
- `test-done-folder` の `TICKET_SH` 文字列は関数に置き換えた
  （`"$TICKET_SH" init` は `timeout 5 ./ticket.sh` という名前のコマンドを探していた）
- done/ の存在検査は `ticket_body_path --done` に置き換え（flat 前提だった）

### 結果

run-all の総数が **479 → 561**。差分は

- worktree suite 34 件（集計から漏れていた）
- 中断していたスイートの、走っていなかった assertion 群

## 3. `start` が resume で `started_at` を入れない

`start` は branch を作ってから stamp するので、その間に失敗すると branch だけ残り
`started_at` は null。以降の `start` は resume 経路に入り stamp しない。結果 ticket は
永久に `todo` で `close` が `Error: Ticket not started` で止まる。前チケットで実際に踏んだ。

### 修正

resume 経路で `started_at` が null なら stamp して commit する。base に ticket の copy が
無ければ fast-forward は skip（gh #9 と同じ `skip_base_ff`）。既に started なら触らない
（`started_at` は作業を始めた時刻であり、2 回目の start は作業リンクを取り戻す手段）。

判定用に `base_has_ticket` を 1 箇所で求め、#9 の `on_own_branch` 判定とも共有した。

## 報告すべきこと

**このセッションで繰り返した「全部通りました」は、実態より強い主張だった。**
worktree suite は集計されておらず、6 スイートは途中で死んでいた。
各チケットで直接実行した分（worktree 34/34 など）は裏付けがあるが、
run-all の「All tests passed」自体が信頼できる指標ではなかった。

## 4. Docker だけで死んでいた 7 つ目: `((VAR++))`

local 561/561 green で Docker を回したら、Ubuntu / Alpine 両方で backstop が
`test-prompt` に発火した。

```
1. Testing prompt command first line...
  ✓ Prompt command returns correct first line
  Suite exited 1 ...
```

`✓` を出した直後に死ぬ。原因は

```sh
((PASS_COUNT++))
```

**post-increment は「増やす前の値」を返す。** `PASS_COUNT` が 0 のときこれは 0 を返し、
`((...))` は算術結果が 0 なら exit status 1 を返すので、`set -e` がスクリプトを殺す。
macOS の bash 3.2 では errexit が発火せず、Linux の bash 5 では発火する
——「local では通り Docker で落ちる」の 3 度目。

この罠は**このリポジトリで既知**で、`test-checklist.sh:346` に

> extract_markdown_body used to increment its line counter with ((line_num++)),

という注意書きが残っている。製品コードでは直されていたが、テスト側に 15 箇所残っていた。

`VAR=$((VAR + 1))`（常に exit 0）に一括置換した。対象:
test-prompt / test-close-no-merge / test-comprehensive / test-config-file-detection /
test-final / test-per-ticket-dir。

`test_x || ((failed++))` の形も同じ穴（`failed` が 0 のとき `||` 全体が 1 を返す）なので
同様に置換した。

## 中断していたスイートの総数

backstop が暴いたのは最終的に **7 スイート**:

test-simple / test-basic / test-close-after-commit-bug / test-close-error-recovery /
test-done-folder / test-epic-management / test-prompt

いずれも「途中まで ✓ を出して静かに死ぬ」形で、run-all は残りを集計せず green を返していた。
