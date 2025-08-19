#!/usr/bin/env bash

# Final test suite for ticket.sh
# This version handles errors more gracefully

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test helpers for timeout function
source "$SCRIPT_DIR/test-helpers.sh"

# Test configuration
TEST_DIR="tmp/test-final-$(date +%s)"
ORIGINAL_DIR=$(pwd)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Summary
echo -e "${YELLOW}=== ticket.sh Test Suite ===${NC}"
echo

# Create test environment
echo "Setting up test environment..."
mkdir -p tmp
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Always rebuild to ensure latest version
(cd "${SCRIPT_DIR}/.." && bash ./build.sh >/dev/null 2>&1)
cp "${SCRIPT_DIR}/../ticket.sh" .
chmod +x ticket.sh

# Track results
TESTS=()
RESULTS=()

# Test function
test_case() {
    local name="$1"
    local result="$2"
    TESTS+=("$name")
    RESULTS+=("$result")
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓${NC} $name"
    else
        echo -e "${RED}✗${NC} $name"
    fi
}

echo
echo "Running tests..."
echo

# Test 1: Error handling without git
if timeout 5 ./ticket.sh init  2>&1 | grep -q "Not in a git repository"; then
    test_case "Detects missing git repository" "PASS"
else
    test_case "Detects missing git repository" "FAIL"
fi

# Initialize git
git init -q >/dev/null 2>&1
git config user.name "Test User" >/dev/null 2>&1
git config user.email "test@example.com" >/dev/null 2>&1
echo "# Test" > README.md
git add README.md >/dev/null 2>&1
git commit -q -m "Initial commit" >/dev/null 2>&1
git checkout -q -b main >/dev/null 2>&1

# Test 2: Error handling without config
if timeout 5 ./ticket.sh list 2>&1 | grep -q "not initialized"; then
    test_case "Detects missing config" "PASS"
else
    test_case "Detects missing config" "FAIL"
fi

# Test 3: Initialize
timeout 5 ./ticket.sh init  >/dev/null 2>&1
if [[ -f .ticket-config.yaml ]] && [[ -d tickets ]] && [[ -f .gitignore ]]; then
    test_case "Initialize creates required files" "PASS"
else
    test_case "Initialize creates required files" "FAIL"
fi

# Test 4: Create ticket
./ticket.sh new test-feature >/dev/null 2>&1
if ls tickets/*test-feature.md >/dev/null 2>&1; then
    test_case "Create new ticket" "PASS"
else
    test_case "Create new ticket" "FAIL"
fi

# Test 5: Invalid slug
if ! timeout 5 ./ticket.sh new "Bad Name" >/dev/null 2>&1; then
    test_case "Reject invalid slug" "PASS"
else
    test_case "Reject invalid slug" "FAIL"
fi

# Test 6: List tickets
if timeout 5 ./ticket.sh list 2>&1 | grep -q "test-feature"; then
    test_case "List shows tickets" "PASS"
else
    test_case "List shows tickets" "FAIL"
fi

# Test 7: Start ticket
git add . >/dev/null 2>&1
git commit -q -m "Add ticket" >/dev/null 2>&1
TICKET_NAME=$(ls tickets/*test-feature.md | xargs basename | sed 's/.md$//')
./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [[ "$BRANCH" == "feature/$TICKET_NAME" ]]; then
    test_case "Start creates feature branch" "PASS"
else
    test_case "Start creates feature branch" "FAIL"
fi

if [[ -L current-ticket.md ]]; then
    test_case "Start creates symlink" "PASS"
else
    test_case "Start creates symlink" "FAIL"
fi

# Commit the started_at change
git add tickets/*.md >/dev/null 2>&1
git commit -q -m "Update ticket started_at" >/dev/null 2>&1

# Test 8: Restore
rm -f current-ticket.md
./ticket.sh restore >/dev/null 2>&1
if [[ -L current-ticket.md ]]; then
    test_case "Restore recreates symlink" "PASS"
else
    test_case "Restore recreates symlink" "FAIL"
fi

# Test 9: Close ticket
echo "work" > work.txt
git add work.txt >/dev/null 2>&1
git commit -q -m "Do work" >/dev/null 2>&1

# Close should work from feature branch with current-ticket.md
CLOSE_OUTPUT=$(timeout 5 ./ticket.sh close --no-push 2>&1)
CLOSE_EXIT=$?

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [[ "$BRANCH" == "main" ]] && [[ $CLOSE_EXIT -eq 0 ]]; then
    test_case "Close returns to main" "PASS"
else
    test_case "Close returns to main" "FAIL"
    echo "  Close exit code: $CLOSE_EXIT"
    echo "  Current branch: $BRANCH"
fi

# Check if any ticket has been closed (check in done folder)
if ls tickets/done/*.md 2>/dev/null | xargs grep -l "closed_at: 20" >/dev/null 2>&1; then
    test_case "Close updates ticket" "PASS"
else
    test_case "Close updates ticket" "FAIL"
fi

# Test 10: List with filters
if timeout 5 ./ticket.sh list --status done 2>&1 | grep -q "test-feature"; then
    test_case "List filters by status" "PASS"
else
    test_case "List filters by status" "FAIL"
fi

# Print summary
echo
echo -e "${YELLOW}=== Test Summary ===${NC}"
PASSED=0
FAILED=0
for i in "${!RESULTS[@]}"; do
    if [[ "${RESULTS[$i]}" == "PASS" ]]; then
        ((PASSED++))
    else
        ((FAILED++))
        echo -e "  Failed: ${TESTS[$i]}"
    fi
done

echo -e "Total: ${#TESTS[@]}"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

# Cleanup
cd "$ORIGINAL_DIR"
rm -rf "$TEST_DIR"

# Exit code
[[ $FAILED -eq 0 ]] && exit 0 || exit 1