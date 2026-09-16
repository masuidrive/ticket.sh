---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "close --no-merge が feature branch 上で走るとき checklist / append_only の gate を効かせる（gh #10）"
created_at: "2026-09-16T08:31:56Z"
started_at: 2026-09-16T08:32:19Z # Do not modify manually
closed_at: 2026-09-16T08:45:32Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GitHub issue #10。

Closes #10

`close --no-merge` は checklist / append_only の gate を呼んでいない。これは
「merge 後に base branch 上で走る」という前提に基づく意図的な設計で、#7 の実装時に
spec / README / DEV に制約として明記した。

その前提が崩れた。GitHub Actions の `GITHUB_TOKEN` は保護された default branch へ
push できない（`GH006`）ため、PDH の github-bot が

- 旧: merge 後に base branch 上で `close --no-merge` して push
- 新: **PR を作る前に feature branch 上で `close --no-merge` し、移動を PR 差分に載せる**

へ移行した。同じコマンドが「gate を測れる場所」で走るのに飛ばされるため、
`--force` でも抜けられないと宣言した gate が、経路を変えるだけで**無音で**迂回される。

## 事実確認（済）

- `cmd_close_no_merge` に `checklist_gate` / `checklist_require_groups` /
  `append_only_check` の呼び出しは 0 件
- default branch 上の `check` は Case 3 で "No active ticket" を返して
  `checklist_ticket` 未設定のまま return するので、checklist を一切出力しない
  （issue が「死んだコードだった」と書いているのはこれ）

## 方針

`close --no-merge` が **base branch 以外の branch 上で走っているとき**は gate を効かせる。
base branch 上（merge 後）では従来どおり飛ばす——そこで拒否しても PR は既に merge 済みで、
ticket だけが done/ に移らない中途半端な状態になり、行動につながらないため。

flag による opt-in にはしない。迂回が無出力で気づけないことが issue の動機であり、
3 つの gate はいずれも config で opt-in（既定は空 / false）なので、既に gating を
要求しているプロジェクトにしか影響しない。

base は ticket の `base_branch`、無ければ `default_branch`（`cmd_close` と同じ解決）。

## Tasks

- [x] `cmd_close_no_merge` が config の gate キーと base branch を読む
- [x] base branch 以外で走っているときだけ gate を効かせる
  - [x] `require_checklist_groups`（欠落グループ）
  - [x] `require_checklist`（未記入）
  - [x] `append_only_files`（失われた行）
- [x] 何も変更する前に拒否する（closed_at も git mv もしない）
- [x] base branch 上では従来どおり飛ばす
- [x] gate キーが未定義なら現行と同一の挙動
- [x] `--dry-run` が `--no-merge` と併用時に黙って無視されている件も直す（gate を事前に見るため）
- [x] テストを追加する（`test/test-close-no-merge.sh` に節を足す）
- [x] テストが python3 / perl に依存しないようにする（Alpine には無い）
- [x] Run tests before closing and pass all tests (No exceptions) — `test/run-all.sh` と `test/run-all-on-docker.sh`
- [x] Run `bash build.sh` to build the project
- [x] Update documentation if necessary
  - [x] Update README.md / README.ja.md
  - [x] Update spec.md / spec.ja.md
  - [x] Update DEV.md
- [ ] Get developer approval before closing
