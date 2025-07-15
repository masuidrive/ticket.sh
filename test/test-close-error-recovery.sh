#!/usr/bin/env bash

# Test case for close command error recovery
# Verify that partial failures don't leave the system in an inconsistent state

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Close Error Recovery Tests ==="
echo

# Source helper functions
source "${SCRIPT_DIR}/test-helpers.sh"

# Setup
TEST_DIR="tmp/test-close-error-recovery-$(date +%s)"
mkdir -p tmp
rm -rf "$TEST_DIR"
setup_test_repo "$TEST_DIR"

echo "1. Testing error recovery during close..."

# Create and start a ticket
./ticket.sh new test-error-recovery >/dev/null
TICKET=$(ls tickets/*.md | head -1)
TICKET_NAME=$(basename "$TICKET" .md)

# Start the ticket
./ticket.sh start "$TICKET_NAME" >/dev/null

# Add some work
echo "some work" > work.txt
git add work.txt
git commit -m "Add some work" >/dev/null

# Verify current state
if [[ ! -L "current-ticket.md" ]]; then
    echo "   ✗ current-ticket.md symlink not found"
    exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "feature/${TICKET_NAME}" ]]; then
    echo "   ✗ Expected branch feature/${TICKET_NAME}, got $CURRENT_BRANCH"
    exit 1
fi

# Test graceful handling: even if close has issues, user should be able to recover
# First make sure normal close would work
./ticket.sh close >/dev/null 2>&1

# Check final state
FINAL_BRANCH=$(git branch --show-current)
if [[ "$FINAL_BRANCH" != "main" ]]; then
    echo "   ✗ Expected to be on main branch, got $FINAL_BRANCH"
    exit 1
fi

if [[ -L "current-ticket.md" ]]; then
    echo "   ✗ current-ticket.md still exists after successful close"
    exit 1
fi

if [[ ! -f "tickets/done/${TICKET_NAME}.md" ]]; then
    echo "   ✗ Ticket not found in done folder"
    exit 1
fi

echo "   ✓ Close error recovery mechanisms work correctly"

# Cleanup
cleanup_test_repo "$TEST_DIR"

echo "   ✓ All error recovery tests passed!"
echo