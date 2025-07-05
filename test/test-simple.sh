#!/usr/bin/env bash

# Simple test script for ticket.sh
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== ticket.sh Test Suite ==="
echo

# Create test directory
TEST_DIR="test-simple-$(date +%s)"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Always rebuild to ensure latest version
(cd "${SCRIPT_DIR}/.." && ./build.sh >/dev/null 2>&1)
cp "${SCRIPT_DIR}/../ticket.sh" .
chmod +x ticket.sh

echo "1. Testing without git repo..."
if ! ./ticket.sh init 2>&1 | grep -q "Error: Not in a git repository"; then
    echo "  FAIL: Should fail without git repo"
    exit 1
fi
echo "  PASS: Correctly fails without git repo"

echo
echo "2. Setting up git repo..."
git init -q
git config user.name "Test"
git config user.email "test@test.com"
echo "# Test" > README.md
git add README.md
git commit -q -m "Initial"
git checkout -q -b develop
echo "  PASS: Git repo initialized"

echo
echo "3. Testing init command..."
./ticket.sh init >/dev/null 2>&1
if [[ ! -f .ticket-config.yml ]]; then
    echo "  FAIL: Config file not created"
    exit 1
fi
if [[ ! -d tickets ]]; then
    echo "  FAIL: Tickets directory not created"
    exit 1
fi
echo "  PASS: Init successful"

echo
echo "4. Testing new command..."
./ticket.sh new test-feature >/dev/null 2>&1
TICKET=$(ls tickets/*.md 2>/dev/null | head -1)
if [[ -z "$TICKET" ]]; then
    echo "  FAIL: Ticket not created"
    exit 1
fi
echo "  PASS: Ticket created: $TICKET"

echo
echo "5. Testing list command..."
# Capture output with error handling
if OUTPUT=$(./ticket.sh list 2>&1); then
    if echo "$OUTPUT" | grep -q "test-feature"; then
        echo "  PASS: Ticket appears in list"
    else
        echo "  FAIL: Ticket not in list"
        echo "  Output: $OUTPUT"
        exit 1
    fi
else
    echo "  FAIL: List command failed with exit code $?"
    exit 1
fi

echo
echo "6. Testing start command..."
git add . && git commit -q -m "Add ticket"
TICKET_NAME=$(basename "$TICKET" .md)
./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "feature/$TICKET_NAME" ]]; then
    echo "  FAIL: Not on feature branch (on: $BRANCH)"
    exit 1
fi
if [[ ! -L current-ticket.md ]]; then
    echo "  FAIL: current-ticket.md not created"
    exit 1
fi
echo "  PASS: Started ticket on branch $BRANCH"

echo
echo "7. Testing restore command..."
rm -f current-ticket.md
./ticket.sh restore >/dev/null 2>&1
if [[ ! -L current-ticket.md ]]; then
    echo "  FAIL: current-ticket.md not restored"
    exit 1
fi
echo "  PASS: Restored current-ticket.md"

echo
echo "8. Testing close command..."
echo "test" > test.txt
git add . && git commit -q -m "Work"
./ticket.sh close --no-push >/dev/null 2>&1
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "develop" ]]; then
    echo "  FAIL: Not back on develop branch"
    exit 1
fi
if grep -q "closed_at: null" "$TICKET"; then
    echo "  FAIL: Ticket not marked as closed"
    exit 1
fi
echo "  PASS: Ticket closed and merged"

echo
echo "9. Testing error handling..."
if ./ticket.sh new "Bad Name" >/dev/null 2>&1; then
    echo "  FAIL: Should reject invalid slug"
    exit 1
fi
echo "  PASS: Correctly rejects invalid slug"

echo
echo "=== All tests passed! ==="

# Cleanup
cd ..
rm -rf "$TEST_DIR"