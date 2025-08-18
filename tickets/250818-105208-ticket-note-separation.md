---
priority: 2
tags: []
description: ""
created_at: "2025-08-18T10:52:08Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Ticket Overview

Separate ticket content and working notes into two files to improve readability and maintainability.

## Background
Currently, tickets contain both task management information and working notes in a single file, making them too large and difficult to review. By separating them:
- Tickets remain concise (20-30 lines) focusing on tasks and requirements
- Notes can freely contain debug logs, trial-and-error records, and investigation details
- Better git diff visibility and easier PR reviews


## Tasks

- [ ] Add `note_content` configuration support to .ticket-config.yaml
- [ ] Modify cmd_new to create both ticket and note files when note_content is defined
- [ ] Support $$NOTE_PATH$$ placeholder in default_content template
- [ ] Update cmd_start to create current-note.md symlink alongside current-ticket.md
- [ ] Update cmd_close to move note files to done/ directory
- [ ] Update cmd_restore to restore note files from done/ directory
- [ ] Ensure backward compatibility when note_content is not defined
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing


## Implementation Details

### File Structure
- Ticket: `tickets/YYYYMMDD-HHMMSS-name.md`
- Note: `tickets/YYYYMMDD-HHMMSS-name-note.md`
- Symlinks: `current-ticket.md` and `current-note.md`

### Configuration
- New optional field: `note_content` in .ticket-config.yaml
- Placeholder support: `$$NOTE_PATH$$` in default_content
- Backward compatible: no notes created if note_content undefined
