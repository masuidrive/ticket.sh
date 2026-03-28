---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "Guard against checkout of branches already used by worktrees"
created_at: "2026-03-28T00:53:18Z"
started_at: 2026-03-28T00:53:45Z # Do not modify manually
closed_at: 2026-03-28T01:05:19Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# Guard against checkout of branches already used by worktrees

When `ticket.sh start` is run and the target branch is already checked out in another worktree, `git checkout` can cause worktree metadata corruption. This is especially dangerous in Docker/devcontainer environments where worktree directories on the host are not accessible.

## Root Cause

`git checkout <branch>` fails if the branch is already checked out in a worktree. In Docker environments where worktree dirs are inaccessible, git may consider them "prunable" and tools/users may run `git worktree prune`, destroying all worktree metadata.

## Fix

- In `cmd_start`, before `git checkout` or `git worktree add`, check if the branch is already checked out in another worktree using `git worktree list`
- If detected, show clear error message with guidance (use the existing worktree or `--worktree` flag)
- Never auto-prune worktrees

## Tasks

- [x] Add worktree-in-use detection before checkout in cmd_start (both new branch and existing branch paths)
- [x] Add tests for the guard (test 10 in test-worktree.sh - 2 assertions)
- [x] Run all tests (137/137 local, 129/129 Docker)
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
