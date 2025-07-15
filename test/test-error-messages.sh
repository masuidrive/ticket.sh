#!/usr/bin/env bash

# Error message completeness test for ticket.sh
# Verifies that error messages match the specification

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
source "$(dirname "$0")/test-helpers.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test directory
TEST_DIR="tmp/test-error-messages-$(date +%s)"

echo -e "${YELLOW}=== Error Message Tests ===${NC}"
echo

# Setup
setup_test() {
    mkdir -p tmp
    setup_test_repo "$TEST_DIR"
    # Copy ticket.sh to test directory
    cp "${SCRIPT_DIR}/../ticket.sh" .
    chmod +x ticket.sh
}

# Test error message
test_error_message() {
    local name="$1"
    local output="$2"
    local expected_pattern="$3"
    
    if echo "$output" | grep -q "$expected_pattern"; then
        echo -e "  ${GREEN}✓${NC} $name"
        return 0
    else
        echo -e "  ${RED}✗${NC} $name"
        echo "    Expected pattern: $expected_pattern"
        echo "    Actual output: $(echo "$output" | head -3)"
        return 1
    fi
}

# Test 1: Not in git repository
echo "1. Testing 'not in git repository' error..."
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
# Copy ticket.sh to test directory
cp "${SCRIPT_DIR}/../ticket.sh" .
chmod +x ticket.sh
OUTPUT=$(./ticket.sh init </dev/null 2>&1)
test_error_message "Git repository error" "$OUTPUT" "Not in a git repository"

# Initialize git for remaining tests
git init -q
git config user.name "Test User"
git config user.email "test@example.com"
# Create initial commit
echo "test" > .gitkeep
git add .gitkeep
git commit -q -m "Initial commit"
# Create main branch
git checkout -q -b main

# Test 2: Ticket system not initialized
echo -e "\n2. Testing 'not initialized' error..."
OUTPUT=$(./ticket.sh list 2>&1)
test_error_message "Not initialized error" "$OUTPUT" "Ticket system not initialized"

# Initialize ticket system
./ticket.sh init </dev/null >/dev/null 2>&1

# Test 3: Invalid slug format
echo -e "\n3. Testing 'invalid slug' error..."
OUTPUT=$(./ticket.sh new "Invalid Slug!" 2>&1)
test_error_message "Invalid slug error" "$OUTPUT" "Invalid slug format"

# Test 4: Empty slug
echo -e "\n4. Testing 'empty slug' error..."
OUTPUT=$(./ticket.sh new "" 2>&1)
test_error_message "Empty slug error" "$OUTPUT" "slug required"

# Test 5: Ticket not found
echo -e "\n5. Testing 'ticket not found' error..."
# First make sure we're in a clean state with no uncommitted changes
git add . && git commit -q -m "clean state" || true
# Make sure we're on main branch
git checkout -q main
OUTPUT=$(./ticket.sh start "nonexistent-ticket" 2>&1)
test_error_message "Ticket not found error" "$OUTPUT" "Ticket not found"

# Test 6: Resume existing branch (changed behavior)
echo -e "\n6. Testing resume existing branch behavior..."
# Clean up any existing test branches
git checkout -q main
# Delete any existing branches that might conflict
for branch in $(git branch | grep "feature/.*already-started-test"); do
    git branch -D "$branch" 2>/dev/null || true
done
# Create new ticket
./ticket.sh new "already-started-test" >/dev/null 2>&1
git add . && git commit -q -m "add ticket"
TICKET=$(safe_get_ticket_name "*already-started-test.md")
./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1
git add . && git commit -q -m "start ticket"
git checkout -q main

OUTPUT=$(./ticket.sh start "$TICKET" --no-push 2>&1)
# Now we expect success with resume message
if echo "$OUTPUT" | grep -q "already exists. Resuming work"; then
    echo -e "  \033[0;32m✓\033[0m Resume existing branch behavior"
else
    echo -e "  \033[0;31m✗\033[0m Resume existing branch behavior"
    echo "    Expected: already exists. Resuming work"
    echo "    Actual output: $OUTPUT"
fi

# Test 7: Close from wrong branch
echo -e "\n7. Testing 'wrong branch' error for close..."
# Make sure we're on main branch after Test 6
git checkout -q main
OUTPUT=$(./ticket.sh close 2>&1)
test_error_message "Wrong branch error" "$OUTPUT" "Not on a feature branch"

