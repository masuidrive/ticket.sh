---
priority: 2
tags: []
description: "Make command name in messages dynamic based on actual invocation method"
created_at: "2025-07-10T01:59:11Z"
started_at: 2025-07-10T03:39:15Z # Do not modify manually
closed_at: 2025-07-10T08:45:15Z # Do not modify manually
---

# Ticket Overview

Currently, all help messages and error messages use hardcoded `./ticket.sh` in examples. However, users might invoke the script with different methods:
- `./ticket.sh` (when script is executable)
- `bash ./ticket.sh` (when using bash explicitly)
- `./bin/ticket.sh` (when installed in a bin directory)
- `ticket.sh` (when in PATH)

The messages should dynamically show the actual command used to invoke the script.

## Problem Examples

Current messages show:
```
Usage: ./ticket.sh <command> [options]
Try: ./ticket.sh new my-feature
```

But user might have run:
```bash
bash ./ticket.sh help
```

## Solution

Detect the actual invocation method and use it in all messages:
- Use `$0` to get the command as invoked
- Handle cases like `bash ./ticket.sh` by extracting the script path
- Store in a variable and use throughout the script

## Technical Approach

1. **Detect invocation method**: Analyze `$0` and process information at script start
2. **Handle bash invocation**: Detect when script is called via `bash ./ticket.sh`
3. **Store in variable**: `SCRIPT_COMMAND` for use in messages
4. **Update all messages**: Replace hardcoded `./ticket.sh` with dynamic variable

## Tasks

- [x] Analyze current hardcoded command references in the script
- [x] Implement command detection logic using $0 and process information
- [x] Create utility function to get display command name (handle bash prefix detection)
- [x] Update all help messages to use dynamic command name
- [x] Update all error messages to use dynamic command name
- [x] Test with different invocation methods (./ticket.sh, bash ./ticket.sh, etc.)
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Get developer approval before closing


## Notes

**Invocation scenarios to handle:**
- `./ticket.sh` → show `./ticket.sh`
- `bash ./ticket.sh` → show `bash ./ticket.sh`
- `/absolute/path/ticket.sh` → show `/absolute/path/ticket.sh` (keep full path)
- `ticket.sh` (in PATH) → show `ticket.sh`

**Rationale:** Always show the actual command that the user typed to maintain consistency and enable copy-paste of examples from help messages.

**Files to check for hardcoded references:**
- Help messages
- Error messages
- Usage examples
- Command suggestions
