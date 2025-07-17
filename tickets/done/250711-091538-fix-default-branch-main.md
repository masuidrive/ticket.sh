---
priority: 1
tags: [bugfix, configuration, compatibility]
description: "Fix DEFAULT_BRANCH inconsistency between code and README examples"
created_at: "2025-07-11T09:15:38Z"
started_at: 2025-07-11T09:16:30Z # Do not modify manually
closed_at: 2025-07-17T09:03:48Z # Do not modify manually
---

# Fix DEFAULT_BRANCH Inconsistency

## Overview

Fix the inconsistency between README configuration examples and actual source code default values. Currently README shows `default_branch: "main"` as the "author's actual production configuration", but the source code has `DEFAULT_BRANCH="develop"`. This causes test failures and user confusion.

## Problem Analysis

**Current Inconsistency:**
- README.md example: `default_branch: "main"` (marked as author's production config)
- Source code: `DEFAULT_BRANCH="develop"` 
- Tests expect: `main` branch behavior
- Result: 2 test failures in `test-no-local-branch-deletion.sh`

**Root Cause:**
README was updated to reflect modern Git standards (`main` as default), but source code still uses legacy `develop` default.

**Decision:** 
Update source code to match README since:
1. README explicitly states "author's actual production configuration"
2. Modern Git standard is `main` (GitHub, GitLab default)
3. Tests expect `main` behavior
4. Existing users can still use `develop` via config file

## Tasks

- [x] Change DEFAULT_BRANCH from "develop" to "main" in src/ticket.sh
- [x] Run tests to verify fix (should pass all 156/156)
- [x] Run `bash build.sh` to build the project
- [x] Verify no breaking changes for existing workflows
- [x] Get developer approval before closing


## Notes

**Impact Assessment:**
- **New users**: Get modern `main` branch default
- **Existing users**: No impact if they have config file with `default_branch: "develop"`
- **Tests**: Will pass consistently 
- **Compatibility**: Maintained through user configuration
