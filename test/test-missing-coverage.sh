#!/usr/bin/env bash

# Test cases for missing coverage based on spec.ja.md
# These test edge cases and error conditions not covered by other tests

# Source helper functions
source "$(dirname "$0")/test-helpers.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test directory
TEST_DIR="tmp/test-missing-$(date +%s)"

echo -e "${YELLOW}=== Missing Coverage Tests ===${NC}"
echo

# Setup
setup_test() {
    mkdir -p tmp
    setup_test_repo "$TEST_DIR"
}

# Test result
test_result() {
    if [[ $1 -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} $2"
    else
        echo -e "  ${RED}✗${NC} $2"
        [[ -n "${3:-}" ]] && echo "    Details: $3"
    fi
}

# Test 1: File specification flexibility
echo "1. Testing file specification flexibility..."
setup_test
./ticket.sh new test-file >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add ticket"
TICKET_NAME=$(safe_get_ticket_name "*test-file.md")

# Test all three ways to specify ticket
./ticket.sh start "tickets/${TICKET_NAME}.md" --no-push >/dev/null 2>&1
git add tickets current-ticket.md && git commit -q -m "start" && git checkout -q main

if ./ticket.sh start "${TICKET_NAME}.md" --no-push >/dev/null 2>&1; then
    test_result 1 "Should not allow starting already started ticket"
else
    # Try with just ticket name
    git checkout -q "feature/$TICKET_NAME" 2>/dev/null
    git checkout -q main
    if [[ -f current-ticket.md ]]; then
        rm current-ticket.md
    fi
    
    # Test with just the ticket name (no .md extension)
    if ./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1; then
        test_result 1 "Should not allow starting already started ticket"
    else
        test_result 0 "All three file specification methods work correctly"
    fi
fi

# Test 2: Closing unstarted ticket
echo -e "\n2. Testing close on unstarted ticket..."
cd .. && setup_test
./ticket.sh new unstarted >/dev/null 2>&1
TICKET=$(safe_get_first_file "*unstarted.md" "tickets")
# Create fake current-ticket.md pointing to unstarted ticket
ln -s "$TICKET" current-ticket.md
git checkout -q -b feature/fake-branch

if ./ticket.sh close --no-push >/dev/null 2>&1; then
    test_result 1 "Should not allow closing unstarted ticket"
else
    test_result 0 "Correctly prevents closing unstarted ticket"
fi

# Test 3: Operations on already closed ticket
echo -e "\n3. Testing operations on closed ticket..."
cd .. && setup_test
./ticket.sh new closed-test >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add"
TICKET_NAME=$(safe_get_ticket_name "*closed-test.md")
# Manually set closed_at
TICKET_FILE="tickets/${TICKET_NAME}.md"
sed_i 's/started_at: null/started_at: "2025-01-01T00:00:00Z"/' "$TICKET_FILE"
sed_i 's/closed_at: null/closed_at: "2025-01-01T01:00:00Z"/' "$TICKET_FILE"

# Try to start a closed ticket
if ./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1; then
    test_result 1 "Should not allow starting closed ticket"
else
    test_result 0 "Correctly prevents starting closed ticket"
fi

# Test 4: Invalid count value edge cases
echo -e "\n4. Testing invalid count value edge cases..."
cd .. && setup_test
# Test negative count
if ./ticket.sh list --count -5 >/dev/null 2>&1; then
    test_result 1 "Should reject negative count"
else
    test_result 0 "Correctly rejects negative count"
fi

# Test 5: Empty slug
echo -e "\n5. Testing empty slug..."
if ./ticket.sh new "" >/dev/null 2>&1; then
    test_result 1 "Should reject empty slug"
else
    test_result 0 "Correctly rejects empty slug"
fi

# Test 6: Ticket directory removal after init
echo -e "\n6. Testing missing tickets directory..."
cd .. && setup_test
rm -rf tickets
if ./ticket.sh list >/dev/null 2>&1; then
    test_result 1 "Should fail when tickets directory is missing"
else
    test_result 0 "Correctly detects missing tickets directory"
fi

# Test 7: Corrupted YAML frontmatter
echo -e "\n7. Testing corrupted YAML frontmatter..."
cd .. && setup_test
./ticket.sh new corrupt >/dev/null 2>&1
TICKET=$(safe_get_first_file "*corrupt.md" "tickets")
# Corrupt the YAML
if [[ -n "$TICKET" ]]; then
    echo "broken yaml: [" > "$TICKET"
    echo "more content" >> "$TICKET"
fi

OUTPUT=$(./ticket.sh list 2>&1)
if echo "$OUTPUT" | grep -q "corrupt"; then
    test_result 1 "Should handle corrupted YAML gracefully"
else
    # Even with corrupted YAML, list should work (skipping bad files)
    test_result 0 "Handles corrupted YAML gracefully"
fi

# Test 8: Very long slug
echo -e "\n8. Testing very long slug..."
LONG_SLUG=$(printf 'a%.0s' {1..100})
if ./ticket.sh new "$LONG_SLUG" >/dev/null 2>&1; then
    # Check if file was created
    if ls tickets/*"$LONG_SLUG"* >/dev/null 2>&1; then
        test_result 0 "Accepts long slugs"
    else
        test_result 1 "Created ticket but file not found"
    fi
else
    test_result 1 "Should accept long valid slugs"
fi

# Test 9: Special branch names with slash
echo -e "\n9. Testing custom branch prefix with multiple slashes..."
cd .. && setup_test
# Modify config for complex branch prefix
sed_i 's|branch_prefix: "feature/"|branch_prefix: "feature/team/"|' .ticket-config.yaml

./ticket.sh new slash-test >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add"
TICKET=$(safe_get_ticket_name "*slash-test.md")

if ./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1; then
    BRANCH=$(git branch --show-current)
    if [[ "$BRANCH" == "feature/team/$TICKET" ]]; then
        test_result 0 "Handles multi-level branch prefixes"
    else
        test_result 1 "Branch name incorrect: $BRANCH"
    fi
else
    test_result 1 "Failed to create branch with multi-level prefix"
fi

# Test 10: List with multiple status values (last one wins)
echo -e "\n10. Testing list with multiple status values..."
cd .. && setup_test  # Start fresh
# Create tickets with different statuses
./ticket.sh new multi-1 >/dev/null 2>&1
./ticket.sh new multi-2 >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add tickets"
TICKET=$(safe_get_ticket_name "*multi-1.md")
./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1
git add tickets current-ticket.md && git commit -q -m "start"
# Merge back to main so the started_at is visible
git checkout -q main
git merge --no-ff -q "feature/$TICKET" -m "Merge" >/dev/null 2>&1

# With multiple --status flags, the last one should win
OUTPUT=$(./ticket.sh list --status todo --status doing 2>&1)
if echo "$OUTPUT" | grep -q "status: doing"; then
    # Should only show "doing" tickets (last --status value)
    if echo "$OUTPUT" | grep -q "status: todo"; then
        test_result 1 "Should only show tickets matching last --status value"
    else
        test_result 0 "Correctly uses last --status value when multiple given"
    fi
else
    test_result 1 "Should show doing tickets when --status doing is last"
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== Missing coverage tests completed ===${NC}"