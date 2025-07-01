---
priority: 1
tags: [test, bugfix]
description: "Fix failing error message tests after branch handling update"
created_at: "2025-07-01T01:47:09Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Fix Error Message Tests

## Overview

Two error message tests are failing in CI (both macOS and Ubuntu) after the recent update that changed how `ticket.sh start` handles existing branches. The tests need to be updated to match the new behavior.


## Failing Tests

1. **Test 6: "Already started" error**
   - Expected: "Branch already exists" error message
   - Actual: "Branch '...' already exists. Resuming work..." (success message)
   - Cause: Changed behavior to checkout & restore instead of error

2. **Test 7: "Wrong branch" error**
   - Expected: "Not on a feature branch" error message  
   - Actual: "git add tickets/..." command output
   - Cause: Test may be in wrong state after Test 6 succeeds

## Tasks

- [ ] Update Test 6 to expect successful resume behavior
- [ ] Fix Test 7 to ensure proper test state
- [ ] Run tests locally to verify fixes
- [ ] Ensure tests pass on both macOS and Ubuntu
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing


## Notes

- This is a regression from the "handle-existing-branch" ticket that changed the behavior
- The new behavior is correct (checkout & restore is better UX than error)
- Only the tests need updating, not the actual functionality
