---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "Add --worktree option to start command for parallel ticket work using git worktree"
created_at: "2026-03-26T15:16:52Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Add worktree support to start command

Add `--worktree` option to `ticket.sh start` that creates a git worktree for the ticket instead of checking out a branch in the current directory. This enables parallel work on multiple tickets.

- Default: checkout方式（現状と同じ）
- `--worktree`: git worktreeを作成して別ディレクトリで作業
- 設定で `worktree_mode: true` にすれば常時worktreeも可能
- close/cancelコマンドでworktreeの後片付けも行う

## Tasks

- [ ] Add `worktree_mode` config option and `--worktree` flag to start command
- [ ] Implement worktree creation in cmd_start
- [ ] Update cmd_close to handle worktree cleanup
- [ ] Update cmd_cancel to handle worktree cleanup
- [ ] Add `list` command worktree info display
- [ ] Add tests for worktree functionality
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
