---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "別の ticket の worktree の中で start すると何も出さずに exit 128 で終わる (GH #16)"
created_at: "2026-10-14T07:29:46Z"
started_at: 2026-10-14T07:30:11Z # Do not modify manually
closed_at: 2026-10-14T16:11:42Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GH #16。`worktree_mode: true` の repo で、**別の ticket の worktree の中から**
`start <別の ticket>` を実行すると、**何も出力せず終了コード 128 で終わる。**

再現は確認済み（`tmp/repro16/run.sh`）。

## 原因

`src/ticket.sh` の `cmd_start`、ticket が disk に無いときに git object から
frontmatter の `branch:` を読むループ:

```bash
for _probe in "$(get_current_branch)" "$default_branch"; do
    [[ -z "$_probe" ]] && continue
    _branch_override=$(git -C "$main_repo" show "${_probe}:${ticket_file}" 2>/dev/null \
                       | _ticket_branch_from_stream)
```

1 回目の `_probe` は今いる branch（他 ticket の feature branch）で、そこには
目的の ticket ファイルが無いので `git show` が 128 で終わる。`pipefail` で
pipeline が 128 を返し、`set -e` の下でこの代入が script を落とす。
`2>/dev/null` で git の message も消えているため何も出ない。
ループ 2 回目の `$default_branch` まで進めば見つかるはずだった。

`bash -x` で abort 位置が生成物 `ticket.sh` の `_branch_override=` 行である
ことを確認済み。

## 方針

1. probe が見つけられなかったら次の probe へ進む（代入が落ちないようにする）
2. 同じ「`2>/dev/null` + `set -e` で無言死」の形が他にないか cmd_start と
   その helper を監査する
3. それでも想定外に落ちたときに 1 行出す。`set -e` で死ぬと EXIT trap は
   走るので、crash 系の終了コード（>= 126。意図的な失敗は 1〜6 しか使って
   いない）のときだけ 1 行出す。bash 3.2 で command substitution の subshell
   は EXIT trap を走らせないことを実機確認済みなので、正常な
   「失敗を許容している `$(...)`」で誤報は出ない

## 追加で見つかったもの

probe ループを直して `start` が通るようになった時点で、同じ経路の続きに別の
不具合が 2 つ見えた（どちらも cwd の tree を読んでいた）。片方だけ直すと
「start は成功するが結果が壊れている」になるので一緒に直した。

- already-started チェックが cwd から ticket を読み、`Error: File not found` を
  出した上で「まだ開始していない」と読んでいた
- `Active ticket paths:` ブロックが cwd を probe し、`layout: unknown` と存在しない
  `tickets/done/<name>.md` を出していた

詳細と、`check_main_repo_ready` について当初の見立てが誤っていた点は note.md に。

## Tasks

- [x] probe ループの `git show` 失敗を次の probe へ進めるようにする
- [x] 同種の無言死パターンを cmd_start / helper で監査し、見つかれば直す
- [x] crash 系終了コードのときだけ 1 行出す EXIT trap を入れる
- [x] 再現手順が通ることを確認する（別 worktree からの start）
- [x] test を追加する（別 worktree からの start、trap の message）
- [x] 修正前の src で新 test が落ちることを確認する
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Run `bash build.sh` to build the project
- [x] Update documentation if necessary
  - [x] Update README.*.md
  - [x] Update spec.*.md
  - [x] Update DEV.md
- [ ] Get developer approval before closing
