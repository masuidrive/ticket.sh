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
TEST_DIR="test-close-force-$(date +%s)"

echo -e "${YELLOW}=== Testing close --force option ===${NC}"
echo

# Setup
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
git add tickets .ticket-config.yml && git commit -q -m "add ticket"
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
    # Check if we're on develop branch
    BRANCH=$(git branch --show-current)
    if [[ "$BRANCH" == "develop" ]]; then
        test_result 0 "Successfully closed with --force"
    else
        test_result 1 "Close succeeded but not on develop branch"
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
git add tickets .ticket-config.yml && git commit -q -m "add ticket"
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
git add tickets .ticket-config.yml && git commit -q -m "add ticket"
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

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== close --force tests completed ===${NC}"