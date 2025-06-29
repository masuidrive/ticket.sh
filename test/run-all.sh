#!/usr/bin/env bash

# Run all tests for ticket.sh and yaml-sh
# Usage: ./run-all.sh

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
    
    # Run test and capture output
    output=$(eval "$test_command" 2>&1) || true
    
    # Show the output
    echo "$output"
    
    # Extract passed/failed counts from output
    # First try to get from summary line
    if echo "$output" | grep -q "Passed:"; then
        # Look for the colored number after "Passed:"
        passed=$(echo "$output" | grep "Passed:" | sed -E 's/.*Passed:.*\[0;32m([0-9]+)\[0m.*/\1/' | tail -1)
        failed=$(echo "$output" | grep "Failed:" | sed -E 's/.*Failed:.*\[0;31m([0-9]+)\[0m.*/\1/' | tail -1)
        # If extraction failed, default to counting symbols
        if [[ -z "$passed" ]] || [[ ! "$passed" =~ ^[0-9]+$ ]]; then
            passed=$(echo "$output" | grep -c "✓" || true)
        fi
        if [[ -z "$failed" ]] || [[ ! "$failed" =~ ^[0-9]+$ ]]; then
            failed=$(echo "$output" | grep -c "✗" || true)
        fi
    else
        # For tests that don't have summary, count check/cross marks
        passed=$(echo "$output" | grep -c "✓" || true)
        failed=$(echo "$output" | grep -c "✗" || true)
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + passed + failed))
    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    
    echo
    echo -e "  Summary - Passed: ${GREEN}$passed${NC}, Failed: ${RED}$failed${NC}"
    echo
}

# Build ticket.sh first
echo -e "${BLUE}Building ticket.sh...${NC}"
if (cd "$ROOT_DIR" && ./build.sh > /dev/null 2>&1); then
    echo -e "  ${GREEN}Build successful${NC}"
else
    echo -e "  ${RED}Build failed${NC}"
    exit 1
fi
echo

# Run ticket.sh tests
echo -e "${YELLOW}=== ticket.sh Tests ===${NC}"
echo

# Run each test file in test directory
for test_file in "$SCRIPT_DIR"/test-*.sh; do
    # Skip run-all scripts
    if [[ "$(basename "$test_file")" == "run-all.sh" ]] || [[ "$(basename "$test_file")" == "run-all-on-docker.sh" ]] || [[ "$(basename "$test_file")" == "run-all-tests.sh" ]]; then
        continue
    fi
    
    if [[ -f "$test_file" ]]; then
        run_test "$(basename "${test_file%.sh}")" "$test_file"
    fi
done

# Run yaml-sh tests
echo -e "${YELLOW}=== yaml-sh Tests ===${NC}"
echo

if [[ -f "$ROOT_DIR/yaml-sh/test.sh" ]]; then
    run_test "yaml-sh parser" "cd $ROOT_DIR/yaml-sh && ./test.sh"
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