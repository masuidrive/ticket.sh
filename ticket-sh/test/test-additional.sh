#!/usr/bin/env bash

# Additional test cases for ticket.sh
# Tests edge cases and error conditions not covered by other tests

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
    rm -rf "$TEST_DIR"
    mkdir "$TEST_DIR"
    cd "$TEST_DIR"
    cp ../ticket.sh .
    git init -q
    git config user.name "Test"
    git config user.email "test@test.com"
    echo "test" > README.md
    git add . && git commit -q -m "init"
    git checkout -q -b develop
    ./ticket.sh init >/dev/null
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
FIRST_TICKET=$(ls tickets/*test-duplicate.md)
sleep 1  # Ensure different timestamp
if ./ticket.sh new test-duplicate >/dev/null 2>&1; then
    SECOND_TICKET=$(ls tickets/*test-duplicate.md | tail -1)
    if [[ "$FIRST_TICKET" != "$SECOND_TICKET" ]]; then
        test_result 0 "Allows same slug with different timestamp"
    else
        test_result 1 "Should create different files for same slug"
    fi
else
    test_result 1 "Should allow duplicate slug with different timestamp"
fi

# Test 2: Start already started ticket
echo -e "\n2. Testing start on already started ticket..."
git add . && git commit -q -m "add tickets"
TICKET_NAME=$(basename "$FIRST_TICKET" .md)
./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1
git add . && git commit -q -m "update"
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
done

COUNT_1=$(./ticket.sh list --count 1 2>&1 | grep -c "ticket_name:")
COUNT_3=$(./ticket.sh list --count 3 2>&1 | grep -c "ticket_name:")
COUNT_10=$(./ticket.sh list --count 10 2>&1 | grep -c "ticket_name:")

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
sed -i.bak 's/branch_prefix: "feature\/"/branch_prefix: "ticket\/"/' .ticket-config.yml 2>/dev/null || \
sed -i '' 's/branch_prefix: "feature\/"/branch_prefix: "ticket\/"/' .ticket-config.yml

./ticket.sh new custom-branch >/dev/null 2>&1
git add . && git commit -q -m "add"
TICKET=$(ls tickets/*custom-branch.md | xargs basename | sed 's/.md$//')
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
git add . && git commit -q -m "add a"
TICKET_A=$(ls tickets/*feature-a.md | xargs basename | sed 's/.md$//')
./ticket.sh start "$TICKET_A" --no-push >/dev/null 2>&1
git add . && git commit -q -m "start a"
echo "work a" > work-a.txt
git add . && git commit -q -m "work a"

# Go back and start second ticket
git checkout -q develop
./ticket.sh new "feature-b" >/dev/null 2>&1
git add . && git commit -q -m "add b"
TICKET_B=$(ls tickets/*feature-b.md | xargs basename | sed 's/.md$//')
./ticket.sh start "$TICKET_B" --no-push >/dev/null 2>&1
git add . && git commit -q -m "start b"

# Check both branches exist
BRANCHES=$(git branch | grep -c feature/)
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
    TICKET=$(ls tickets/*priority-$i.md | tail -1)
    sed -i.bak "s/priority: 2/priority: $i/" "$TICKET" 2>/dev/null || \
    sed -i '' "s/priority: 2/priority: $i/" "$TICKET"
done

# Start one to test status+priority sorting
git add . && git commit -q -m "add all"
TICKET_2=$(ls tickets/*priority-2.md | xargs basename | sed 's/.md$//')
./ticket.sh start "$TICKET_2" --no-push >/dev/null 2>&1
git add . && git commit -q -m "start"
git checkout -q develop

# Check order in list
LIST_OUTPUT=$(./ticket.sh list 2>&1)
FIRST=$(echo "$LIST_OUTPUT" | grep -A1 "ticket_name:" | head -1)
if echo "$FIRST" | grep -q "priority-2"; then
    test_result 0 "Doing status shown first (status > priority)"
else
    test_result 1 "Priority sorting may be incorrect"
fi

# Test 12: Auto-push configuration
echo -e "\n12. Testing auto_push configuration..."
cd .. && setup_test

# Test with auto_push: true (default)
./ticket.sh new "push-test" >/dev/null 2>&1
git add . && git commit -q -m "add"
TICKET=$(ls tickets/*push-test.md | xargs basename | sed 's/.md$//')

# Should show push command in output when auto_push is true
OUTPUT=$(./ticket.sh start "$TICKET" 2>&1)
if echo "$OUTPUT" | grep -q "git push"; then
    test_result 0 "Shows push command with auto_push: true"
else
    test_result 1 "Should show push attempt with auto_push: true"
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== Additional tests completed ===${NC}"