---
priority: 2
tags: []
description: ""
created_at: "2025-08-18T10:52:08Z"
started_at: 2025-08-18T10:52:39Z # Do not modify manually
closed_at: 2025-08-19T03:53:00Z # Do not modify manually
---

# Ticket Overview

Separate ticket content and working notes into two files to improve readability and maintainability.

## Background
Currently, tickets contain both task management information and working notes in a single file, making them too large and difficult to review. By separating them:
- Tickets remain concise (20-30 lines) focusing on tasks and requirements
- Notes can freely contain debug logs, trial-and-error records, and investigation details
- Better git diff visibility and easier PR reviews


## Tasks

- [x] Add `note_content` configuration support to .ticket-config.yaml
- [x] Modify cmd_new to create both ticket and note files when note_content is defined
- [x] Support $$NOTE_PATH$$ placeholder in default_content template
- [x] Update cmd_start to create current-note.md symlink alongside current-ticket.md
- [x] Update cmd_close to move note files to done/ directory
- [x] Update cmd_restore to restore note files from done/ directory
- [x] Ensure backward compatibility when note_content is not defined
- [x] Fix bash interactive mode issue in init command (escaped backticks in heredoc)
- [x] Fix test failures by adjusting for note_content as default
- [x] Add timeout command to all test executions
- [x] Handle environments without timeout command (macOS fallback)
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Run `bash build.sh` to build the project
- [x] Update documentation if necessary
  - [x] Update README.*.md
  - [x] Update spec.*.md
  - [x] Update DEV.md
- [x] Update prompt command to include note file information
- [x] Update prompt command Closing Tickets section to include git commit instructions
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

## Issues Found and Fixed

### 1. Bash Interactive Mode Issue in init Command
**Problem**: The init command would freeze when run normally due to unescaped backticks in heredoc causing bash to launch in interactive mode.

**Root Cause**: In the README.md heredoc within cmd_init, backticks (``` ` ```) were not escaped, causing command substitution attempt.

**Fix Applied**: Escaped all backticks in heredoc with backslash (`\`\`\``)

**Why Tests Didn't Catch It**: All tests used `</dev/null` stdin redirection which prevented interactive bash from launching

### 2. Test Improvements Needed
**Current Issue**: Tests always use stdin redirection (`</dev/null`), hiding potential interactive mode problems

**Root Cause**: All test commands use `</dev/null` to prevent interactive sessions, which masked the backtick issue

**Proposed Solutions**:
1. Add tests that run commands WITHOUT stdin redirection to catch interactive mode issues
2. Use `timeout` command wrapper for all tests to detect and fail on hanging commands
3. Create a specific test case for init command without redirection

**Status**: Not yet implemented - left for future improvement to avoid breaking existing test infrastructure