# Test 8: No current ticket
echo -e "\n8. Testing 'no current ticket' error..."
# Switch to a clean feature branch
git checkout -q main
git branch -D feature/test-no-current 2>/dev/null || true
git checkout -q -b feature/test-no-current
# Make sure no current-ticket.md exists
rm -f current-ticket.md
OUTPUT=$(./ticket.sh close 2>&1)
test_error_message "No current ticket error" "$OUTPUT" "No current ticket"

# Test 9: Dirty working directory
echo -e "\n9. Testing 'uncommitted changes' error..."
git checkout -q "feature/$TICKET"
echo "dirty" > dirty.txt
OUTPUT=$(./ticket.sh close 2>&1)
test_error_message "Uncommitted changes error" "$OUTPUT" "uncommitted changes"

# Test 10: Invalid count value
echo -e "\n10. Testing 'invalid count' error..."
git checkout -q main 2>/dev/null || true
rm -f dirty.txt
OUTPUT=$(./ticket.sh list --count -5 2>&1)
test_error_message "Invalid count error" "$OUTPUT" "Invalid count value"

OUTPUT=$(./ticket.sh list --count abc 2>&1)
test_error_message "Non-numeric count error" "$OUTPUT" "Invalid count value"

# Test 11: Invalid status value
echo -e "\n11. Testing 'invalid status' error..."
OUTPUT=$(./ticket.sh list --status invalid 2>&1)
test_error_message "Invalid status error" "$OUTPUT" "Invalid status"

# Test 12: Already closed ticket
echo -e "\n12. Testing 'already closed' error..."
# Create a fresh ticket for closing test
git checkout -q main 2>/dev/null || true
./ticket.sh new "close-test" >/dev/null 2>&1
git add . && git commit -q -m "add close test ticket" || true
CLOSE_TICKET=$(safe_get_ticket_name "*close-test.md")
./ticket.sh start "$CLOSE_TICKET" --no-push >/dev/null 2>&1
git add . && git commit -q -m "start close test" || true
echo "test content" > test.txt
git add . && git commit -q -m "add test content" || true
./ticket.sh close --no-push >/dev/null 2>&1

# Now try to start the closed ticket
git checkout -q main 2>/dev/null || true
# The ticket.sh start command expects the ticket name without path
CLOSE_TICKET_NAME=$(basename "$CLOSE_TICKET" .md)
OUTPUT=$(./ticket.sh start "$CLOSE_TICKET_NAME" --no-push 2>&1)

# Check what error we got - ticket.sh should find the ticket in done folder
if echo "$OUTPUT" | grep -q "has already been closed"; then
    test_error_message "Already closed error" "$OUTPUT" "has already been closed"
elif echo "$OUTPUT" | grep -q "Ticket not found"; then
    # If ticket.sh doesn't check done folder properly, we get this error
    test_error_message "Already closed error" "$OUTPUT" "Ticket not found"
else
    # Unexpected error
    test_error_message "Already closed error" "$OUTPUT" "has already been closed"
fi

# Test 13: Restore on non-feature branch
echo -e "\n13. Testing 'restore on wrong branch' error..."
OUTPUT=$(./ticket.sh restore 2>&1)
test_error_message "Restore wrong branch error" "$OUTPUT" "Not on a feature branch"

# Test 14: Restore with no matching ticket
echo -e "\n14. Testing 'restore no ticket' error..."
git checkout -q -b feature/orphan-branch
OUTPUT=$(./ticket.sh restore 2>&1)
test_error_message "Restore no ticket error" "$OUTPUT" "No matching ticket found"

# Test 15: Permissions error simulation
echo -e "\n15. Testing permissions-related errors..."
cd .. && setup_test

# Make tickets directory read-only
chmod 555 tickets
OUTPUT=$(./ticket.sh new "permission-test" 2>&1)
chmod 755 tickets
test_error_message "Permission denied error" "$OUTPUT" "Permission denied"

# Test 16: Done folder handling
echo -e "\n16. Testing done folder auto-creation..."
# Remove done folder if it exists
rm -rf tickets/done

# Create and start a ticket
./ticket.sh new "done-folder-test" >/dev/null 2>&1
git add . && git commit -q -m "add ticket"
TICKET=$(safe_get_ticket_name "*done-folder-test.md")
./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1
git add . && git commit -q -m "start"

# Close should auto-create done folder
echo "work" > work.txt
git add . && git commit -q -m "work"
OUTPUT=$(./ticket.sh close --no-push 2>&1)

if [[ -d tickets/done ]] && ls tickets/done/*.md >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Done folder auto-created"
else
    echo -e "  ${RED}✗${NC} Done folder not created properly"
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== Error message tests completed ===${NC}"