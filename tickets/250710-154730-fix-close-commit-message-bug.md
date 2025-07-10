---
priority: 2
tags: []
description: "Fix close command commit message bug - reading ticket content from wrong branch"
created_at: "2025-07-10T15:47:30Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
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

- [ ] Move `ticket_content=$(cat "$ticket_file")` to before branch switching
- [ ] Update the ticket name extraction to use the moved content
- [ ] Test the fix with the existing test case
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing


## Notes

Additional notes or requirements.
