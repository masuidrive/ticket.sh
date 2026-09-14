---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "ticket ごとに feature branch 名を上書きできるようにし、外部が作った branch でも start / check / close が動くようにする"
created_at: "2026-09-14T09:57:53Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

feature branch 名は `{branch_prefix}<ticket-name>` に固定されている。GitHub Actions 上の bot（masuidrive/pdh の github-bot 層。vendor の machinery が `agent/issue-<N>` を先に作って checkout する）はこの模型に乗れず、次の回避を強いられている。

- `check` が毎回「Ticket file and branch mismatch」を出し、bot は「既知の不一致なので無視する」と規則に書いている
- `close` は squash merge が使えず `--no-merge` 専用。merge は PR 経由か bot 自前の `git merge --squash`
- `start` を使えないので `started_at` を手で frontmatter に書いている

branch 名の由来が外（issue 番号）にある運用は今後も増える（bot、複数人、他ツール）。**ticket 側に「この ticket の branch はこれ」と書ければ、ticket.sh の全コマンドがそのまま動く。**

## 設計判断（提案）

1. frontmatter に `branch:` を足す（`base_branch` と対になる）。無ければ従来どおり `{branch_prefix}<ticket-name>`。
   ```yaml
   branch: agent/issue-12   # Override feature branch name (default: {branch_prefix}<ticket-name>)
   ```
2. `new --branch <name>` で指定できる（bot は `new` の時点で branch 名を知っている）。
3. `start` は `branch:` があればその branch を使う。**既に存在すれば checkout、無ければ作る**（外部が先に作ったケースと、ticket.sh が作るケースの両方）。
4. `check` / `restore` の ticket ↔ branch 対応は `branch:` を見る。
5. `close` の squash merge は `branch:` の branch を対象にする。`--no-merge` は従来どおり。
6. `list` の `started_at_only_on: <branch>` も `branch:` を尊重する。
7. `branch_prefix` の意味は変えない（`branch:` が無いときの既定）。

## 実装メモ

- branch 名を組み立てている箇所を 1 つの関数（例 `ticket_branch_name <ticket-file>`）に寄せ、frontmatter を読んで無ければ prefix + name を返す。呼び手（start / restore / check / close / list）を全部それに置き換える。
- `branch:` の値の検証は `git check-ref-format --branch`。
- worktree 名は従来どおり ticket-name 由来でよい（branch 名を dir 名に使うと `/` を含む）。

## What / Acceptance Criteria

- [ ] `new --branch <name>` で frontmatter に `branch:` が入る
- [ ] `branch:` がある ticket は、`start` がその branch を使う（存在すれば checkout、無ければ作成）
- [ ] `check` / `restore` が `branch:` の branch と ticket を対応付け、mismatch を出さない
- [ ] `close` が `branch:` の branch を base へ squash merge する
- [ ] `branch:` が無い ticket は現行と同一の挙動
- [ ] 不正な branch 名は `new --branch` で拒否する
- [ ] spec.md / spec.ja.md に説明が入る

## Tasks

- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
