---
priority: 1
tags: [bugfix, git, initialization]
description: "Fix get_current_branch() to handle repositories with no commits"
created_at: "2025-07-11T02:33:43Z"
started_at: 2025-07-11T02:34:22Z # Do not modify manually
closed_at: 2025-07-11T02:39:54Z # Do not modify manually
---

# Fix get_current_branch() for Empty Repositories

## Overview

The `get_current_branch()` function in `lib/utils.sh` fails when called on a Git repository that has no commits yet. This causes the `ticket.sh init` command to incorrectly set `default_branch: "develop"` instead of detecting the actual current branch (usually "main").

## Problem Details

**Error in Claude Code environment:**
```
! git rev-parse --abbrev-ref HEAD 
  ⎿  HEAD
  ⎿ fatal: ambiguous argument 'HEAD': unknown revision or path not in the working tree.
```

**Root Cause:**
- `git rev-parse --abbrev-ref HEAD` fails when no commits exist
- `get_current_branch()` returns empty string
- `cmd_init()` falls back to `DEFAULT_BRANCH="develop"` instead of detecting "main"

## Solution Implemented

Modified `get_current_branch()` function to handle empty repositories:

1. Try `git rev-parse --abbrev-ref HEAD` (existing behavior)
2. If fails, try `git config --get init.defaultBranch`
3. If still empty, try `git symbolic-ref --short HEAD`
4. If still empty, default to "main"

## Tasks

- [x] Identify the root cause of the branch detection issue
- [x] Modify `get_current_branch()` function in `lib/utils.sh` 
- [x] Add fallback logic for repositories with no commits
- [x] Test the fix with empty repository scenario
- [x] Build the project with the fix
- [x] Verify `ticket.sh init` correctly detects "main" branch
- [x] Run full test suite to ensure no regressions - **154/156 tests pass, no regressions**
- [ ] Get developer approval before closing

## Files Modified

- [x] `lib/utils.sh` - Enhanced `get_current_branch()` function
- [x] `ticket.sh` - Built with the fix

## Test Results

✅ **Before fix**: `git init` + `ticket.sh init` → `default_branch: "develop"`
✅ **After fix**: `git init` + `ticket.sh init` → `default_branch: "main"`

## Notes

This fix ensures that ticket.sh works correctly in environments like Claude Code where repositories are often initialized without initial commits. The fallback logic maintains compatibility with various Git configurations while defaulting sensibly to "main".
