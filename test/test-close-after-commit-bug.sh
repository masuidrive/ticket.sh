#!/usr/bin/env bash

# Test case for critical bug: close fails after commit during ticket workflow
# Bug description: When close fails due to uncommitted changes, user commits,
# then tries close again - it fails with "No current ticket" error

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Close After Commit Bug Fix Test ==="
echo

# Source helper functions
source "${SCRIPT_DIR}/test-helpers.sh"

# Setup
TEST_DIR="tmp/test-close-after-commit-bug-$(date +%s)"
mkdir -p tmp
rm -rf "$TEST_DIR"
setup_test_repo "$TEST_DIR"

echo "1. Testing close-after-commit bug fix..."

# Create and start a ticket
./ticket.sh new test-bug >/dev/null
TICKET=$(ls tickets/*.md | head -1)
TICKET_NAME=$(basename "$TICKET" .md)

# Start the ticket
./ticket.sh start "$TICKET_NAME" >/dev/null

# Verify we're on feature branch and have current ticket
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "feature/${TICKET_NAME}" ]]; then
    echo "   ✗ Expected branch feature/${TICKET_NAME}, got $CURRENT_BRANCH"
    exit 1
fi

if [[ ! -L "current-ticket.md" ]]; then
    echo "   ✗ current-ticket.md symlink not found"
    exit 1
fi

# Make some changes without committing
echo "test content" > test-file.txt
git add test-file.txt
# Don't commit yet - this simulates the bug scenario

# Try to close with uncommitted changes - should fail
if ./ticket.sh close >/dev/null 2>&1; then
    echo "   ✗ Expected close to fail with uncommitted changes"
    exit 1
fi

# Current ticket should still exist after failed close
if [[ ! -L "current-ticket.md" ]]; then
    echo "   ✗ current-ticket.md was removed after failed close"
    exit 1
fi

CURRENT_BRANCH_AFTER_FAIL=$(git branch --show-current)
if [[ "$CURRENT_BRANCH_AFTER_FAIL" != "feature/${TICKET_NAME}" ]]; then
    echo "   ✗ Branch changed after failed close"
    exit 1
fi

# Commit the changes as instructed by error message
git commit -m "test commit" >/dev/null

# Try to close again - this should succeed now (bug was here)
if ! ./ticket.sh close >/dev/null 2>&1; then
    echo "   ✗ Close failed after commit - bug reproduced!"
    exit 1
fi

# Verify ticket was properly closed
FINAL_BRANCH=$(git branch --show-current)
if [[ "$FINAL_BRANCH" != "main" ]]; then
    echo "   ✗ Expected to be on main branch, got $FINAL_BRANCH"
    exit 1
fi

if [[ -L "current-ticket.md" ]]; then
    echo "   ✗ current-ticket.md still exists after close"
    exit 1
fi

if [[ ! -f "tickets/done/${TICKET_NAME}.md" ]]; then
    echo "   ✗ Ticket not found in done folder"
    exit 1
fi

echo "   ✓ Close after commit bug fix works correctly"

# Cleanup
cleanup_test_repo "$TEST_DIR"

echo "   ✓ All tests passed!"
echo