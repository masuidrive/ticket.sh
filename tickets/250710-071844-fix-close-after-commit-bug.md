---
priority: 1
tags: [bug, critical, close, workflow]
description: "Fix critical bug where close fails after commit during ticket workflow"
created_at: "2025-07-10T07:18:44Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Critical Bug: Close Command Fails After Commit

## Problem Description

When working on a ticket and trying to close with uncommitted changes:
1. `ticket.sh close` fails with "Uncommitted changes" error
2. User commits the changes as instructed
3. User runs `ticket.sh close` again
4. **BUG**: Close fails with "No current ticket" error, even though user is still on feature branch

## Root Cause Analysis

The issue appears to be that something in the close workflow is prematurely removing the `current-ticket.md` symlink or switching branches before the close operation completes successfully.

## Reproduction Steps

1. Start a ticket: `ticket.sh start <ticket-name>`
2. Make changes and forget to commit
3. Run `ticket.sh close` → fails with uncommitted changes error
4. Commit changes: `git add . && git commit -m "message"`
5. Run `ticket.sh close` again → **BUG**: "No current ticket" error

## Expected Behavior

Step 5 should successfully close the ticket and merge to default branch.

## Actual Behavior

Step 5 fails with "No current ticket" error, leaving user stranded on feature branch.

## Tasks

- [ ] Investigate close command workflow for premature cleanup
- [ ] Check if current-ticket.md is being removed too early
- [ ] Check if branch switching occurs before close completion
- [ ] Identify exact point where the bug occurs
- [ ] Implement fix to preserve ticket state until successful close
- [ ] Add test case for this specific scenario
- [ ] Verify fix doesn't break normal close workflow
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing

## Investigation Areas

1. **Close command sequence**: Check the order of operations in cmd_close()
2. **Error handling**: See if failed close attempts leave system in inconsistent state
3. **Symlink management**: Verify current-ticket.md removal timing
4. **Branch state**: Check if branch switching happens prematurely

## Impact

**Critical**: This breaks the core ticket workflow and leaves users unable to complete their work properly.