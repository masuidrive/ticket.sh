---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "start が ticket の branch: を checkout 後に読むため、ticket が base branch にも在ると branch: が無効になる (GH #13)"
created_at: "2026-09-22T06:06:53Z"
started_at: 2026-09-22T06:07:11Z # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GitHub Issue #13 の修正。

`start` が ticket frontmatter の `branch:` を **base branch へ checkout した後**に読むため、
ticket が base branch にも commit 済みだと、base 側の（`branch:` を持たない）写しを読んでしまい
`branch:` が無効化される。結果として `features/<ticket名>` を新規作成してそちらへ移ってしまう。

Issue #9（ticket がその branch にしか無いケース）の姉妹ケース。#9 は `on_own_branch` 判定で
「base に無い」側を直したが、「base にも在る」側は未修正のまま。

## 再現

1. base branch (main) に ticket を commit（`branch:` なし）
2. 別 branch (`agent/issue-107`) へ移り、frontmatter に `branch: agent/issue-107` を追記して commit
3. `ticket.sh start <ticket>` を実行

- 実際: HEAD が `features/<ticket名>`（新規 branch が作られる）
- 期待: HEAD は `agent/issue-107` のまま

## 原因

`start` 内の処理順:

| 順 | 動作 |
|---|---|
| 1 | `git cat-file -e "${effective_base}:${ticket_file}"` → base にも在るので `base_has_ticket=true` |
| 2 | `on_own_branch` は 3 条件のうち `base_has_ticket != true` を満たさず false |
| 3 | `elif [[ "$current_branch" != "$effective_base" ]]` → base branch を checkout |
| 4 | `branch_name=$(ticket_branch_name "$ticket_file" ...)` → **base 側の写し**を読むので `branch:` が見えない |

## 直し方の方針

checkout の前に `ticket_branch_override` を読んでおき、それを優先する。

## 影響

bot が issue から既存 ticket を採用する流れでは、ticket は backlog として base に commit 済みなので
`branch:` を書けるのは agent branch 側だけ。この形では `branch:` が毎回無効になり、
`start` 後の commit が PR を出す branch に載らない。`start` は成功を返し `started_at` も入るため、
PR が空になるまで気づけない。

## Tasks

- [ ] 再現テストを書いて、現状で失敗することを確認する
- [ ] `src/` 側の `start` 実装を修正（checkout 前に `branch:` を読み、優先する）
- [ ] 既存経路の回帰確認（通常 start / `--worktree` / #9 の経路 / `--worktree` + `branch:`）
- [ ] `bash build.sh` を実行してビルド
- [ ] `test/run-all.sh` と `test/run-all-on-docker.sh` を実行して全テストパス（例外なし）
- [ ] ドキュメント更新（必要なら）
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
