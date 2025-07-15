#!/usr/bin/env bash

# Test for close --force option

# Source helper functions
source "$(dirname "$0")/test-helpers.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test directory
TEST_DIR="tmp/test-close-force-$(date +%s)"

echo -e "${YELLOW}=== Testing close --force option ===${NC}"
echo

# Setup
mkdir -p tmp
setup_test_repo "$TEST_DIR"

# Test result
test_result() {
    if [[ $1 -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} $2"
    else
        echo -e "  ${RED}✗${NC} $2"
        [[ -n "${3:-}" ]] && echo "    Details: $3"
    fi
}

echo "1. Testing close with uncommitted changes (should fail)..."
./ticket.sh new test-force >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add ticket"
TICKET=$(safe_get_ticket_name "*.md")
if [[ -n "$TICKET" ]]; then
    ./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1
    # Commit the started_at change
    git add tickets && git commit -q -m "start ticket"
fi

# Create uncommitted changes
echo "uncommitted content" > dirty.txt

# Try to close without force
if ./ticket.sh close --no-push >/dev/null 2>&1; then
    test_result 1 "Should fail with uncommitted changes"
else
    # Check if the error message mentions --force
    OUTPUT=$(./ticket.sh close --no-push 2>&1)
    if echo "$OUTPUT" | grep -q "close --force"; then
        test_result 0 "Correctly fails and suggests --force option"
    else
        test_result 1 "Error message should mention --force option"
    fi
fi

echo -e "\n2. Testing close --force with uncommitted changes..."
# Now try with --force
if ./ticket.sh close --force --no-push >/dev/null 2>&1; then
    # Check if we're on main branch
    BRANCH=$(git branch --show-current)
    if [[ "$BRANCH" == "main" ]]; then
        test_result 0 "Successfully closed with --force"
    else
        test_result 1 "Close succeeded but not on main branch (found: $BRANCH)"
    fi
else
    test_result 1 "Close --force should succeed with uncommitted changes"
fi

echo -e "\n3. Testing close -f (short form)..."
# Setup again with a fresh test directory
cd ..
rm -rf "$TEST_DIR"
setup_test_repo "$TEST_DIR"

./ticket.sh new test-short >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add ticket"
TICKET=$(safe_get_ticket_name "*.md")
if [[ -n "$TICKET" ]]; then
    ./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1
    # Commit the started_at change
    git add tickets && git commit -q -m "start ticket"
fi

# Create uncommitted changes
echo "more uncommitted" > another-dirty.txt

# Try with -f short form
if ./ticket.sh close -f --no-push >/dev/null 2>&1; then
    test_result 0 "Short form -f works correctly"
else
    test_result 1 "Short form -f should work"
fi

echo -e "\n4. Testing combined options..."
# Setup again with a fresh test directory
cd ..
rm -rf "$TEST_DIR"
setup_test_repo "$TEST_DIR"

./ticket.sh new test-combined >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add ticket"
TICKET=$(safe_get_ticket_name "*.md")
if [[ -n "$TICKET" ]]; then
    ./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1
    # Commit the started_at change
    git add tickets && git commit -q -m "start ticket"
fi

# Create uncommitted changes
echo "combined test" > combined.txt

# Try with both --no-push and --force
if ./ticket.sh close --no-push --force >/dev/null 2>&1; then
    test_result 0 "Combined --no-push --force works"
else
    test_result 1 "Combined options should work"
fi

echo -e "\n5. Testing invalid option handling..."
if ./ticket.sh close --invalid-option 2>&1 | grep -q "Unknown option"; then
    test_result 0 "Correctly rejects invalid options"
else
    test_result 1 "Should reject invalid options"
fi

echo -e "\n6. Testing current-ticket.md removal from git history..."
# Setup again with a fresh test directory
cd ..
rm -rf "$TEST_DIR"
setup_test_repo "$TEST_DIR"

./ticket.sh new test-current-ticket >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add ticket"
TICKET=$(safe_get_ticket_name "*.md")
if [[ -n "$TICKET" ]]; then
    ./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1
    # Commit the started_at change
    git add tickets && git commit -q -m "start ticket"
fi

# Force add current-ticket.md and commit it
git add -f current-ticket.md >/dev/null 2>&1
git commit -q -m "Force add current-ticket.md" >/dev/null 2>&1

# Verify current-ticket.md is in git history
if git ls-files | grep -q "^current-ticket.md$"; then
    # Now close the ticket
    if ./ticket.sh close --no-push >/dev/null 2>&1; then
        # Check if current-ticket.md is removed from git history
        if git ls-files | grep -q "^current-ticket.md$"; then
            test_result 1 "current-ticket.md should be removed from git history"
        else
            # Check if current-ticket.md still exists as a file
            if [[ -f current-ticket.md ]]; then
                test_result 1 "current-ticket.md file should not exist after close"
            else
                test_result 0 "current-ticket.md correctly removed from git history during close"
            fi
        fi
    else
        test_result 1 "Close should succeed after removing current-ticket.md"
    fi
else
    test_result 1 "Setup failed: current-ticket.md not found in git history"
fi

echo -e "\n7. Testing normal close without current-ticket.md in git..."
# Setup again with a fresh test directory
cd ..
rm -rf "$TEST_DIR"
setup_test_repo "$TEST_DIR"

./ticket.sh new test-normal >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add ticket"
TICKET=$(safe_get_ticket_name "*.md")
if [[ -n "$TICKET" ]]; then
    ./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1
    # Commit the started_at change
    git add tickets && git commit -q -m "start ticket"
fi

# Close without force-adding current-ticket.md
if ./ticket.sh close --no-push >/dev/null 2>&1; then
    test_result 0 "Normal close works when current-ticket.md not in git history"
else
    test_result 1 "Normal close should work when current-ticket.md not in git history"
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== close --force tests completed ===${NC}"