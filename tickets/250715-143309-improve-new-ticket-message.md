---
priority: 2
tags: [enhancement, ui, messaging]
description: "Improve new ticket creation message with start command instructions"
created_at: "2025-07-15T14:33:09Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Improve New Ticket Creation Message

## Overview

Enhance the message displayed after creating a new ticket to include instructions for starting the ticket with the correct command. This will help users understand the proper workflow and avoid confusion about how to begin work on a ticket.

## Tasks

- [ ] Find cmd_new() function in src/ticket.sh that outputs the current message
- [ ] Update the message to include start command instructions
- [ ] Use dynamic command name (./ticket.sh or ticket.sh) based on context
- [ ] Include the actual ticket name in the start command example
- [ ] Add emphasis (bold) to the "必ず" (must) instruction
- [ ] Test the new message display
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Get developer approval before closing


## Notes

**Current message:**
```
Created ticket file: tickets/YYMMDD-HHMMSS-slug-name.md
Please edit the file to add title, description and details.
```

**Requested enhancement:**
Add English message explaining that when starting the ticket, users **must** run the appropriate start command to switch branches properly.

**Target message format:**
```
Created ticket file: tickets/YYMMDD-HHMMSS-slug-name.md
Please edit the file to add title, description and details.
To start working on this ticket, you **must** run: ./ticket.sh start YYMMDD-HHMMSS-slug-name
```
