#!/usr/bin/env bash

# Test the check command functionality
# This test verifies all scenarios that the check command handles

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Test helper functions
pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASS_COUNT++))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAIL_COUNT++))
}

run_test() {
    ((TEST_COUNT++))
    echo -e "\n${BLUE}$TEST_COUNT. $1${NC}"
}

# Get the directory where this script is located and find ticket.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TICKET_SH="$SCRIPT_DIR/../ticket.sh"

if [[ ! -f "$TICKET_SH" ]]; then
    echo "Error: ticket.sh not found at $TICKET_SH"
    exit 1
fi

# Create temporary test directory
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# Initialize git and ticket system
git init > /dev/null 2>&1
git config user.email "test@example.com"
git config user.name "Test User"

# Create main branch (some git versions default to master)
current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")
if [[ "$current_branch" != "main" ]]; then
    git checkout -b main > /dev/null 2>&1 || true
fi

git commit --allow-empty -m "Initial commit" > /dev/null 2>&1

"$TICKET_SH" init > /dev/null 2>&1

echo -e "${YELLOW}=== Check Command Tests ===${NC}"

# Test 1: Check on default branch without current ticket
run_test "Testing check on default branch without current ticket"
rm -f current-ticket.md
output=$("$TICKET_SH" check 2>&1)
if [[ "$output" =~ "No active ticket (on default branch)" ]] && [[ "$output" =~ "ticket.sh list" ]]; then
    pass "Shows correct message for default branch"
else
    fail "Incorrect message for default branch: $output"
fi

# Test 2: Create ticket and test feature branch scenarios
run_test "Creating test ticket"
"$TICKET_SH" new test-feature > /dev/null 2>&1
TICKET_NAME=$(ls tickets/ | grep test-feature | head -1 | sed 's/\.md$//')
if [[ -n "$TICKET_NAME" ]]; then
    pass "Created ticket: $TICKET_NAME"
else
    fail "Failed to create ticket"
fi

# Test 3: Start ticket and test synchronized state
run_test "Testing check on synchronized feature branch"
"$TICKET_SH" start "$TICKET_NAME" > /dev/null 2>&1
output=$("$TICKET_SH" check 2>&1)
if [[ "$output" =~ "Current ticket is active and synchronized" ]] && [[ "$output" =~ "Working on: $TICKET_NAME" ]]; then
    pass "Shows synchronized state correctly"
else
    fail "Incorrect synchronized state message: $output"
fi

# Test 4: Test branch/ticket mismatch
run_test "Testing check with branch/ticket mismatch"
git checkout main > /dev/null 2>&1
output=$("$TICKET_SH" check 2>&1 || true)
if [[ "$output" =~ "Ticket file and branch mismatch detected" ]] && [[ "$output" =~ "ticket.sh restore" ]]; then
    pass "Detects branch/ticket mismatch correctly"
else
    fail "Failed to detect mismatch: $output"
fi

# Test 5: Test restore functionality from feature branch
run_test "Testing check restore functionality on feature branch"
git checkout "feature/$TICKET_NAME" > /dev/null 2>&1
rm -f current-ticket.md
output=$("$TICKET_SH" check 2>&1)
if [[ "$output" =~ "Found matching ticket for current branch" ]] && [[ "$output" =~ "Restored ticket link" ]]; then
    pass "Restores ticket link correctly"
else
    fail "Failed to restore ticket link: $output"
fi

# Verify symlink was actually created
if [[ -L current-ticket.md ]]; then
    pass "Symlink created successfully"
else
    fail "Symlink not created"
fi

# Test 6: Test feature branch without corresponding ticket
run_test "Testing check on feature branch without ticket"
git checkout -b feature/nonexistent-ticket > /dev/null 2>&1
rm -f current-ticket.md
output=$("$TICKET_SH" check 2>&1 || true)
if [[ "$output" =~ "No ticket found for current feature branch" ]] && [[ "$output" =~ "ticket.sh new" ]]; then
    pass "Shows correct error for missing ticket"
else
    fail "Incorrect error for missing ticket: $output"
fi

# Test 7: Test unknown branch type
run_test "Testing check on unknown branch"
git checkout -b unknown-branch-type > /dev/null 2>&1
rm -f current-ticket.md
output=$("$TICKET_SH" check 2>&1)
if [[ "$output" =~ "You are on an unknown branch" ]] && [[ "$output" =~ "git checkout main" ]]; then
    pass "Shows correct message for unknown branch"
else
    fail "Incorrect message for unknown branch: $output"
fi

# Test 8: Test check command with completed ticket (in done folder)
run_test "Testing check with completed ticket"
git checkout "feature/$TICKET_NAME" > /dev/null 2>&1
mkdir -p tickets/done
mv "tickets/$TICKET_NAME.md" "tickets/done/$TICKET_NAME.md"
rm -f current-ticket.md
output=$("$TICKET_SH" check 2>&1)
if [[ "$output" =~ "Found matching ticket for current branch" ]] && [[ "$output" =~ "Restored ticket link" ]]; then
    pass "Handles completed tickets in done folder"
else
    fail "Failed to handle done folder ticket: $output"
fi

# Test 9: Test check command error handling (invalid repository)
run_test "Testing check command prerequisites"
# Create a non-git directory for testing
NON_GIT_DIR=$(mktemp -d)
cd "$NON_GIT_DIR"
output=$("$TICKET_SH" check 2>&1 || true)
if [[ "$output" =~ "not a git repository" ]] || [[ "$output" =~ "Not in a git repository" ]]; then
    pass "Correctly detects missing git repository"
else
    fail "Failed to detect missing git repository: $output"
fi
rm -rf "$NON_GIT_DIR"

# Test 10: Test check command with missing config
run_test "Testing check with missing config"
cd "$TEST_DIR"
rm -f .ticket-config.yaml
output=$("$TICKET_SH" check 2>&1 || true)
if [[ "$output" =~ "not initialized" ]] || [[ "$output" =~ "config" ]]; then
    pass "Correctly detects missing config"
else
    fail "Failed to detect missing config: $output"
fi

echo -e "\n${YELLOW}=== Check Command Test Summary ===${NC}"
echo "Total tests: $TEST_COUNT"
echo -e "Passed: ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"

# Cleanup
cd /
rm -rf "$TEST_DIR"

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "\n${GREEN}All check command tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi