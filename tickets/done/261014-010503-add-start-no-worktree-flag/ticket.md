---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "start に --no-worktree を足し、worktree_mode: true でも 1 回だけ worktree を作らずに進められるようにする (GH #14)"
created_at: "2026-10-14T01:05:03Z"
started_at: 2026-10-14T01:05:26Z # Do not modify manually
closed_at: 2026-10-14T04:20:36Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GitHub Issue #14 の対応。機能追加。

`worktree_mode: true` のとき、**1 回の `start` だけ worktree を作らずに進める `--no-worktree`** を足す。

## なぜ要るか

並行して ticket を進める repo では `worktree_mode: true` を既定にしたい（`--worktree` の付け忘れで
main の checkout 内で branch が切り替わると、同じ checkout で動く別 session の作業ツリーを巻き込む）。

一方で「1 つの checkout の中で 1 ticket だけを進める」呼び出し側もある。GitHub Actions の coding bot が
そうで、runner の checkout で `ticket.sh start "$TICKET_NAME"` を実行し、そのまま同じディレクトリで
作業する。この呼び出し側には worktree の利点が無い（1 run = 1 ticket、並行 session なし）のに、
`worktree_mode: true` の repo では `start` が `../<project>.worktrees/` に worktree を作り、bot は
元の checkout で作業を続けてしまう。

いまは 1 回だけ外す手段が無い。`start` の引数は `--worktree` と `--copy-file` だけで、未知のフラグは
#11 の修正どおりエラーになる。結果、«人の端末では worktree を既定にしたい» と «bot は worktree を
使わない» を同じ `.ticket-config.yaml` で両立できない。

## 要件

1. `start` に `--no-worktree` を足す。`worktree_mode: true` でも、その 1 回は worktree を作らない
2. `--worktree` と `--no-worktree` の同時指定はエラー（後勝ちにすると、どちらが効いたか分からない）
3. help の `start` の行と、`worktree_mode` の設定例のコメントに `--no-worktree` を書く

## 実装上の注意

- **フラグ名を名指しで受ける。** #11 と同じ理由で、catch-all にすると打ち間違いが通る穴に戻る
- `worktree_mode` の読み込みは、**フラグで明示されていないときだけ**効くようにする必要がある。
  現在は引数解析の**後**で `worktree_mode` が `use_worktree=true` に上書きしている
- issue が示している形:

  ```
  --worktree)    use_worktree=true;  worktree_flag_set=true ;;
  --no-worktree) use_worktree=false; no_worktree_flag_set=true ;;
  ```

- `--copy-file` は worktree を実際に作ったときだけ参照される。`--no-worktree` と併用されたときの
  扱いを決めて（無害な no-op か、エラーか）テストで固定する

## Tasks

- [x] `src/ticket.sh` の `cmd_start()` に `--no-worktree` を追加し、`worktree_mode` の上書き順を直す
- [x] `--worktree` と `--no-worktree` の同時指定をエラーにする
- [x] `--no-worktree` + `--copy-file` の扱いを決める → warning を出して続行（理由は note.md）
- [x] help の `start` 行を更新
- [x] `init` が書き出す config の `worktree_mode` コメントを更新
- [x] テストを追加（`--no-worktree` が worktree_mode を上回る / 同時指定がエラー / 打ち間違いは通らない / 既定の挙動は不変）
- [x] `bash build.sh` を実行してビルド
- [x] `test/run-all.sh` と `test/run-all-on-docker.sh` を実行して全テストパス（例外なし）
- [x] ドキュメント更新
  - [x] Update README.*.md
  - [x] Update spec.*.md
  - [x] Update DEV.md
- [ ] Get developer approval before closing
