#!/usr/bin/env bash

# Run all tests for ticket.sh and yaml-sh
# Usage: ./run-all.sh
# 
# Note: This script must be run with bash, not sh
# Use: bash test/run-all.sh
#
# IMPORTANT: macOS bash 3.2.57 compatibility issues
# =================================================
# macOS ships with an old bash version (3.2.57) that has issues with stdin handling.
# This can cause scripts to hang when bash enters interactive mode unexpectedly.
# 
# Known issues and solutions:
# 1. Process substitution with stdin (< <()) can cause hanging
#    Solution: Use temporary files instead of process substitution
# 
# 2. Commands that might spawn interactive shells (like ticket.sh init) need stdin redirection
#    Solution: Always redirect stdin from /dev/null for such commands
#    Example: ./ticket.sh init </dev/null >/dev/null 2>&1
# 
# 3. Git commands may also trigger interactive prompts
#    Solution: Configure git to avoid interactive mode or redirect stdin
# 
# If tests hang on macOS, check for:
# - Missing stdin redirection on init commands
# - Process substitution patterns in the code
# - Any command that might expect terminal input

# Check if running with bash (POSIX compatible check)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script requires bash. Please run with 'bash test/run-all.sh'"
    exit 1
fi

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Track overall results
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

echo -e "${YELLOW}=== Running All Tests ===${NC}"
echo

# Function to run a test and capture results
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${BLUE}Running $test_name...${NC}"
    echo "  [$(date '+%H:%M:%S')] Starting test: $test_name"
    
    # Run test and capture output
    output=$(eval "$test_command" 2>&1) || true
    
    # Show the output
    echo "$output"
    
    # Extract passed/failed counts from output - simplified approach
    # Count check/cross marks directly
    passed=$(echo "$output" | grep -c "✓" || true)
    failed=$(echo "$output" | grep -c "✗" || true)
    
    # Also try to get from summary line if available - use the LAST summary line to avoid duplicates
    if echo "$output" | grep -q "Summary - Passed:"; then
        summary_passed=$(echo "$output" | grep "Summary - Passed:" | tail -1 | sed -n 's/.*Passed: *\([0-9]*\).*/\1/p')
        summary_failed=$(echo "$output" | grep "Summary - Passed:" | tail -1 | sed -n 's/.*Failed: *\([0-9]*\).*/\1/p')
        
        # Use summary numbers if they're valid and greater than symbol count
        if [[ -n "$summary_passed" ]] && [[ "$summary_passed" =~ ^[0-9]+$ ]] && [[ "$summary_passed" -gt "$passed" ]]; then
            passed="$summary_passed"
        fi
        if [[ -n "$summary_failed" ]] && [[ "$summary_failed" =~ ^[0-9]+$ ]] && [[ "$summary_failed" -gt "$failed" ]]; then
            failed="$summary_failed"
        fi
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + passed + failed))
    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    
    echo "  [$(date '+%H:%M:%S')] Completed test: $test_name"
    echo -e "  Summary - Passed: ${GREEN}$passed${NC}, Failed: ${RED}$failed${NC}"
    echo
}

# Build ticket.sh first
echo -e "${BLUE}Building ticket.sh...${NC}"
if (cd "$ROOT_DIR" && bash ./build.sh > /dev/null 2>&1); then
    echo -e "  ${GREEN}Build successful${NC}"
else
    echo -e "  ${RED}Build failed${NC}"
    exit 1
fi
echo

# Run ticket.sh tests
echo -e "${YELLOW}=== ticket.sh Tests ===${NC}"
echo

# Define test order for better performance (fast tests first)
FAST_TESTS=(
    "test-check-simple.sh"
    "test-prompt.sh"
    "test-simple.sh"
    "test-basic.sh"
)

SLOW_TESTS=(
    "test-additional.sh"
    "test-check.sh"
    "test-comprehensive.sh"
    "test-final.sh"
)

# Run fast tests first
echo "Running fast tests..."
for test_name in "${FAST_TESTS[@]}"; do
    test_file="$SCRIPT_DIR/$test_name"
    if [[ -f "$test_file" ]]; then
        run_test "$(basename "${test_file%.sh}")" "bash $test_file"
    fi
done

# Run remaining tests
echo "Running remaining tests..."
for test_file in "$SCRIPT_DIR"/test-*.sh; do
    test_name=$(basename "$test_file")
    
    # Skip run-all scripts and already processed tests
    if [[ "$test_name" == "run-all.sh" ]] || [[ "$test_name" == "run-all-on-docker.sh" ]] || [[ "$test_name" == "run-all-tests.sh" ]]; then
        continue
    fi
    
    # Skip if already processed in fast tests
    skip=false
    for fast_test in "${FAST_TESTS[@]}"; do
        if [[ "$test_name" == "$fast_test" ]]; then
            skip=true
            break
        fi
    done
    
    if [[ "$skip" == false ]] && [[ -f "$test_file" ]]; then
        run_test "$(basename "${test_file%.sh}")" "bash $test_file"
    fi
done

# Run yaml-sh tests
echo -e "${YELLOW}=== yaml-sh Tests ===${NC}"
echo

if [[ -f "$ROOT_DIR/yaml-sh/test.sh" ]]; then
    run_test "yaml-sh parser" "cd $ROOT_DIR/yaml-sh && bash ./test.sh"
fi

# Summary
echo -e "${YELLOW}=== Overall Test Summary ===${NC}"
echo -e "Total tests run: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$TOTAL_PASSED${NC}"
echo -e "Failed: ${RED}$TOTAL_FAILED${NC}"

if [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    echo "Exit code: 0"
    exit 0
else
    echo -e "\n${RED}Some tests failed.${NC}"
    echo "Exit code: 1"
    exit 1
fi