---
priority: 2
tags: [enhancement, usability]
description: "Add configurable success messages for new and restore commands, update documentation and samples"
created_at: "2025-07-16T01:42:48Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Add Success Messages for new and restore Commands

Add configurable success messages for `new` and `restore` commands to provide better user feedback, similar to existing `start_success_message` and `close_success_message`.

## Tasks

- [ ] Add `new_success_message` configuration option to config file
- [ ] Add `restore_success_message` configuration option to config file 
- [ ] Implement success message display in `cmd_new()` function
- [ ] Implement success message display in `cmd_restore()` function
- [ ] Set all success message defaults to empty string (disable by default)
- [ ] Update config file template in `cmd_init()` with new message options
- [ ] Update documentation in `show_usage()` function
- [ ] Update sample config in comments
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Get developer approval before closing

## Notes

**Requirements:**
- All success messages should default to empty (disabled)
- Messages should be configurable via `.ticket-config.yaml`
- Support multiline messages using YAML `|` syntax
- Empty messages should not display anything
- Update all documentation and samples

**Implementation details:**
- Follow same pattern as existing `start_success_message` and `close_success_message`
- Add constants for defaults in source code
- Display messages at end of successful command execution
