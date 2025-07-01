---
priority: 2
tags: [feature]
description: "Add version command to display ticket.sh version"
created_at: "2025-07-01T01:27:03Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Add Version Command

## Overview

Add a `version` command to ticket.sh that displays the current version number. This should be accessible both through the help command and as a standalone command.

## Design Options

### Option 1: Simple version display
```bash
$ ./ticket.sh version
ticket.sh version 20250701.012703
```

### Option 2: Verbose version with build info
```bash
$ ./ticket.sh version
ticket.sh - Git-based Ticket Management System
Version: 20250701.012703
Built from source files
```

### Option 3: Include both in help and as command
- Add version info at the top of help output
- Support `./ticket.sh version` command
- Support `./ticket.sh --version` flag

## Recommendation

I recommend Option 2 (verbose) for the version command and adding the version number to the help output header. This provides:
- Clear identification of what ticket.sh is
- Version information in a standard format
- Professional appearance consistent with other CLI tools

## Tasks

- [ ] Add version display to help command output
- [ ] Implement cmd_version function
- [ ] Add version to command dispatcher
- [ ] Support --version flag as alias
- [ ] Update help text to include version command
- [ ] Test version command works correctly
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing

## Notes

- Version is generated during build time (YYYYMMDD.HHMMSS format)
- Should be consistent with how other CLI tools display version
- Consider showing both short and verbose options