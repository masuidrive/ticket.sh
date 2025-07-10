---
priority: 1
tags: [bug, critical, close, workflow]
description: "Fix critical bug where close fails after commit during ticket workflow"
created_at: "2025-07-10T07:18:44Z"
started_at: 2025-07-10T07:19:52Z # Do not modify manually
closed_at: 2025-07-10T07:42:40Z # Do not modify manually
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

- [x] Investigate close command workflow for premature cleanup
- [x] Check if current-ticket.md is being removed too early
- [x] Check if branch switching occurs before close completion
- [x] Identify exact point where the bug occurs
- [x] Implement fix to preserve ticket state until successful close
- [x] Add test case for this specific scenario
- [x] Verify fix doesn't break normal close workflow
- [x] Run tests before closing and pass all tests (No exceptions)
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

## Solution Implemented

**Root Cause**: The `current-ticket.md` symlink was being removed at line 2157 in the `cmd_close()` function, but this happened before all operations were guaranteed to complete successfully. If any later operation failed (like git push warnings), the symlink was already gone.

**Fix Applied**: 
1. Moved the symlink removal (`rm -f "$CURRENT_TICKET_LINK"`) to the very end of the close function (line 2157)
2. Added local branch cleanup (`git branch -d $current_branch`) before symlink removal to ensure proper cleanup
3. Added proper error handling for branch deletion

**Files Modified**: 
- `src/ticket.sh` - Updated `cmd_close()` function
- `test/test-close-after-commit-bug.sh` - Added comprehensive test case

**Verification**: All tests pass (132/132) including the new test case for this specific bug scenario.

## Additional Robustness Improvements

Based on user feedback about preventing similar issues when commands fail mid-process, the following additional improvements were implemented:

**Enhanced Error Handling**:
1. **Rollback mechanism**: Store original ticket state and rollback on early failures
2. **Detailed error messages**: Provide clear guidance for manual recovery
3. **Graceful degradation**: Critical operations protected, non-critical operations can fail safely
4. **State preservation**: Keep `current-ticket.md` if cleanup fails so users can recover

**Specific Error Scenarios Handled**:
- Ticket file update failures → Complete rollback
- Git staging/commit failures → Rollback with clear recovery instructions  
- Branch switching failures → Clear instructions for manual completion
- Merge failures → Preserve state with recovery guidance
- Final commit failures → Staged changes with manual completion options
- Cleanup failures → Keep symlink for user recovery

**Files Added**:
- `test/test-close-error-recovery.sh` - Comprehensive error recovery testing

This ensures that even if individual Git commands fail during the close process, users are never left in an unrecoverable state and always have clear instructions for manual completion.
