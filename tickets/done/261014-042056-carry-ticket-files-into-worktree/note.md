# Work Notes for 261014-042056-carry-ticket-files-into-worktree

## Implementation Details

...

## Task 1

...

## Task N

...


## Reviewer note #N

...

## 作業ログ (2026-10-14)

### 再現

issue の手順をそのまま再現。`[start]` commit に `progress.md` が入らず、main の checkout に
未追跡で残り、worktree からの `close` が `Error: Main repo has uncommitted changes` で止まる
ところまで確認した。

### in-place では起きない

worktree なしの `start` は `check_clean_working_dir` が先に止める
（`Error: Uncommitted changes (ticket files only)` → 先に commit させる）。
worktree モードは cwd の HEAD を触らないのでこの検査を通らない。よって worktree 固有。

### 原因と修正（src/ticket.sh）

`ticket.md` と `note.md` だけを名指ししている箇所が 4 つあった。

1. `start` の worktree 経路、`start_from != prev_branch` のときの `git checkout "$prev_branch" --` 群
2. 同、未 commit の ticket を worktree へ直接コピーする fallback
3. `record_start_on_base()` の `commit_paths`（`[start]` commit に入るファイル）
4. `advance_branch_ff` に渡す `<path> <hash>` 対（base 側の未追跡コピーを退かす仕組み）

修正:

- `ticket_extra_file_rels()` を追加。`TICKET_FILE_PATHS` から ticket dir 相対→repo 相対の
  path 一覧を返す単一の出所にした。`note.md` は別名で扱われているので除外。
  legacy flat ticket は `ticket_files` を持たないので空を返す
- `record_start_on_base()` を末尾可変引数 `[<rel> <hash>]...` 対応に。
  既存の 9/10 引数の呼び出しのうち 9 引数だったものに明示的に `"false"` を足し、
  可変長の末尾が曖昧にならないようにした
- hash の snapshot は既存の 2 つと同じ «commit を組む前» の地点で採る。
  これは `drop_untracked_if_unchanged` の契約（「commit を組む前に採った snapshot と
  一致すること」）に合わせる必要がある
- **fallback の cp は ticket.md の有無から切り離した。** 元は
  `[[ ! -f "${wt_path}/${ticket_file}" ]]` で括られていたので、
  「ticket.md は base に commit 済み、ticket_files だけ未 commit」だとブロック全体が
  飛ばされ、同じ漏れが別経路で起きていた（テストで両経路を押さえた）

### 検証（手動、4 シナリオ）

| | 結果 |
|---|---|
| A. 報告どおりの形 | main の status が空、`progress.md` が main で追跡済み、`[start]` commit に入る |
| B. ticket.md は commit 済み / progress.md だけ未 commit | worktree に揃う、main に残らない |
| C. `append_only_files: [progress.md]` | worktree で `✓ Append-only files intact` |
| D. `ticket_files` 無しの repo | worktree 側は `note.md ticket.md tmp` のみ、`[start]` commit も ticket.md だけ |

### テスト

`test/test-ticket-files.sh` に節「6b. the declared files travel into a worktree (issue #15)」を
追加（9 assertion）。修正前の src で走らせると、意図どおり新規 7 件が落ち、
「ticket_files 無しなら不変」の 1 件だけが通る。

- `test/run-all.sh` → 591 passed / 0 failed
- `test/run-all-on-docker.sh` → 583 passed / 0 failed

### ドキュメント

- `spec.md` / `spec.ja.md`: `ticket_files` の節に「ticket と一緒に移動する」項目
- `README.md` / `README.ja.md`: 同趣旨の項目
- `DEV.md`: `start_ticket()` に 1 項目（4 箇所と `ticket_extra_file_rels()` の位置付け、
  fallback を切り離した理由、hash を採る地点の理由）、テスト一覧の説明も更新

### ついでに直した表記漏れ

前チケット（#14）で `spec.md` / `spec.ja.md` の **Worktree Mode** 節は更新したが、
`### start [--worktree] ...` の見出しと Options 一覧に `--no-worktree` を入れ忘れていた。
同じファイルを触るついでに両方へ追記した。
