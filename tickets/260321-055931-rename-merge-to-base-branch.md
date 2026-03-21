---
priority: 1
merge_to: default  # Override merge target branch (default: use default_branch from config)
description: "Rename merge_to to base_branch and use it in start command"
created_at: "2026-03-21T05:59:31Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Rename `merge_to` to `base_branch` and use it in `start` command

## Overview

- Rename YAML frontmatter field `merge_to` → `base_branch`
- `start` command: create feature branch from `base_branch` (error if branch doesn't exist)
- `close` command: merge back to `base_branch` (already works, just rename field)
- `cancel` command: switch back to `base_branch` (already uses default_branch, just rename)
- Backward compatibility: support `merge_to` as fallback with deprecation

## Tasks

- [ ] Rename field in ticket template (`merge_to` → `base_branch`)
- [ ] Update `cmd_start` to branch from `base_branch` (error if not found)
- [ ] Update `cmd_close` to use `base_branch` instead of `merge_to`
- [ ] Update `cmd_cancel` to use `base_branch`
- [ ] Add backward compat: read `merge_to` as fallback if `base_branch` not set
- [ ] Update show_usage / help text
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
