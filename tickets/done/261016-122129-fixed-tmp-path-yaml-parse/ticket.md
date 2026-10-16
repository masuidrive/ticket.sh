---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "close / start / cancel の固定パス /tmp/ticket_yaml.yml をやめる（GH #20）"
created_at: "2026-10-16T12:21:29Z"
started_at: 2026-10-16T12:21:48Z # Do not modify manually
closed_at: 2026-10-16T12:40:54Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GH #20。`cmd_close` / `cmd_start` / `cmd_cancel` が ticket の frontmatter を parse する
ときに、プロセスごとに固定のパス（`/tmp/ticket_yaml.yml`、`/tmp/ticket_yaml_early.yml`）
へ書き出してから `yaml_parse` している。`yaml-sh/yaml-sh.sh` も `/tmp/yaml_parse_$$.tmp`。

再現済みの 2 つの帰結:

1. **並走すると他の ticket の frontmatter を読む。** repo 2 つで `close --dry-run` を
   同時に 100 回走らせて 48 回。merge 先の branch 名が両方に在る場合は override が
   成功してしまい、何のエラーも出さずに **merge 先を間違える**（60 回中 27 回）。
   worktree を分けた並走は `ticket.sh` が自分で宣伝している使い方である。
2. **共有マシンで他人のファイルを壊せる。** 固定の名前・`O_EXCL` 無し・world-writable
   な `/tmp`（CWE-377 / CWE-59）。`/tmp/ticket_yaml.yml` を symlink として先に
   置かれると `>|` が辿り、そのファイルが frontmatter で上書きされる。`rm -f` が
   消すのは symlink の方なので痕跡も残らない。

## 設計判断

1. 固定パスをやめ `mktemp` にする（`TMPDIR` を尊重。`ticket_frontmatter_text()` が
   #16 で既にこの形）
2. 3 箇所に同じ 4 行を繰り返さず `yaml_parse_text <yaml_content>` helper に寄せる。
   `mktemp` が失敗したら黙って進まず理由を出して止める
3. `yaml-sh/yaml-sh.sh` の `/tmp/yaml_parse_$$.tmp` も `mktemp` にする
4. `get_yaml_field` への置き換えでは**ない**。`description: |`（block scalar）は
   `yaml_get` でなければ読めず、`get_yaml_field` は `|` を返す。直すのは
   「パスが固定であること」で「yaml_parse を使っていること」ではない

## Tasks

- [x] `yaml_parse_text()` を lib に足す（mktemp / 失敗時は理由を出して止まる）
- [x] `cmd_close` / `cmd_start` / `cmd_cancel` の 3 箇所を差し替える
- [x] `yaml-sh/yaml-sh.sh` の固定パスも mktemp にする
- [x] 並走しても互いの frontmatter を読まないテスト
- [x] 固定パスに symlink を置いても辿らないテスト
- [x] `description: |` が従来どおり読めることのテスト
- [-] `TMPDIR` を見ることのテスト - skip: `mktemp`（template 無し）は GNU / busybox では `TMPDIR` を見るが macOS は見ない（per-user の temp dir を使う）。置き場所は platform の裁量で、必要な性質（private・予測不能・`O_EXCL`）はどちらも満たすので、「後に残っていないか」を見る テストに替えた（note.md 参照）
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Run `bash build.sh` to build the project
- [x] Update documentation if necessary
  - [x] Update README.*.md
  - [x] Update spec.*.md
  - [x] Update DEV.md
- [x] Get developer approval before closing（「直して」）
