---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "Show cd hint to main repo after close/cancel from worktree"
created_at: "2026-03-30T07:13:14Z"
started_at: 2026-03-30T07:13:47Z # Do not modify manually
closed_at: 2026-03-30T07:16:51Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# Show cd hint after close/cancel from worktree

After close/cancel from a worktree, the worktree directory is removed but the user's shell is still in that (now deleted) directory. Show a message telling them to cd to the main repo.

## Tasks

- [ ] Add cd hint message to cmd_close worktree path
- [ ] Add cd hint message to cmd_cancel worktree path
- [ ] Add test
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
