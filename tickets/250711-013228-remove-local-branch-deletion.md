---
priority: 2
tags: [cleanup, git, workflow]
description: "Remove unnecessary local branch deletion during close command"
created_at: "2025-07-11T01:32:28Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Remove Local Branch Deletion from Close Command

## Overview

Currently the `ticket.sh close` command automatically deletes the local feature branch after merging. This is unnecessary and potentially problematic since:

1. Users might want to keep the local branch for reference
2. Local branches don't consume significant resources
3. It's safer to let users manage their local branches manually
4. The remote branch deletion is sufficient for cleanup

## Current Behavior (Problem)

When closing a ticket, the system executes:
```bash
git branch -D feature/ticket-name
```

This forces deletion of the local branch, which should be optional.

## Desired Behavior

- Keep remote branch deletion (configurable via `delete_remote_on_close`)
- Remove automatic local branch deletion
- Let users manually delete local branches if they want

## Tasks

- [ ] Locate the local branch deletion code in `src/ticket.sh`
- [ ] Remove the `git branch -D` command from the close workflow
- [ ] Keep remote branch deletion functionality intact
- [ ] Update any related documentation/comments
- [ ] Test the close command to ensure it works without local deletion
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Get developer approval before closing

## Files to Modify

- [ ] `src/ticket.sh` - Remove local branch deletion logic
- [ ] Update any related comments about branch cleanup

## Notes

This change makes the close workflow less aggressive and gives users more control over their local Git state while maintaining the important remote cleanup functionality.
