---
priority: 2
tags: []
description: "Migrate config file from .yml to .yaml extension with backward compatibility"
created_at: "2025-07-10T14:52:15Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Ticket Overview

Migrate the ticket system configuration file from `.ticket-config.yml` to `.ticket-config.yaml` extension while maintaining backward compatibility. The system should prefer `.yaml` but fall back to `.yml` if the newer format doesn't exist.

## Tasks

- [ ] Update source code to check for `.ticket-config.yaml` first, then fall back to `.ticket-config.yml`
- [ ] Update `cmd_init()` to create `.ticket-config.yaml` by default
- [ ] Update all references in source code comments and error messages
- [ ] Update documentation to use `.yaml` extension
  - [ ] Update README.md and README.ja.md
  - [ ] Update spec.md and spec.ja.md  
  - [ ] Update DEV.md
  - [ ] Update help text and usage examples
- [ ] Update test files to use `.yaml` extension
- [ ] Add comprehensive test cases for config file detection:
  - [ ] Test reading `.ticket-config.yaml` when only it exists
  - [ ] Test reading `.ticket-config.yml` when only it exists
  - [ ] Test priority: `.yaml` is preferred when both files exist
  - [ ] Test error handling when neither file exists
  - [ ] Test backward compatibility with existing `.yml` projects
- [ ] Add migration logic for existing `.yml` files (optional convenience feature)
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Get developer approval before closing

## Notes

### Implementation Strategy:
1. Create a helper function to determine config file path with priority logic
2. Update all config file references to use this helper function
3. Maintain full backward compatibility - existing `.yml` files continue to work
4. New installations will use `.yaml` by default

### Backward Compatibility:
- Existing projects with `.ticket-config.yml` continue to work unchanged
- Priority order: `.ticket-config.yaml` > `.ticket-config.yml`
- No breaking changes for current users

### Test Coverage Requirements:
1. **Single file scenarios**:
   - Only `.yaml` exists → should read `.yaml`
   - Only `.yml` exists → should read `.yml`
   
2. **Both files exist scenario**:
   - Both `.yaml` and `.yml` exist → should prefer `.yaml`
   - Verify `.yml` is ignored when `.yaml` is present
   
3. **Edge cases**:
   - Neither file exists → proper error handling
   - File permissions issues
   - Malformed YAML content in either format
   
4. **Migration scenarios**:
   - Projects upgrading from `.yml` to `.yaml`
   - New projects starting with `.yaml`
