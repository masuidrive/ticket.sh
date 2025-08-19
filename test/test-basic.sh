#!/usr/bin/env bash

# Check if running with bash (POSIX compatible check)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This test requires bash. Please run with 'bash test/test-basic.sh'"
    echo "Current shell: $0"
    exit 1
fi

# Basic test suite focusing on core functionality
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Basic ticket.sh Tests ==="
echo

# Source helper functions
source "${SCRIPT_DIR}/test-helpers.sh"

# Setup
TEST_DIR="tmp/test-basic-$(date +%s)"
echo "Setting up test environment..."
mkdir -p tmp
rm -rf "$TEST_DIR"
setup_test_repo "$TEST_DIR"
echo "Test environment ready."

# Test 1: Init
echo "1. Testing init..."
echo "   Initializing ticket system..."
timeout 5 ./ticket.sh init  >/dev/null
echo "   ✓ Init completed"

# Test 2: New ticket
echo "2. Testing new ticket..."
echo "   Creating new ticket..."
./ticket.sh new my-feature >/dev/null
TICKET=$(ls tickets/*.md | head -1)
echo "   ✓ Created: $TICKET"

# Test 3: List
echo "3. Testing list..."
echo "   Listing tickets..."
./ticket.sh list | grep -q "my-feature" && echo "   ✓ Ticket appears in list"

# Test 4: Start
echo "4. Testing start..."
echo "   Committing initial state..."
git add tickets .ticket-config.yaml .gitignore && git commit -q -m "add ticket and config"
TICKET_NAME=$(basename "$TICKET" .md)
echo "   Starting ticket: $TICKET_NAME"
./ticket.sh start "$TICKET_NAME" --no-push >/dev/null
echo "   ✓ Started on branch: $(git branch --show-current)"
echo "   ✓ Symlink exists: $(test -L current-ticket.md && echo "yes" || echo "no")"

# Commit the started_at change
echo "   Committing started_at change..."
git add tickets && git commit -q -m "start ticket"

# Test 5: Work and close
echo "5. Testing close..."
echo "   Creating work file..."
echo "work" > work.txt
echo "   Committing work..."
git add work.txt && git commit -q -m "work"

# Debug close
echo "   Running close command..."
echo "   Current branch: $(git branch --show-current)"
echo "   Working directory status: $(git status --porcelain | wc -l) changes"
if timeout 5 ./ticket.sh close --no-push; then
    echo "   ✓ Close succeeded"
    echo "   ✓ Final branch: $(git branch --show-current)"
    # Check ticket in done folder after close
    DONE_TICKET="tickets/done/$(basename "$TICKET")"
    [[ -f "$DONE_TICKET" ]] && grep -q "closed_at: 20" "$DONE_TICKET" && echo "   ✓ Ticket marked as closed"
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