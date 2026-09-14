---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "GitHub issues #6 / #7 / #8 を実装する（ticket_files, append_only_files, frontmatter branch:）"
created_at: "2026-09-14T10:07:59Z"
started_at: 2026-09-14T10:08:26Z # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GitHub issues #6 / #7 / #8 の 3 件をまとめて実装する。

作業ログ・調査結果は `note.md` に記録する。

## #6 ticket_files — new が note.md 以外の追加ファイルも作れるようにする

config の `ticket_files:` に `path` / `content` の組を列挙すると、`new` が
ticket dir にそのファイルを作る。`note_content` は後方互換で残し、
`ticket_files` に `note.md` があればそちらを優先する。

## #7 append_only_files — 行を削った commit を close で拒否する

config の `append_only_files:` に列挙した ticket dir 相対のファイルについて、
base branch 以降の commit がその行を削っていたら `close` を拒否する。
plain `check` は表示するだけで exit 0。`--force` では抜けられない。

## #8 frontmatter `branch:` — ticket ごとに feature branch 名を上書きする

frontmatter に `branch:` があればそれを feature branch として使う。
`new --branch <name>` で指定できる。start / restore / check / close / cancel /
list がすべて `branch:` を尊重する。

## Tasks

### #6 ticket_files
- [ ] yaml-sh が list の中の複数行 `content`（`|` ブロック）を読めるか確認する
- [ ] `config_read_list` と同じ層に `ticket_files` を読む仕組みを足す
- [ ] `cmd_new` が `ticket_files` の各ファイルを作る（`$$TICKET_NAME$$` / `$$NOTE_PATH$$` 置換、既存ファイルは上書きしない）
- [ ] `ticket_files` に `note.md` がある場合は `note_content` より優先する
- [ ] flat（legacy）レイアウトでは作らない
- [ ] `emit_active_ticket_paths`（start / restore）に、作ったファイルの実パスを出す
- [ ] `ticket_files` 未定義なら現行と同一の挙動

### #7 append_only_files
- [ ] `lib/append-only.sh` を追加し、`build.sh` に組み込む
- [ ] base（ticket の base_branch、無ければ default_branch）以降の commit から削除行を数える
- [ ] `close` は拒否する（`--force` で迂回不可、`--dry-run` で見える）
- [ ] plain `check` は同じ内容を表示するが exit 0
- [ ] 拒否メッセージに file・commit・削除行数と復旧手順を出す
- [ ] `cancel` はゲートしない
- [ ] `origin/<base>` が無ければ local `<base>`、それも無ければ警告して skip
- [ ] キー未定義／ファイル不在なら何もしない

### #8 frontmatter branch:
- [ ] `ticket_branch_name` / `ticket_name_for_branch`（逆引き）を lib に足す
- [ ] `new --branch <name>` を追加（`git check-ref-format --branch` で検証）
- [ ] `start` が `branch:` の branch を使う（存在すれば checkout、無ければ作成）
- [ ] `restore` / `check` が `branch:` の branch と ticket を対応付ける
- [ ] `close` が `branch:` の branch を base へ squash merge する
- [ ] `cancel` が `branch:` の branch を受け付ける
- [ ] `list` の `started_at_only_on:` / worktree 表示が `branch:` を尊重する
- [ ] `branch:` が無い ticket は現行と同一の挙動

### 共通
- [ ] テストを追加する（`test/test-ticket-files.sh` / `test-append-only.sh` / `test-branch-override.sh`）
- [ ] Run tests before closing and pass all tests (No exceptions) — `test/run-all.sh` と `test/run-all-on-docker.sh`
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.md / README.ja.md
  - [ ] Update spec.md / spec.ja.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
