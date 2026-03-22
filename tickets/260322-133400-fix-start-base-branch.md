---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "Fix start command to read base_branch before switching branches"
created_at: "2026-03-22T13:34:00Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Fix start command base_branch handling

## Problem
`cmd_start` forces a switch to `default_branch` (main) at line 882-907 BEFORE reading the ticket's `base_branch` at line 1028. When tickets exist only on an epic branch (not on main), the ticket file cannot be found after switching to main.

## Solution
Read the ticket file and its `base_branch` field early (before the branch-switching logic), then use `base_branch` instead of `default_branch` for the initial branch check.

## Tasks

- [ ] Read ticket file and base_branch before branch-switching logic in cmd_start
- [ ] Use base_branch (if set) as the target branch for initial check instead of default_branch
- [ ] Handle case where current branch is the base_branch (treat same as being on default_branch)
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
