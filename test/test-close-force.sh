#!/usr/bin/env bash

# Test for close --force option

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
mkdir "$TEST_DIR"
cd "$TEST_DIR"
cp ../../ticket.sh .
git init -q
git config user.name "Test"
git config user.email "test@test.com"
echo "test" > README.md
git add . && git commit -q -m "init"
git checkout -q -b develop
./ticket.sh init >/dev/null

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
git add . && git commit -q -m "add ticket"
TICKET=$(ls tickets/*.md | xargs basename | sed 's/.md$//')
./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1

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
# Setup again
rm -rf .git tickets .ticket-config.yml current-ticket.md
git init -q
git config user.name "Test"
git config user.email "test@test.com"
echo "test" > README.md
git add . && git commit -q -m "init"
git checkout -q -b develop
./ticket.sh init >/dev/null

./ticket.sh new test-short >/dev/null 2>&1
git add . && git commit -q -m "add ticket"
TICKET=$(ls tickets/*.md | xargs basename | sed 's/.md$//')
./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1

# Create uncommitted changes
echo "more uncommitted" > another-dirty.txt

# Try with -f short form
if ./ticket.sh close -f --no-push >/dev/null 2>&1; then
    test_result 0 "Short form -f works correctly"
else
    test_result 1 "Short form -f should work"
fi

echo -e "\n4. Testing combined options..."
# Setup again
rm -rf .git tickets .ticket-config.yml current-ticket.md
git init -q
git config user.name "Test"
git config user.email "test@test.com"
echo "test" > README.md
git add . && git commit -q -m "init"
git checkout -q -b develop
./ticket.sh init >/dev/null

./ticket.sh new test-combined >/dev/null 2>&1
git add . && git commit -q -m "add ticket"
TICKET=$(ls tickets/*.md | xargs basename | sed 's/.md$//')
./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1

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