# Work Notes for 260416-161005-worktree-native-close

## tmp-worktree 方式を断念した理由

当初は提案書どおり tmp-worktree（`git worktree add $tmp $default_branch` で一時 worktree を作って merge）で書き始めた。しかし検証で根本的な問題が 2 つ判明:

1. **Git は同一 branch の複数 worktree checkout を禁止**
   - main_repo が既に `default_branch`（典型的に `main`）を checkout 中
   - `git worktree add $tmp $default_branch` は fatal エラー
   - 実際にテストで `fatal: 'main' is already used by worktree at ...` を観測

2. **detached HEAD で tmp-worktree を作って `update-ref` で流し込む案も不採用**
   - `git -C $main_repo update-ref refs/heads/$default_branch $new_commit` で default_branch を進められるが、main_repo の working tree は旧 commit のまま → dirty / stale 状態
   - main_repo にいる worker から見ると「勝手に大量のファイルが stage された」ように見える
   - 結局 main_repo の状態を破壊するので本末転倒

## 採用した方針: `git -C $main_repo` 方式

- cmd_close / cmd_cancel 内で `cd $main_repo` を止め、`git -C $main_repo ...` で merge
- ticket.sh プロセスの cwd は worker の worktree のまま保たれる
- main_repo は `default_branch` を checkout 中という前提（提案者の I1 不変条件そのもの）
- main_repo が別 branch にいる場合は `check_main_repo_ready` guard が refuse

## `check_main_repo_ready` は残す判断

前チケット `260416-150656-worktree-close-cd-main-race` で追加した guard。当初「tmp-worktree で独立 merge できれば不要」と考えたが、`git -C $main_repo` で merge する以上、main_repo が別 branch だと silent HEAD 汚染が再発する。提案者の I1 前提を守るためには guard が必要。

## 提案者要求との対応

| 提案不変条件 | 対応 |
|---|---|
| I1: main_repo HEAD = default_branch 常時 | guard で検査、違反時 refuse |
| I2: worker session cwd 常時有効 | `--keep-worktree` で worktree を残す。AI agent には prompt で推奨 |
| I3: main_repo 経由しない | 部分達成: cwd 汚染なし、HEAD は動かない。index / working tree は merge の副作用で一時的に触るが commit 後は戻る |

完全な「main_repo 不関与」は別チケットで tmp-worktree + detached + update-ref 方式を再検討する余地あり（主工数: main_repo worker の working tree stale 問題解決）。

## `--keep-worktree` の設計

- AI agent: `./ticket.sh close --keep-worktree` を使い、close 後も自分の worktree を残す → cwd dangling 回避、次チケットへスムーズに移れる
- 人間: フラグなしの従来挙動（close で worktree 削除）をデフォルトで維持。prompt には agent 向けに推奨と明記
