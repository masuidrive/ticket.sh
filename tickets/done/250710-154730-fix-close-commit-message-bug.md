---
priority: 2
tags: []
description: "Fix close command commit message bug - reading ticket content from wrong branch"
created_at: "2025-07-10T15:47:30Z"
started_at: 2025-07-10T15:48:51Z # Do not modify manually
closed_at: 2025-07-10T15:51:20Z # Do not modify manually
---

# Fix Close Command Commit Message Bug

## Problem
The close command has a critical bug where the commit message contains the initial template content instead of the actual updated ticket content with progress notes.

## Root Cause
In the `cmd_close()` function in `src/ticket.sh`, line 1273 reads the ticket content AFTER switching to the default branch (line 1263). This causes the commit message to contain the original template content from the default branch instead of the updated content from the feature branch.

The sequence is:
1. Line 1223: Update ticket file with `closed_at` timestamp
2. Line 1247: Commit changes to feature branch  
3. Line 1263: Switch to default branch (ticket file reverts to original state)
4. Line 1273: Read ticket content from default branch (gets template content)

## Solution
Move the ticket content reading to BEFORE switching branches, right after updating the `closed_at` field.

## Tasks

- [x] Move `ticket_content=$(cat "$ticket_file")` to before branch switching
- [x] Update the ticket name extraction to use the moved content
- [x] Test the fix with the existing test case
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Run `bash build.sh` to build the project
- [x] Update documentation if necessary
  - [x] Update README.*.md
  - [x] Update spec.*.md
  - [x] Update DEV.md
- [x] Get developer approval before closing


## Notes

### Fix Implementation Details

The bug was in the `cmd_close()` function in `/Users/masuidrive/Develop/bloom/ticket-sh/src/ticket.sh`. 

**Original problematic sequence:**
1. Line 1223: Update ticket file with `closed_at` timestamp on feature branch
2. Line 1247: Commit changes to feature branch
3. Line 1263: Switch to default branch (ticket file reverts to original state)
4. Line 1273: Read ticket content from default branch (gets template content)

**Fixed sequence:**
1. Line 1223: Update ticket file with `closed_at` timestamp on feature branch
2. Line 1247: Commit changes to feature branch  
3. **Lines 1258-1259: Read ticket content BEFORE switching branches**
4. Line 1268: Switch to default branch
5. Use the captured content for commit message

### Test Results
- All 146 tests pass
- The specific test `test-close-commit-message.sh` now passes all 7 assertions
- Commit message now correctly includes:
  - Proper started_at timestamp (not null)
  - Updated closed_at timestamp  
  - All progress notes added during development
  - Complete work documentation

### Files Modified
- `/Users/masuidrive/Develop/bloom/ticket-sh/src/ticket.sh` - Fixed the bug
- `/Users/masuidrive/Develop/bloom/ticket-sh/ticket.sh` - Rebuilt with fix
