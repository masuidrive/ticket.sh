---
priority: 2
tags: [enhancement]
description: "Handle existing branch case in start command - checkout and restore instead of error"
created_at: "2025-06-30T23:54:46Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Handle Existing Branch in Start Command

## Overview

When running `ticket.sh start <ticket-name>` and the feature branch already exists, instead of showing an error, the command should checkout the existing branch and restore the current-ticket.md symlink.

## Current Behavior

```
Error: Branch already exists
Branch 'feature/xxx' already exists. Please:
1. Switch to existing branch: git checkout feature/xxx
2. Or delete existing branch if no longer needed
3. Use 'ticket.sh restore' to restore ticket link
```

## Desired Behavior

If the branch exists:
1. Checkout the existing branch
2. Restore the current-ticket.md symlink
3. Show a message indicating that we're continuing work on an existing ticket

## Tasks

- [ ] Modify cmd_start to detect existing branch
- [ ] When branch exists, checkout instead of error
- [ ] Automatically run restore logic after checkout
- [ ] Update success message to indicate continuing work
- [ ] Test the new behavior
- [ ] Update documentation if needed
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing

## Notes

- This improves the workflow when switching between tickets
- Makes it easier to resume work on a ticket
- Should still validate that the ticket file exists