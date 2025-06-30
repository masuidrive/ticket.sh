---
priority: 2
tags: [feature, ux]
description: "Add configurable success messages for start and close commands"
created_at: "2025-06-30T13:11:42Z"
started_at: 2025-06-30T14:03:26Z # Do not modify manually
closed_at: 2025-06-30T14:09:46Z # Do not modify manually
---

# Configurable Success Messages for Start and Close Commands

## Overview
Implement configurable success messages that appear at the end of `start` and `close` command output. This helps guide users on next steps in their workflow.

## Tasks

- [x] Add configuration for start success message
  - Default: "Please review the ticket content in `current-ticket.md` and make any necessary adjustments before beginning work."
- [x] Add configuration for close success message  
  - Default: "" (empty)
- [x] Implement message display at end of command output
- [x] Ensure messages work with both start and close commands
- [x] Update documentation with configuration options
- [x] Add examples of usage in README
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing

## Notes

- Success messages guide users on next steps in workflow
- Start message reminds users to review ticket before starting work
- Close message can be customized for team-specific workflows
- Messages should be displayed as the last output of the command

### Configuration Example

```yaml
# Success messages
start_success_message: |
  Please review the ticket content in `current-ticket.md` and make any
  necessary adjustments before beginning work.

close_success_message: |
  # Empty by default
```
