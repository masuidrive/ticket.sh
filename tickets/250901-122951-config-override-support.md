---
priority: 2
description: "Add support for .ticket-config.override.yaml to override main configuration values"
created_at: "2025-09-01T12:29:51Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Add .ticket-config.override.yaml Support

Add support for a `.ticket-config.override.yaml` file that can override values from the main `.ticket-config.yaml`/`.ticket-config.yml` configuration file. This allows users to customize configuration locally without modifying the main config file.

This will be implemented using Test-Driven Development (TDD) with Red-Green-Refactor pattern.

Please record any notes related to this ticket, such as debugging information, review results, or other work logs, `250901-122951-config-override-support-note.md`.

## Tasks

### RED Phase: Create Failing Tests
- [ ] Create `test/test-config-override.sh` with comprehensive test cases
  - [ ] Test basic override functionality (override file overrides main config)
  - [ ] Test optional override (system works without override file)  
  - [ ] Test precedence (override values win over main config values)
  - [ ] Test with both .yaml and .yml main config files
  - [ ] Test error handling for malformed override files
  - [ ] Test that existing functionality still works
- [ ] Run new tests to confirm they fail (RED)

### GREEN Phase: Minimum Implementation
- [ ] Modify `lib/utils.sh`:
  - [ ] Add `load_config_with_override()` function
  - [ ] Modify existing config loading to support override
- [ ] Update `src/ticket.sh` config loading points (~7-8 locations) to use new system
- [ ] Run tests to confirm they pass (GREEN)

### REFACTOR Phase: Improve & Polish  
- [ ] Clean up code structure and add proper error handling
- [ ] Update documentation and help messages
- [ ] Optimize performance if needed

### Final Testing & Documentation
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md  
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
