---
priority: 2
tags: [enhancement, ui, messaging]
description: "Improve new ticket creation message with start command instructions"
created_at: "2025-07-15T14:36:05Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Improve New Ticket Creation Message

## Overview

Add instructions to the new ticket creation message to guide users on how to properly start working on the ticket using the start command.

## Tasks

- [ ] Update cmd_new() function in src/ticket.sh to include start command instructions
- [ ] Use dynamic command name detection for proper ./ticket.sh or ticket.sh usage
- [ ] Include the actual ticket name in the start command example
- [ ] Test the new message display
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Get developer approval before closing


## Notes

**Target message format:**
```
Created ticket file: tickets/YYMMDD-HHMMSS-slug-name.md
Please edit the file to add title, description and details.
To start working on this ticket, you **must** run: ./ticket.sh start YYMMDD-HHMMSS-slug-name
```
