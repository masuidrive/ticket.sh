---
priority: 1
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "parallel multi-worktree race: close/cancel cd \$main_repo causes HEAD churn"
created_at: "2026-04-16T15:06:56Z"
started_at: 2026-04-16T15:11:07Z # Do not modify manually
closed_at: 2026-04-16T15:32:10Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# parallel multi-worktree race: `close`/`cancel` の `cd $main_repo` が HEAD churn を起こす

**Status**: upstream issue (discussion), PR は設計収束後
**Reporter**: Wikifarm プロジェクト PM (Claude Code Director セッション), 2026-04-16
**Priority**: 高（parallel 運用でデータ喪失リスクあり、ただし workaround で緩和可能）

## サマリ

`ticket.sh close` / `cancel` が内部で `cd $main_repo` → `git checkout $default_branch` → `git merge --squash` → `git commit` をメインリポで実行する。このため、Claude Code v2.1.49+ の native worktree 機能 (`EnterWorktree` / `--worktree`) を使った parallel multi-worktree 運用で **メインリポの HEAD が勝手に切り替わる副作用** が発生する。

## 検証結果 (ticket.sh 側コード調査)

`src/ticket.sh`:
- **1766 行目 (cmd_close)**: `cd "$main_repo"` → `git checkout $default_branch` → `git merge --squash` → `git commit`
- **2089 行目 (cmd_cancel)**: 同様に `cd "$main_repo"` → `git checkout $default_branch`
- `start --worktree` は `git worktree add -b` を使っておりメインリポ HEAD には触らない（問題なし）

**問題は close/cancel 側のみ**。レポートの「start で /workspace HEAD が features/... になる」観測は、直前 close の副作用が残留したものと推定される。

## 観測された実害

1. worker A が `/workspace/.worktrees/e4` で `ticket.sh close` 実行
2. ticket.sh が内部で `cd /workspace` → `git checkout $default_branch` → merge → commit
3. メインリポ `/workspace` の HEAD が強制切替
4. 同時にメインリポで別ブランチ作業中の worker B がいた場合、race で影響を受ける
5. 実運用では 3 worktree のうち 2 が prunable 化、1 が消失（bug-report.md 実測）

## 修正方針（段階的アプローチ）

### Step 1: `cd` を使わない（cwd 汚染の除去）

`cd "$main_repo"` をやめ、`git -C "$main_repo" ...` に置換する。プロセスの cwd は worker 自身の worktree に保たれる。

### Step 2: メインリポ状態の検査（silent HEAD switch 防止）

merge 操作の前にメインリポの HEAD / working tree 状態を検査:
- メインリポが `default_branch` 以外にいる場合 → **明示的にエラー停止**
- メインリポに uncommitted changes がある場合 → **明示的にエラー停止**

現状は暗黙に `git checkout` を叩いて HEAD を切り替えているため、失敗しない限り他ワーカーに影響が及ぶ。明示エラーにすれば parallel 運用で安全に検知できる。

### Step 3: opt-in の強制フラグ

`--force-main-switch` 等の明示フラグで、検査を無視してメインリポ HEAD を切り替える既存挙動を opt-in として残す（単独運用者の後方互換）。

### 将来案: temporary worktree で merge

根本解決として、merge 専用のテンポラリ worktree を作成してそこで `checkout default_branch + merge + commit` を行う案。メインリポ HEAD に一切触れない。ただし ticket.sh の branch 削除・commit message 採取フローに影響するため reviewer feedback を要する。

## 既知の workaround

1. **`flock -x /tmp/ticket.lock bash ticket.sh ...`**: 直列化で race を緩和（w2 T01 close で実証済み）
2. **手動 merge fallback**: ticket.sh close を避け手動で squash merge

どちらも根本解決ではないが、Step 1〜3 が入るまでの回避策として有効。

## Claude Code 側の関連 issue（参考）

- anthropics/claude-code#31471 — custom statusLine で cwd reset
- anthropics/claude-code#42837, #42844 — `cd && pwd` でリセット
- anthropics/claude-code#45478 — workspace 境界外 cd リセット

これらは `EnterWorktree` で回避可能だが、ticket.sh 内部の cd がこの回避策を無効化する。

Please record any notes related to this ticket, such as debugging information, review results, or other work logs, `260416-150656-worktree-close-cd-main-race-note.md`.

## Tasks

- [x] Step 1: `src/ticket.sh` の `cd "$main_repo"` を `git -C "$main_repo"` に置換（cmd_close / cmd_cancel 両方）
- [x] Step 2: merge 前のメインリポ状態検査を追加（default_branch 判定 + uncommitted 検出 → 明示エラー）。ticket file mutation 前に実行するよう early guard 配置
- [x] Step 3: `--force-main-switch` フラグ追加で後方互換 opt-in 経路を残す
- [ ] 将来検討: temporary worktree での merge 実装（reviewer feedback 後）
- [x] parallel multi-worktree 運用のユーザ向けドキュメント追記（help の close/cancel に `--force-main-switch` 注記）
- [x] テスト追加: 複数 worktree 同時 close でメインリポ HEAD が保護されることの検証（test-worktree.sh No.11-13）
- [x] Run tests before closing and pass all tests (No exceptions) — ローカル 137/137 + worktree 23/23
- [x] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
