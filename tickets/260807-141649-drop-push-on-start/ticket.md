---
priority: 1
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "start が base branch を push するのをやめる。設定は追加せず落としきる（外部からの意見書 A への回答）。"
created_at: "2026-08-07T14:16:49Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

`record_start_on_base` は fast-forward 後に `auto_push` が有効なら base branch を push する。
これは `20260806` で入った新しい挙動であり、旧版 `5b98102` の `cmd_start` には `git push` の
実行が1つも無かった（`auto_push` の変数宣言があるだけで、「Note: Branch created locally.
Use 'git push -u ...' when ready to share.」と案内するのみ）。

外部（並列 worktree を5本running する repo）からの指摘:

- `start` は「これから作業を始める」宣言であって、**base branch を publish する操作だとは
  思われていない**
- base branch に未 push の commit があると **それも一緒に出る**。並列運用では
  「別の窓の未 push commit を、自分の `start` が出す」ことになる
- push 前に `git log --oneline origin/main..main` で同乗 commit を確認する運用ルールがあっても、
  **この経路は ticket.sh の内側で push するのでその確認を通らない**
- `auto_push` が `start` と `close` で共有なので、`false` にすると `close` の push まで止まる

## 決定

**`start` の push を落としきる。設定キーは追加しない。**（意見書への確認 A の回答が
「落とし切って良い」）

`start` で push しなくても base branch は `close` 時に push されるため、`start` の push が
持つ意味は「共有が数十分早まる」程度しかない。opt-in 設定を足すのは、その価値に対して
設定項目が増えるコストが見合わない。

## 影響範囲

- `record_start_on_base` から push ブロックを削除し、不要になる引数（`auto_push`,
  `repository`）を落とす
- `start --no-push` を削除する。push しないのだからフラグの意味が無い。`cmd_start` の
  引数パースは unknown flag を無視するので、既に `--no-push` を付けて運用している側は
  そのままで壊れない
- ヘルプ（`## Push Control`、`start` の項）、spec.md / spec.ja.md、README.md / README.ja.md
- `test/test-start-base-sync.sh` のセクション7（push の有無を検証している）

`auto_push` 自体は `close` 用として残す。意味を「close で push するか」に戻す。

## Tasks

- [ ] `record_start_on_base` から push を削除し、引数を整理する
- [ ] `start` の `--no-push` を削除する
- [ ] ヘルプの `## Push Control` と `start` の項を更新する
- [ ] spec.md / spec.ja.md の start セクションと設定説明を更新する
- [ ] README.md / README.ja.md の `auto_push` コメントを close 用に戻す
- [ ] `test/test-start-base-sync.sh` のセクション7 を「start は push しない」を検証する形に変える
- [ ] Run tests before closing and pass all tests (No exceptions)
  - [ ] `test/run-all.sh`
  - [ ] `test/run-all-on-docker.sh`
- [ ] Run `bash build.sh` to build the project
- [ ] Get developer approval before closing
