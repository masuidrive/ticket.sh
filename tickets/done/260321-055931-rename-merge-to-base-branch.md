---
priority: 1
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "Rename merge_to to base_branch and use it in start command"
created_at: "2026-03-21T05:59:31Z"
started_at: 2026-03-21T05:59:58Z # Do not modify manually
closed_at: 2026-03-21T06:22:17Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# Rename `merge_to` to `base_branch` and use it in `start` command

## Overview

- Rename YAML frontmatter field `merge_to` → `base_branch`
- `start` command: create feature branch from `base_branch` (error if branch doesn't exist)
- `close` command: merge back to `base_branch` (already works, just rename field)
- `cancel` command: switch back to `base_branch` (already uses default_branch, just rename)
- Backward compatibility: support `merge_to` as fallback if `base_branch` not set

## Implementation notes

- `git checkout -b branch_name base_branch` creates the feature branch directly from base_branch
- When base_branch differs from current branch, ticket files are brought over via `git checkout prev_branch -- ticket_file`
- started_at is updated after branch creation (not before) to avoid uncommitted changes blocking checkout

## Tasks

- [x] Rename field in ticket template (`merge_to` → `base_branch`)
- [x] Update `cmd_start` to branch from `base_branch` (error if not found)
- [x] Update `cmd_close` to use `base_branch` instead of `merge_to`
- [x] Update `cmd_cancel` to use `base_branch`
- [x] Add backward compat: read `merge_to` as fallback if `base_branch` not set
- [x] Update show_usage / help text
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Run `bash build.sh` to build the project
- [x] Update documentation if necessary
  - [x] Update README.*.md
  - [x] Update spec.*.md
  - [x] Update DEV.md
- [ ] Get developer approval before closing
