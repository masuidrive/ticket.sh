---
priority: 2
tags: [enhancement, ui, messaging]
description: "Improve new ticket creation message with start command instructions"
created_at: "2025-07-15T14:36:05Z"
started_at: 2025-07-15T14:37:37Z # Do not modify manually
closed_at: 2025-07-15T15:45:55Z # Do not modify manually
---

# Improve New Ticket Creation Message

## Overview

Add instructions to the new ticket creation message to guide users on how to properly start working on the ticket using the start command.

## Tasks

- [x] Update cmd_new() function in src/ticket.sh to include start command instructions
- [x] Use dynamic command name detection for proper ./ticket.sh or ticket.sh usage
- [x] Include the actual ticket name in the start command example
- [x] Test the new message display
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Run `bash build.sh` to build the project
- [x] Get developer approval before closing
- [x] Add bash check for non-bash shells
- [x] Optimize test suite performance  
- [x] Add detailed progress output to tests
- [x] Fix failing tests for CI deployment


## Notes

**Target message format:**
```
Created ticket file: tickets/YYMMDD-HHMMSS-slug-name.md
Please edit the file to add title, description and details.
To start working on this ticket, you **must** run: ./ticket.sh start YYMMDD-HHMMSS-slug-name
```
