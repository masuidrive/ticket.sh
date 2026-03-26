---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "git worktreeとticket.shの組み合わせについて調査し、可能であればworktreeサポートを追加する"
created_at: "2026-03-26T14:04:57Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# git worktreeとticket.shの統合調査

git worktreeを使うと、1つのリポジトリから複数の作業ディレクトリを同時に持てる。
ticket.shと組み合わせることで、複数チケットの並行作業が可能になるか調査する。

## 調査ポイント
- git worktreeの基本動作とticket.shの現在のブランチ管理との互換性
- current-ticket.mdのパス解決がworktree環境で正しく動くか
- worktreeごとに独立したチケット作業が可能か
- ticket.sh start/closeがworktree内で正しく機能するか

Please record any notes related to this ticket, such as debugging information, review results, or other work logs, `260326-140457-explore-git-worktree-note.md`.

## Tasks

- [x] git worktreeの基本動作を理解・検証
- [x] ticket.shのブランチ・パス管理コードを読み、worktreeとの互換性を確認
- [x] worktree環境でticket.shを実際に動かして問題点を洗い出す
- [x] 課題と対応方針をまとめる
- [x] ticket.shにworktreeサポートの修正を実施（lib/utils.sh: check_git_repo()の1行修正）
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
