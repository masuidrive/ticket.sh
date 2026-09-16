---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "start の未知フラグ黙殺を止め、close/cancel の worktree 削除を opt-in にする（gh #11 / #12）"
created_at: "2026-09-16T08:49:15Z"
started_at: 2026-09-16T08:48:52Z # Do not modify manually
closed_at: 2026-09-16T09:01:39Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GitHub issues #11 と #12。どちらもフラグの扱いの話で、#12 の互換要件が #11 の原則
（「廃止フラグは catch-all ではなく名指しで no-op」）を前提にしているため 1 チケットにまとめる。

Closes #11, closes #12

## #11 start だけが未知フラグを黙って受け取る

`cmd_start` の引数処理だけが `-*)` で catch-all し、知らないフラグを無視して先へ進む。
他の全コマンド（new / list / restore / check / close / cancel / prompt / version）は
`Unknown option` で止まることを実測で確認済み。

実害は打ち間違いが「エラー」ではなく「別の動作」として通ること。
`--worktre`（`--worktree` の打ち間違い）が黙って通り、worktree が作られないまま
branch だけできて作業が進む。気づくのは「並列で動かない」と思ったときで、かなり後。

catch-all は廃止済み `--no-push` を受け流すためのもの。**名指しの no-op に変えれば
「昔の呼び出しが壊れない」と「打ち間違いが止まる」が両立する。**
履歴と docs を確認したところ、start の廃止フラグは `--no-push` のみ。

## #12 close / cancel の worktree 削除を opt-in にする

いまは削除が既定で、残すには `--keep-worktree` が要る。help に
「coding agents は必ず付けること」と書いてあるが、**必ず付けろと書くものは選択肢ではない。**

付け忘れると agent の cwd が消え、以降のコマンドが全部失敗する。しかも原因が
「さっき打ったフラグ」なので `getcwd: cannot access parent directories` から辿りにくい。
呼び出し側は llmhub だけで 25 箇所あり、そのすべてで「忘れないこと」を要求している。

既定を反転し、消すときだけ `--delete-worktree` を付ける形にする。

**`--keep-worktree` は deprecated として残す**（開発者判断）。名指しで受けて no-op にする。
catch-all で無視すると #11 と同じ穴になるため。既定が「残す」になった以上、
`--keep-worktree` を渡し続けても意味は正しいままなので、実行時の警告は出さない
（25 箇所に毎回ノイズを出すのは、書き換えなくて済むようにするという要件に反する）。
docs 上で deprecated と明記する。

## Tasks

- [x] #11: `cmd_start` の `-*)` catch-all を廃止し、`--no-push` を名指しの no-op にする
- [x] #11: 未知フラグは `Unknown option` + usage で return 1
- [x] #11: `start --no-push` を使っている既存テストが通ることを確認する
- [x] #12: `close` の既定を「worktree を残す」にする
- [x] #12: `close --delete-worktree` を追加する
- [x] #12: `close --keep-worktree` を名指しの no-op にする（deprecated）
- [x] #12: `cancel` にも同じ 3 点を入れる
- [x] #12: help から「coding agents must pass --keep-worktree」を削る
- [x] テストを追加する（`test-worktree.sh` に節を足す）
- [x] fixture が期待どおり作用したかを先に assert する（前チケットの反省）
- [x] Run tests before closing and pass all tests (No exceptions) — `test/run-all.sh` と `test/run-all-on-docker.sh`
- [x] Run `bash build.sh` to build the project
- [x] Update documentation if necessary
  - [x] Update README.md / README.ja.md
  - [x] Update spec.md / spec.ja.md
  - [x] Update DEV.md
- [ ] Get developer approval before closing
