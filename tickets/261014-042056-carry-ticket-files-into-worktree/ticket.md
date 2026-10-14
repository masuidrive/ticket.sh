---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "worktree で start すると ticket_files で作ったファイルが main の checkout に取り残される (GH #15)"
created_at: "2026-10-14T04:20:56Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GitHub Issue #15 の修正。

`new` した ticket を commit しないまま worktree で `start` すると、`ticket.md` と `note.md` は
worktree へ移るのに、`ticket_files` で作ったファイル（例 `progress.md`）だけが main の checkout に
未追跡のまま残る。

## 再現（確認済み）

`ticket_files: [progress.md]` と `worktree_mode: true` の config で:

```
$ ./ticket.sh new probe
Created ticket file: tickets/<T>/ticket.md
Created note file: tickets/<T>/note.md
Created ticket file: tickets/<T>/progress.md

$ ./ticket.sh start <T>        # commit せずに
git -C ".../proj.worktrees/<T>" commit -m "[start] feature/<T>" -- ".../ticket.md" ".../note.md"

$ git status --short           # main の checkout
?? tickets/<T>/progress.md

$ ls .../proj.worktrees/<T>/tickets/<T>/
note.md  ticket.md  tmp
```

worktree 側から `close` すると、報告どおり止まる:

```
Error: Main repo has uncommitted changes
```

## 実害

- main の checkout に未追跡ファイルが残り、**ほかの worktree からの `close` が止まる**
- worktree 側の ticket に `progress.md` が無い。`append_only_files` に入れていると追記先が無い状態で始まる

## in-place では起きない（調査済み）

worktree なしの `start` は `check_clean_working_dir` が先に止める
（`Error: Uncommitted changes (ticket files only)` → 先に commit させる）。
worktree モードは cwd の HEAD を触らないので、この検査を通らない。よって worktree 固有。

## 原因

`ticket.md` と `note.md` だけを名指ししている箇所が 3 つある。

1. `start` の worktree 経路、`start_from != prev_branch` のときの
   `git -C "$wt_path" checkout "$prev_branch" -- <path>` 群
2. 同、最後の fallback の `cp`（未 commit の ticket を worktree へ直接コピーするところ）。
   しかも `[[ ! -f "${wt_path}/${ticket_file}" ]]` で括られているので、
   「ticket.md は base に在るが ticket_files だけ未 commit」だと丸ごと飛ばされる
3. `record_start_on_base()` の `commit_paths`（`[start]` commit に入るファイル）

加えて、base branch 側の未追跡コピーを退かして fast-forward する仕組み
（`drop_untracked_if_unchanged` / `advance_branch_ff` の `<path> <hash>` 対）も
ticket と note の 2 つ分しか受け取っていない。

## 直し方の方針

- `ticket_files` の実体パス一覧を返すヘルパを足し、上の 1〜3 すべてがそれを通る形にする
  （`note.md` は別名で扱われているので除く。legacy flat ticket には `ticket_files` が無いので空）
- `record_start_on_base()` は末尾可変引数で `<rel> <hash>` 対を受け取る。
  hash の snapshot は、既存の 2 つと同じ «commit を組む前» の地点で採る
- fallback の `cp` は ticket.md の有無に依存させず、ファイルごとに «worktree に無く cwd に在れば移す»

## Tasks

- [ ] `ticket_files` の実体パス一覧を返すヘルパを追加
- [ ] `start` の worktree 経路（git checkout 群）で ticket_files も移す
- [ ] 同、fallback の cp を ticket.md の有無から切り離し、ファイルごとに判定する
- [ ] `record_start_on_base()` の `commit_paths` に ticket_files を含める
- [ ] fast-forward 用の `<path> <hash>` 対に ticket_files を含める
- [ ] テストを追加（再現ケース / worktree 側に揃う / `[start]` commit に入る / main に残らない / close が通る / ticket_files 無しの既定は不変）
- [ ] `bash build.sh` を実行してビルド
- [ ] `test/run-all.sh` と `test/run-all-on-docker.sh` を実行して全テストパス（例外なし）
- [ ] ドキュメント更新（必要なら）
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
