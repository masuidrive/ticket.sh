#!/usr/bin/env bash

# Test suite for check command
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Check Command Tests ==="
echo

# Source helper functions
source "${SCRIPT_DIR}/test-helpers.sh"

# Setup
TEST_DIR="test-check"
rm -rf "$TEST_DIR"
setup_test_repo "$TEST_DIR"

# Test 1: Check without config
echo "1. Testing check without config..."
rm -f .ticket-config.yml
OUTPUT=$(./ticket.sh check 2>&1 || true)
if echo "$OUTPUT" | grep -q "No ticket configuration found"; then
    echo "   ✓ Correctly shows no config message"
else
    echo "   ✗ Failed: Expected config not found message"
    exit 1
fi

# Test 2: Check on default branch without ticket
echo "2. Testing check on default branch without ticket..."
./ticket.sh init >/dev/null
rm -f current-ticket.md
OUTPUT=$(./ticket.sh check 2>&1)
if echo "$OUTPUT" | grep -q "You are on the default branch with no active ticket"; then
    echo "   ✓ Correctly shows default branch status"
else
    echo "   ✗ Failed: Expected default branch message"
    exit 1
fi

# Test 3: Check on feature branch without ticket
echo "3. Testing check on feature branch without ticket..."
./ticket.sh new test-check >/dev/null
TICKET=$(ls tickets/*-test-check.md | head -1)
TICKET_NAME=$(basename "$TICKET" .md)
git add . && git commit -q -m "add ticket"
./ticket.sh start "$TICKET_NAME" --no-push >/dev/null
rm -f current-ticket.md
OUTPUT=$(./ticket.sh check 2>&1)
if echo "$OUTPUT" | grep -q "You are on a feature branch without an active ticket"; then
    echo "   ✓ Correctly shows feature branch without ticket"
else
    echo "   ✗ Failed: Expected feature branch message"
    exit 1
fi

# Test 4: Check with active ticket and matching branch
echo "4. Testing check with matching ticket and branch..."
./ticket.sh restore >/dev/null
OUTPUT=$(./ticket.sh check 2>&1)
if echo "$OUTPUT" | grep -q "Active ticket found and branch matches"; then
    echo "   ✓ Correctly shows matching ticket and branch"
else
    echo "   ✗ Failed: Expected matching message"
    exit 1
fi

# Test 5: Check with ticket and branch mismatch
echo "5. Testing check with ticket branch mismatch..."
git checkout -b feature/other-branch >/dev/null 2>&1
OUTPUT=$(./ticket.sh check 2>&1)
if echo "$OUTPUT" | grep -q "Ticket and branch mismatch detected"; then
    echo "   ✓ Correctly detects mismatch"
else
    echo "   ✗ Failed: Expected mismatch message"
    exit 1
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo
echo "All check command tests passed!"