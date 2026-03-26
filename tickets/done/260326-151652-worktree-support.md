---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "Add --worktree option to start command for parallel ticket work using git worktree"
created_at: "2026-03-26T15:16:52Z"
started_at: 2026-03-26T15:17:31Z # Do not modify manually
closed_at: 2026-03-26T16:32:13Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# Add worktree support to start command

Add `--worktree` option to `ticket.sh start` that creates a git worktree for the ticket instead of checking out a branch in the current directory. This enables parallel work on multiple tickets.

- Default: checkout方式（現状と同じ）
- `--worktree`: git worktreeを作成して別ディレクトリで作業
- 設定で `worktree_mode: true` にすれば常時worktreeも可能
- close/cancelコマンドでworktreeの後片付けも行う

## Tasks

- [x] Add `worktree_mode` config option and `--worktree` flag to start command
- [x] Implement worktree creation in cmd_start
- [x] Update cmd_close to handle worktree cleanup
- [x] Update cmd_cancel to handle worktree cleanup
- [x] Add `list` command worktree info display
- [x] Add tests for worktree functionality (test/test-worktree.sh - 13 tests)
- [x] Run tests before closing and pass all tests (137/137 local, 129/129 Docker)
- [x] Run `bash build.sh` to build the project
- [x] Update documentation if necessary
  - [x] Update README.md, README.ja.md
  - [x] Update spec.md, spec.ja.md
  - [x] Update DEV.md
- [ ] Get developer approval before closing
