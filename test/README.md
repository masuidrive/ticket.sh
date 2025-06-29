# Test Suite Documentation

This document describes the purpose and structure of the ticket.sh test suite.

## Overview

The test suite consists of multiple test files that verify different aspects of ticket.sh functionality. Due to historical development, there is some overlap between test files, but each serves a specific purpose.

## Test Files

### Core Functionality Tests

#### test-basic.sh
- **Purpose**: Tests core functionality with minimal setup
- **Coverage**: init, new, list, start, close, status filter
- **Characteristics**: 
  - Simplest test structure
  - No error case testing
  - Good for quick verification of basic features
- **Dependencies**: test-helpers.sh

#### test-simple.sh
- **Purpose**: Basic workflow with error handling
- **Coverage**: Same as test-basic.sh plus error conditions
- **Characteristics**:
  - Tests git repository requirements
  - Includes restore command testing
  - Builds ticket.sh before testing
- **Dependencies**: None (standalone)

#### test-comprehensive.sh
- **Purpose**: Comprehensive test suite with detailed reporting
- **Coverage**: Similar to test-simple.sh with better structure
- **Characteristics**:
  - Does not use `set -e` (allows individual test failures)
  - Counts PASSED/FAILED tests
  - Colored output for better readability
- **Dependencies**: None (standalone)

#### test-final.sh
- **Purpose**: Final test suite with improved error handling
- **Coverage**: Standard workflow plus error conditions
- **Characteristics**:
  - Suppresses error output for cleaner results
  - Uses arrays to track test results
  - More robust close command testing
- **Dependencies**: None (standalone)

### Advanced Feature Tests

#### test-additional.sh
- **Purpose**: Edge cases and advanced features not covered by basic tests
- **Coverage**:
  - Duplicate ticket prevention
  - Branch state validation
  - Count parameter functionality
  - Custom branch prefixes
  - Multiple ticket workflows
  - YAML frontmatter edge cases
  - Priority sorting
  - Auto-push configuration
- **Dependencies**: test-helpers.sh (uses advanced helper functions)

#### test-missing-coverage.sh
- **Purpose**: Tests based on spec.ja.md to ensure complete coverage
- **Coverage**:
  - File specification flexibility (3 methods)
  - Invalid state operations
  - Invalid parameter values
  - Long slugs (100+ characters)
  - Broken YAML handling
  - Multi-level branch prefixes
  - Multiple status flags
- **Dependencies**: test-helpers.sh

#### test-utf8.sh
- **Purpose**: UTF-8 character support and locale handling
- **Coverage**:
  - UTF-8 in ticket slugs, descriptions, and content
  - UTF-8 in Git commit messages
  - UTF-8 in YAML tags
  - Locale auto-setting verification
  - Long UTF-8 strings
  - Emoji support
- **Dependencies**: test-helpers.sh

#### test-error-messages.sh
- **Purpose**: Verify error messages match specification
- **Coverage**:
  - All error conditions and their messages
  - Permission errors
  - Git repository errors
  - Invalid parameter errors
  - State validation errors
  - Done folder auto-creation
- **Dependencies**: test-helpers.sh

## Helper Files

### test-helpers.sh
- **Purpose**: Shared utility functions for tests
- **Functions**:
  - `setup_test_repo()`: Creates test git repository
  - `safe_get_first_file()`: Cross-platform file selection
  - `safe_get_ticket_name()`: Extract ticket name from path
  - `sed_i()`: Portable in-place sed editing
- **Usage**: Sourced by test files that need these utilities

### test-compat.sh
- **Purpose**: Cross-platform compatibility layer
- **Features**:
  - Normalizes date command differences (GNU vs BSD)
  - Handles busybox environments
  - Provides consistent behavior across platforms

## Execution Scripts

### run-all.sh
- **Purpose**: Runs all tests locally
- **Features**:
  - Executes tests in recommended order
  - Provides summary of all test results
  - Exits with appropriate status code

### run-all-on-docker.sh
- **Purpose**: Runs tests in Docker containers
- **Environments**:
  - Ubuntu 22.04
  - Alpine Linux (with busybox)
- **Features**:
  - Tests cross-platform compatibility
  - Isolates test environment
  - Verifies minimal dependencies

## Test Overlap and Redundancy

Due to iterative development, the four basic test files (test-basic.sh, test-simple.sh, test-comprehensive.sh, test-final.sh) have significant overlap:

1. **Common tests**: init, new, list, start, close
2. **Differences**: Error handling approach, output formatting, test structure
3. **Recommendation**: These could be consolidated in future refactoring

## Recommended Test Execution Order

For comprehensive testing:

1. **test-basic.sh** - Quick smoke test
2. **test-final.sh** - Standard workflow with error handling
3. **test-additional.sh** - Advanced features and edge cases
4. **test-missing-coverage.sh** - Spec compliance verification

## Test Coverage

The complete test suite covers:

- ✅ All main commands (init, new, list, start, close, restore)
- ✅ Error conditions and validation
- ✅ Edge cases (long names, special characters, etc.)
- ✅ Cross-platform compatibility
- ✅ Configuration options
- ✅ Complex workflows (multiple tickets, branch management)

## Future Improvements

Proposed test structure for future refactoring:

```
test/
├── unit/          # Command-specific tests
├── integration/   # Workflow tests
├── edge-cases/    # Edge case tests
└── compat/        # Platform compatibility tests
```

This would reduce redundancy and improve maintainability while preserving comprehensive coverage.