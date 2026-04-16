---
priority: 1
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "close/cancel を tmp-worktree 方式に書き換え、main_repo HEAD を一切触らない。--keep-worktree フラグ追加、--force-main-switch 削除"
created_at: "2026-04-16T16:10:05Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# worktree-native close: tmp-worktree で merge、main_repo に触らない

## 背景

前チケット `260416-150656-worktree-close-cd-main-race` で `check_main_repo_ready` guard を入れたが、clean state では close 毎に main_repo HEAD が base_branch に動き default_branch に戻らない構造は残った。AI agent + parallel worktree 運用で以下の実害が出ている:

1. **main_repo HEAD drift**: close 毎に main HEAD が動き、hook / IDE 前提が壊れる
2. **worker cwd dangling**: close が worker の worktree を削除 → Claude Code の cwd が無効化 → hang
3. **race の根本解決未達**: guard で refuse はするが構造は残り、`--force-main-switch` で戻る

実測 2 件（w1 E4 T08, w4 E6 T01）で PM 介入が発生、合計 10〜70 分のロス。

## 欲しい不変条件

| # | 不変条件 |
|---|---|
| I1 | main_repo HEAD = default_branch 常時 |
| I2 | worker session cwd = 自分の worktree 常時 |
| I3 | feature → base の merge は main_repo を経由しない |

## 変更内容

### 1. close/cancel の merge ロジックを tmp-worktree 方式に書き換え

現状（worktree モード時）:
```
cd $main_repo → git checkout $default_branch → git merge --squash → commit
```

新実装（worktree モード時）:
```
tmp=$(mktemp -d)
git worktree add "$tmp" "$resolved_base_branch"
( cd "$tmp" && git merge --squash "$feature_branch" && git commit ... )
git worktree remove "$tmp"
```

- main_repo には一切触らない（cd しない、HEAD も変えない）
- `base_branch: default` でも `base_branch: epic/foo` でも同じロジック
- ticket.sh プロセスの cwd は worker の worktree のまま

### 2. `--keep-worktree` フラグを追加

close/cancel に `--keep-worktree` フラグを追加:
- 付けない場合（default）: 従来どおり worktree を削除（人間運用向け）
- 付けた場合: worktree を残す（AI agent 運用向け、cwd dangling 回避）

`ticket.sh prompt` の AI agent 向け説明に「worktree 使用時は必ず `--keep-worktree` を付けること」と明記。

### 3. `--force-main-switch` を削除

tmp-worktree 方式なら main_repo HEAD を触らないので不要。前チケットで足したばかりだが意味を失うので削除。

### 4. `check_main_repo_ready` の扱い

- tmp-worktree 方式では main_repo に触らないため、guard 自体が不要
- 削除してコードを簡素化
- ただし `git worktree add $tmp $base_branch` は base_branch が別 worktree にあると失敗するので、「base_branch が他の worktree で checkout 中の場合」の検査だけは残す（既存 Git のエラーメッセージで十分ならコード追加なしでも可）

### 非 worktree モードの挙動

worktree を使わない通常モード（`start` だけで `--worktree` なし）は**従来どおり** `git checkout $default_branch && git merge --squash` を cwd 内で実行。既存ユーザへの影響ゼロ。

Please record any notes related to this ticket, such as debugging information, review results, or other work logs, `260416-161005-worktree-native-close-note.md`.

## Tasks

- [ ] `src/ticket.sh` cmd_close: worktree モード時の merge を tmp-worktree 方式に書き換え
- [ ] `src/ticket.sh` cmd_cancel: 同様に tmp-worktree 方式に書き換え
- [ ] `--keep-worktree` フラグを close/cancel に追加、引数パースと worktree remove 分岐
- [ ] `--force-main-switch` フラグを削除（close/cancel 両方）
- [ ] `check_main_repo_ready` helper を削除（`lib/utils.sh`）
- [ ] `ticket.sh prompt` / help の説明更新（`--keep-worktree` を agent 向けに推奨）
- [ ] `test/test-worktree.sh` 更新: parallel scenario テストを新挙動向けに書き直し（main_repo HEAD が動かないこと、worker 側 worktree が `--keep-worktree` で残ることを検証）
- [ ] 既存の `--force-main-switch` テスト（No.13）を削除
- [ ] ローカル / Docker テスト全通過
- [ ] ビルドして `ticket.sh` に反映
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
