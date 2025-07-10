#!/usr/bin/env bash

# Additional test cases for ticket.sh
# Tests edge cases and error conditions not covered by other tests

# Source helper functions
source "$(dirname "$0")/test-helpers.sh"

# Ensure consistent environment for cross-platform compatibility
export LC_ALL=C
export GREP_OPTIONS=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test directory
TEST_DIR="test-additional-$(date +%s)"

echo -e "${YELLOW}=== Additional ticket.sh Tests ===${NC}"
echo

# Setup
setup_test() {
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

# Test 1: Duplicate ticket prevention
echo "1. Testing duplicate ticket prevention..."
setup_test
./ticket.sh new test-duplicate >/dev/null 2>&1

# Check if tickets directory exists
if [[ ! -d tickets ]]; then
    test_result 1 "Tickets directory not created"
else
    # Find first ticket file
    FIRST_TICKET=$(safe_get_first_file "*test-duplicate.md" "tickets")
    
    if [[ -z "$FIRST_TICKET" ]]; then
        test_result 1 "First ticket not created"
    else
        sleep 1  # Ensure different timestamp
        if ./ticket.sh new test-duplicate >/dev/null 2>&1; then
            # Find all matching files
            TICKET_COUNT=0
            for f in tickets/*test-duplicate.md; do
                if [[ -f "$f" ]]; then
                    ((TICKET_COUNT++))
                fi
            done
            
            if [[ $TICKET_COUNT -gt 1 ]]; then
                test_result 0 "Allows same slug with different timestamp"
            else
                test_result 1 "Should create different files for same slug"
            fi
        else
            test_result 1 "Should allow duplicate slug with different timestamp"
        fi
    fi
fi

# Test 2: Start already started ticket
echo -e "\n2. Testing start on already started ticket..."
git add tickets .ticket-config.yaml && git commit -q -m "add tickets"
TICKET_NAME=$(basename "$FIRST_TICKET" .md)
./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1
git add tickets current-ticket.md && git commit -q -m "update"
git checkout -q develop
if ./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1; then
    test_result 1 "Should not allow starting already started ticket"
else
    test_result 0 "Correctly prevents starting already started ticket"
fi

# Test 3: Close from wrong branch
echo -e "\n3. Testing close from wrong branch..."
git checkout -q main 2>/dev/null || git checkout -q -b main
if ./ticket.sh close --no-push >/dev/null 2>&1; then
    test_result 1 "Should not allow close from non-feature branch"
else
    test_result 0 "Correctly prevents close from wrong branch"
fi

# Test 4: Restore with broken symlink
echo -e "\n4. Testing restore with broken symlink..."
git checkout -q "feature/$TICKET_NAME"
rm -f tickets/*.md  # Remove ticket file but keep symlink
if ./ticket.sh restore >/dev/null 2>&1; then
    test_result 1 "Should fail when ticket file is missing"
else
    test_result 0 "Correctly detects missing ticket file"
fi

# Test 5: List with various counts
echo -e "\n5. Testing list count parameter..."
cd .. && setup_test
# Create multiple tickets
for i in {1..5}; do
    ./ticket.sh new "test-$i" >/dev/null 2>&1
    sleep 0.1  # Small delay to ensure different timestamps
done

# Use more explicit grep pattern and ensure clean counting
COUNT_1=$(./ticket.sh list --count 1 2>&1 | grep -E "^[[:space:]]*ticket_path:" | wc -l | tr -d ' ')
COUNT_3=$(./ticket.sh list --count 3 2>&1 | grep -E "^[[:space:]]*ticket_path:" | wc -l | tr -d ' ')
COUNT_10=$(./ticket.sh list --count 10 2>&1 | grep -E "^[[:space:]]*ticket_path:" | wc -l | tr -d ' ')

if [[ $COUNT_1 -eq 1 ]] && [[ $COUNT_3 -eq 3 ]] && [[ $COUNT_10 -eq 5 ]]; then
    test_result 0 "Count parameter works correctly"
else
    test_result 1 "Count parameter not working" "Got: 1=$COUNT_1, 3=$COUNT_3, 10=$COUNT_10"
fi

# Test 6: Invalid count values
echo -e "\n6. Testing invalid count values..."
if ./ticket.sh list --count 0 >/dev/null 2>&1; then
    test_result 1 "Should reject count 0"
else
    test_result 0 "Correctly rejects count 0"
fi

if ./ticket.sh list --count abc >/dev/null 2>&1; then
    test_result 1 "Should reject non-numeric count"
else
    test_result 0 "Correctly rejects non-numeric count"
fi

# Test 7: Custom branch prefix
echo -e "\n7. Testing custom branch prefix..."
cd .. && setup_test
# Modify config
# Use portable sed
sed_i 's/branch_prefix: "feature\/"/branch_prefix: "ticket\/"/' .ticket-config.yaml

./ticket.sh new custom-branch >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add"
TICKET=$(safe_get_ticket_name "*custom-branch.md")
./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1

BRANCH=$(git branch --show-current)
if [[ "$BRANCH" == "ticket/$TICKET" ]]; then
    test_result 0 "Custom branch prefix works"
else
    test_result 1 "Custom branch prefix not applied" "Got: $BRANCH"
fi

# Test 8: Dirty working directory
echo -e "\n8. Testing operations with dirty working directory..."
git checkout -q develop
echo "dirty" > dirty.txt
if ./ticket.sh start some-ticket --no-push >/dev/null 2>&1; then
    test_result 1 "Should prevent start with uncommitted changes"
else
    test_result 0 "Correctly prevents start with dirty directory"
fi

# Test 9: Multiple tickets workflow
echo -e "\n9. Testing multiple tickets workflow..."
cd .. && setup_test

# Create and start first ticket
./ticket.sh new "feature-a" >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add a"
TICKET_A=$(safe_get_ticket_name "*feature-a.md")
./ticket.sh start "$TICKET_A" --no-push >/dev/null 2>&1
git add tickets current-ticket.md && git commit -q -m "start a"
echo "work a" > work-a.txt
git add work-a.txt && git commit -q -m "work a"

# Go back and start second ticket
git checkout -q develop
./ticket.sh new "feature-b" >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add b"
TICKET_B=$(safe_get_ticket_name "*feature-b.md")
./ticket.sh start "$TICKET_B" --no-push >/dev/null 2>&1
git add tickets current-ticket.md && git commit -q -m "start b"

# Check both branches exist using more reliable method
BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -c "^feature/")
if [[ $BRANCHES -eq 2 ]]; then
    test_result 0 "Multiple feature branches can coexist"
else
    test_result 1 "Problem with multiple branches" "Found $BRANCHES branches"
fi

# Test 10: YAML frontmatter edge cases
echo -e "\n10. Testing YAML frontmatter handling..."
cd .. && setup_test

# Create ticket with special characters in description
cat > tickets/test-yaml.md << 'EOF'
---
priority: 1
tags: []
description: "Test with: colons and \"quotes\""
created_at: "2025-01-01T00:00:00Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Test Ticket
EOF

OUTPUT=$(./ticket.sh list 2>&1)
if echo "$OUTPUT" | grep -q "Test with: colons"; then
    test_result 0 "Handles special characters in YAML"
else
    test_result 1 "Problem with special characters in YAML"
fi

# Test 11: Priority sorting
echo -e "\n11. Testing priority sorting in list..."
cd .. && setup_test

# Create tickets with different priorities
for i in 3 1 2; do
    ./ticket.sh new "priority-$i" >/dev/null 2>&1
    TICKET=$(safe_get_first_file "*priority-$i.md" "tickets")
    if [[ -n "$TICKET" ]]; then
        # Portable sed for priority update
        sed_i "s/priority: 2/priority: $i/" "$TICKET"
    fi
done

# Start one to test status+priority sorting
git add tickets .ticket-config.yaml && git commit -q -m "add all"
TICKET_2=$(safe_get_ticket_name "*priority-2.md")
./ticket.sh start "$TICKET_2" --no-push >/dev/null 2>&1

# Stay on feature branch to commit the started_at change
git add tickets current-ticket.md && git commit -q -m "start ticket"

# Merge the change back to develop so started_at is visible
git checkout -q develop
git merge --no-ff -q "feature/$TICKET_2" -m "Merge feature branch" >/dev/null 2>&1

# Now check order in list from develop branch
LIST_OUTPUT=$(./ticket.sh list 2>&1)
# Get the first ticket name (should be priority-2 with doing status)
FIRST_TICKET=$(echo "$LIST_OUTPUT" | grep "ticket_path:" | head -1 | awk '{print $2}')
if [[ "$FIRST_TICKET" == *"priority-2"* ]]; then
    test_result 0 "Doing status shown first (status > priority)"
else
    test_result 1 "Priority sorting may be incorrect" "First ticket was: $FIRST_TICKET"
fi

# Test 12: Auto-push configuration (for close command)
echo -e "\n12. Testing auto_push configuration..."
cd .. && setup_test

# Test that start command no longer shows push
./ticket.sh new "push-test" >/dev/null 2>&1
git add tickets .ticket-config.yaml && git commit -q -m "add"
TICKET=$(safe_get_ticket_name "*push-test.md")

# Should NOT execute push command in start anymore
OUTPUT=$(./ticket.sh start "$TICKET" 2>&1)
# Check that it only mentions push in the note, not as executed command
if echo "$OUTPUT" | grep -q "^# run command$" && echo "$OUTPUT" | grep -q "^git push"; then
    test_result 1 "Start command should not execute push"
elif echo "$OUTPUT" | grep -q "Use 'git push.*when ready"; then
    test_result 0 "Start command correctly doesn't push (only shows note)"
else
    test_result 1 "Unexpected output from start command"
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== Additional tests completed ===${NC}"