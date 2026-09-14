---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "check / close が、指定ファイルの行を削った commit を branch 上で検出して拒否する"
created_at: "2026-09-14T09:57:53Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

PDH は ticket dir の `progress.md` を **追記だけ**（経緯は消さない）と決めた。いまは PDH 側の `scripts/check-pdh-ticket.sh`（`test-all.sh` の 1 段）が `git log <base>..HEAD -p -- progress.md` の削除行を数えて落としているが、**test-all を回さない run（human gate で止まる run）では捕まらない。**ticket と branch の対応を知っていて、close の前に必ず走るのは ticket.sh の `check` / `close` なので、そこで数えるのが筋。

## 設計判断（提案）

1. config に `append_only_files:`（ticket dir 相対の path のリスト）を足す。
   ```yaml
   append_only_files:
     - progress.md
   ```
2. 判定は **base branch 以降の commit のどれかがそのファイルの行を削っているか**（`git log <base>..HEAD -p --format= -- <file>` の `^-[^-]` 行）。作業 tree の未 commit 変更は見ない（commit 前に直せる）。
3. plain `check` は削除を表示するが exit 0（`require_checklist_groups` と同じ方針: mid-ticket で落ちると機能ごと切られる）。**`close` は拒否する**。`--force` では抜けない。`--dry-run` で見える。
4. `cancel` はゲートしない。
5. base は ticket の `base_branch`、無ければ `default_branch`（close の squash 先と同じ）。`origin/<base>` が無い（fetch していない）ときは local の `<base>` を使い、それも無ければ警告して skip。

## 実装メモ

- `lib/checklist.sh` と同じ層に `lib/append-only.sh` を置くか、`check` の実装の隣に関数を足す。
- 拒否メッセージは「どのファイルの、どの commit が、何行削ったか」（`git log --format=%h -p` から拾える）。
- 削った行を戻す手順を 1 行添える（「削った行を再度追記する。過去の commit は書き換えない」）。

## What / Acceptance Criteria

- [ ] `append_only_files` に列挙したファイルの行を削る commit が base 以降にあると、`close` が拒否する
- [ ] 拒否メッセージに file・commit・削除行数が出る
- [ ] plain `check` は同じ内容を表示するが exit 0
- [ ] `--force` で迂回できない。`--dry-run` で拒否が見える
- [ ] キー未定義なら現行と同一の挙動
- [ ] ファイルが存在しない ticket では何もしない（存在の強制は別の機構）
- [ ] spec.md / spec.ja.md に説明が入る

## Tasks

- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
