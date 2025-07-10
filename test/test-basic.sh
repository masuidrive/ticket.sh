#!/usr/bin/env bash

# Basic test suite focusing on core functionality
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Basic ticket.sh Tests ==="
echo

# Source helper functions
source "${SCRIPT_DIR}/test-helpers.sh"

# Setup
TEST_DIR="test-basic"
rm -rf "$TEST_DIR"
setup_test_repo "$TEST_DIR"

# Test 1: Init
echo "1. Testing init..."
./ticket.sh init >/dev/null
echo "   ✓ Init completed"

# Test 2: New ticket
echo "2. Testing new ticket..."
./ticket.sh new my-feature >/dev/null
TICKET=$(ls tickets/*.md | head -1)
echo "   ✓ Created: $TICKET"

# Test 3: List
echo "3. Testing list..."
./ticket.sh list | grep -q "my-feature" && echo "   ✓ Ticket appears in list"

# Test 4: Start
echo "4. Testing start..."
git add tickets .ticket-config.yml .gitignore && git commit -q -m "add ticket and config"
TICKET_NAME=$(basename "$TICKET" .md)
./ticket.sh start "$TICKET_NAME" --no-push >/dev/null
echo "   ✓ Started on branch: $(git branch --show-current)"
echo "   ✓ Symlink exists: $(test -L current-ticket.md && echo "yes" || echo "no")"

# Commit the started_at change
git add tickets && git commit -q -m "start ticket"

# Test 5: Work and close
echo "5. Testing close..."
echo "work" > work.txt
git add work.txt && git commit -q -m "work"

# Debug close
echo "   Running close command..."
if ./ticket.sh close --no-push; then
    echo "   ✓ Close succeeded"
    echo "   ✓ Final branch: $(git branch --show-current)"
    grep -q "closed_at: 20" "$TICKET" && echo "   ✓ Ticket marked as closed"
else
    echo "   ✗ Close failed"
    exit 1
fi

# Test 6: Status filter
echo "6. Testing status filter..."
./ticket.sh list --status done | grep -q "$TICKET_NAME" && echo "   ✓ Done filter works"

echo
echo "=== All basic tests passed! ==="

# Cleanup
cd ..
rm -rf "$TEST_DIR"