#!/usr/bin/env bash

# Run all tests
# This script runs all test-*.sh files in the current directory

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Directory of this script
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}=== Running All Tests ===${NC}"
echo

# Count successes and failures
PASSED=0
FAILED=0
FAILED_TESTS=()

# Find and run all test scripts
for test_script in "$TEST_DIR"/test-*.sh; do
    # Skip this script itself
    if [[ "$(basename "$test_script")" == "test-all.sh" ]]; then
        continue
    fi
    
    # Skip if not a regular file or not executable
    if [[ ! -f "$test_script" ]]; then
        continue
    fi
    
    echo -e "\n${YELLOW}Running $(basename "$test_script")...${NC}"
    
    # Run the test and capture exit code
    if "$test_script"; then
        echo -e "${GREEN}✓ $(basename "$test_script") passed${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ $(basename "$test_script") failed${NC}"
        ((FAILED++))
        FAILED_TESTS+=("$(basename "$test_script")")
    fi
done

# Summary
echo -e "\n${YELLOW}=== Test Summary ===${NC}"
echo -e "Total tests run: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

if [[ $FAILED -gt 0 ]]; then
    echo -e "\n${RED}Failed tests:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    exit 1
else
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
fi