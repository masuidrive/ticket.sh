---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "close の前に導入先のコマンドを実行し、失敗なら close を止める設定（pre_close_command / GH #18）"
created_at: "2026-10-16T11:15:06Z"
started_at: 2026-10-16T11:15:28Z # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GH #18。`close` が止まる条件は、いま `require_checklist` / `require_checklist_groups` と
作業ツリーの clean-check など固定の項目だけで、**導入先が自分の検査を close の前に差し込む
口が無い**。

PDH（masuidrive/pdh）は ticket dir の記録を `scripts/check-pdh-ticket.sh` で検査しているが、
この検査は `scripts/test-all.sh` の 1 段としてしか回らない。PR を通さず `./ticket.sh close`
で main に merge する運用では、test-all を回し忘れると検査を通らないまま close できる。
git の pre-commit hook は代わりにならない（`.git/hooks` は repo に入らず、close の commit
だけを見分ける工夫が要り、`--dry-run` では動かない）。

config に `pre_close_command:` を足して、close の直前に導入先のコマンドを 1 本走らせ、
非 0 なら close を中止する。

## 設計判断（issue の提案どおり）

1. config に `pre_close_command:`。値は shell で実行するコマンド 1 行。既定は空、空なら何もしない
2. clean-check と `require_checklist` の検査の後、commit・merge の前に、repo root で実行。
   exit が 0 以外なら close を中止し、コマンドの出力をそのまま見せる
3. `--dry-run` でも実行する
4. `--force` では飛ばさない
5. `TICKET_NAME` / `TICKET_DIR` / `TICKET_BASE_BRANCH` を環境変数で渡す
6. `cancel` では実行しない

## Tasks

- [ ] `pre_close_command` を config の読み書き（既定値・生成される config のコメント）に足す
- [ ] `close` の検査順の中に実行点を置く（clean-check / checklist の後、commit・merge の前）
- [ ] 非 0 のときに close を中止し、コマンドの出力を見せる
- [ ] `--dry-run` でも実行し、`--force` では飛ばさない
- [ ] 環境変数 `TICKET_NAME` / `TICKET_DIR` / `TICKET_BASE_BRANCH` を渡す
- [ ] `cancel` では実行しないことを確かめる
- [ ] テストを書く（空 / 0 / 非 0 / --dry-run / --force / 環境変数 / cancel）
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
