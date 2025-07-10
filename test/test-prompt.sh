#!/bin/bash

# Test for prompt command functionality

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test helpers
source "$SCRIPT_DIR/test-helpers.sh"

# Test counter
TEST_COUNT=0
PASS_COUNT=0

echo "=== Prompt Command Tests ==="
echo

# Test 1: Check that prompt command returns correct first line
echo "1. Testing prompt command first line..."
cd "$PROJECT_ROOT"

# Run prompt command and check first line
FIRST_LINE=$(bash ./ticket.sh prompt | head -1)
EXPECTED="# Ticket Management Instructions"

if [[ "$FIRST_LINE" == "$EXPECTED" ]]; then
    echo "  ✓ Prompt command returns correct first line"
    ((PASS_COUNT++))
else
    echo "  ✗ Expected: '$EXPECTED'"
    echo "  ✗ Got: '$FIRST_LINE'"
fi
((TEST_COUNT++))

echo
echo "=== Prompt command tests completed ==="
echo

# Display summary
echo "  Summary - Passed: $(printf '\033[0;32m%d\033[0m' $PASS_COUNT), Failed: $(printf '\033[0;31m%d\033[0m' $((TEST_COUNT - PASS_COUNT)))"

# Exit with appropriate code
if [[ $PASS_COUNT -eq $TEST_COUNT ]]; then
    exit 0
else
    exit 1
fi