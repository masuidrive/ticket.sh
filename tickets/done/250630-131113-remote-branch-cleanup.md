---
priority: 2
tags: [feature]
description: "Delete remote feature branch automatically when closing tickets"
created_at: "2025-06-30T13:11:13Z"
started_at: 2025-06-30T13:24:52Z # Do not modify manually
closed_at: 2025-06-30T14:03:04Z # Do not modify manually
---

# Automatic Remote Branch Cleanup on Close

## Overview
Implement automatic deletion of remote feature branches when closing tickets to prevent GitHub's "Compare & pull request" banner from appearing. This feature will be configurable with a default of enabled.

## Tasks

- [x] Add configuration option for remote branch deletion (default: enabled)
- [x] Implement remote branch deletion in close command
- [x] Add command-line flag `--no-delete-remote` to override config setting
- [x] Handle errors gracefully (e.g., remote branch already deleted)
- [x] Update documentation with new feature
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing

## Notes

- Remote branches left after merge cause clutter in GitHub UI
- The "Compare & pull request" banner is distracting when branches are already merged
- Feature should be configurable to accommodate different team workflows
- Default behavior should be to delete remote branches for cleaner repository management

### Configuration Example

```yaml
# Remote branch cleanup settings
# When enabled, automatically deletes the remote feature branch after closing a ticket.
# This prevents GitHub's "Compare & pull request" banner from appearing for already-merged branches.
# Set to false if you want to keep remote branches for historical reference.
delete_remote_on_close: true  # Default: true
```
