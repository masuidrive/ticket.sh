---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "done へ移した ticket を作業中へ戻す reopen と、done のまま直したときの close の抜け道（GH #22）"
created_at: "2026-10-16T14:56:01Z"
started_at: 2026-10-16T14:56:28Z # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GH #22。`close --no-merge` で `done/` へ移した ticket を作業中へ戻す手段が無く、戻せないまま
直すと close の前の検査が二度と走らない。

PDH の coding-bot は「人が PR を merge すること」を close とみなす運用を持つ。bot は PR の
branch で `close --no-merge` を実行して ticket を `done/` へ移し、PR を ready にする。人は
merge する代わりに PR へ「修正して」と書けるので、そのとき ticket は `done/` にある。

確認した 2 点:

- `start <ticket>` は `tickets/<name>/ticket.md` だけを見るので、`done/` にある ticket では
  `Ticket not found`（rc=1）。戻す手段が無い
- `cmd_close_no_merge` の «Idempotent: already finalized» が gate 群より手前にあって
  `return 0`。done にある ticket に対する `close --no-merge` は checklist も
  `pre_close_command`（#18）も走らせずに成功を返す

結果、修正をやり直した PR が、close の前の検査（ticket の記録・AC の承認・close 前 review の
区間）を通らないまま merge できる状態になる。#18 で «`--force` で抜けられない gate» を作った
のに、done にある状態から呼べば丸ごと飛ぶ、という穴。

## 設計判断

issue の提案 1〜6 に沿う。提案 4 の判定基準だけ変える:

- issue は「移した commit の後に commit が増えていなければ従来どおり」と書くが、
  `done/<name>/ticket.md` を触った **最新** commit を基準にすると、修正 commit が ticket 本文や
  note.md も一緒に直していた場合（note に経過を書く運用なら普通に起きる）その commit 自身が
  基準になって「増えていない」と読まれ、また検査が飛ぶ
- 基準は `--diff-filter=A` でその file を **追加した** commit にする

`reopen` が `pre_close_command` / `post_start_command` を走らせないのは、戻すことは「終わった」
とも「新しい worktree を用意した」とも主張しないから。

## Tasks

- [ ] `cmd_reopen` を実装する（done/ から元の場所へ `git mv`、`closed_at: null`、1 commit）
- [ ] base branch の上では拒否し、ticket の branch（または worktree）でだけ動くようにする
- [ ] 戻した後に symlink を張り直し `Active ticket paths:` を出す
- [ ] flat の legacy layout（`done/<name>.md` + `-note.md`）も戻せるようにする
- [ ] `--dry-run` を持たせる
- [ ] `close --no-merge` の «already finalized» を、追加 commit が無ければ 0・在れば 1 にする
- [ ] 判定の基準 commit を `--diff-filter=A` で取る（ticket 本文を直した commit に乗らない）
- [ ] main() の dispatch と show_usage に足す
- [ ] test/test-reopen.sh を書き、修正前のコードに対して落ちることを確認する
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
