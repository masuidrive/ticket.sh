---
priority: 2
tags: []
description: "Improve ticket.sh UI messages and clean up version/help commands"
created_at: "2025-07-10T13:50:54Z"
started_at: 2025-07-10T13:51:26Z # Do not modify manually
closed_at: 2025-07-10T14:14:46Z # Do not modify manually
---

# Ticket Overview

Improve ticket.sh user interface by:
1. Adding helpful message about current-ticket.md updates when closing tickets with uncommitted changes
2. Cleaning up README and version command output
3. Adding GitHub URL to help and version commands

## Tasks

- [x] Add message about current-ticket.md updates in close command when uncommitted changes exist
- [x] Remove "# New change on main" from bottom of English README
- [x] Remove "Built from source files" line from version command
- [x] Add GitHub URL (https://github.com/masuidrive/ticket.sh) to help and version commands
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Update documentation if necessary
  - [x] Update README.*.md (English README updated, Japanese README didn't need changes)
  - [x] Update spec.*.md (No changes needed)
  - [x] Update DEV.md (No changes needed)
- [x] Get developer approval before closing


## Notes

Focus on improving user experience with clearer messages and proper attribution.

### Changes Implemented:

1. **Enhanced error messages**: Added "Remember to update current-ticket.md with your progress before committing." to both `lib/utils.sh:check_clean_working_dir()` and `src/ticket.sh:cmd_close()` when uncommitted changes are detected.

2. **Cleaned up README.md**: Removed the erroneous "# New change on main" section from the bottom of the English README.

3. **Improved version command**: 
   - Removed "Built from source files" line
   - Added GitHub URL (https://github.com/masuidrive/ticket.sh)

4. **Enhanced help command**: Added GitHub URL at the top of help output for better discoverability.

5. **Comprehensive testing**: All 132+ tests pass on both local macOS and Docker environments (Ubuntu 22.04, Alpine Linux).

### Files Modified:
- `lib/utils.sh` - Enhanced check_clean_working_dir function
- `src/ticket.sh` - Updated cmd_close error message, cmd_version and show_usage functions
- `README.md` - Removed erroneous section

All changes maintain backward compatibility and improve user guidance.
