#!/usr/bin/env bash

# Check if running with bash (POSIX compatible check)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This test requires bash. Please run with 'bash test/test-merge-to.sh'"
    echo "Current shell: $0"
    exit 1
fi

# Test suite for merge_to field in ticket YAML frontmatter
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== merge_to Field Tests ==="
echo

# Source helper functions
source "${SCRIPT_DIR}/test-helpers.sh"

PASSED=0
FAILED=0

pass() {
    echo "  ✓ $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo "  ✗ $1"
    FAILED=$((FAILED + 1))
}

# Setup
TEST_DIR="tmp/test-merge-to-$(date +%s)"
echo "Setting up test environment..."
mkdir -p tmp
rm -rf "$TEST_DIR"
setup_test_repo "$TEST_DIR"

# Commit ticket system files
git add -A && git commit -q -m "setup tickets"
echo "Test environment ready."
echo

# =====================================================
# Test 1: New ticket includes merge_to field
# =====================================================
echo "1. Testing new ticket includes merge_to field..."
./ticket.sh new test-merge-field >/dev/null
TICKET_FILE=$(ls tickets/*test-merge-field.md | head -1)
if grep -q "merge_to:" "$TICKET_FILE"; then
    pass "merge_to field exists in new ticket"
else
    fail "merge_to field missing from new ticket"
fi
if grep -q "merge_to: default" "$TICKET_FILE"; then
    pass "merge_to defaults to 'default'"
else
    fail "merge_to should default to 'default'"
fi
# Clean up
git add -A && git commit -q -m "add test ticket"

# =====================================================
# Test 2: Close with merge_to=default merges to default_branch
# =====================================================
echo "2. Testing close with merge_to=default (should use default_branch)..."
./ticket.sh new default-merge >/dev/null
TICKET_FILE=$(ls tickets/*default-merge.md | head -1)
TICKET_NAME=$(basename "$TICKET_FILE" .md)
git add -A && git commit -q -m "add ticket"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "test content" > testfile-default.txt
git add testfile-default.txt && git commit -q -m "add test file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" ]]; then
    pass "Returned to main branch with merge_to=default"
else
    fail "Expected main branch, got: $CURRENT"
fi
if [[ -f "testfile-default.txt" ]]; then
    pass "Changes merged to main"
else
    fail "Changes not found on main"
fi
echo

# =====================================================
# Test 3: Close with merge_to=<branch> merges to that branch
# =====================================================
echo "3. Testing close with merge_to pointing to custom branch..."
# Create target branch
git checkout -q -b epic/release-1
git checkout -q main

./ticket.sh new custom-target >/dev/null
TICKET_FILE=$(ls tickets/*custom-target.md | head -1)
TICKET_NAME=$(basename "$TICKET_FILE" .md)
# Set merge_to to the epic branch
sed -i.bak "s/merge_to: default/merge_to: epic\/release-1/" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with custom merge_to"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "epic content" > testfile-epic.txt
git add testfile-epic.txt && git commit -q -m "add epic file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "epic/release-1" ]]; then
    pass "Merged to custom branch epic/release-1"
else
    fail "Expected epic/release-1, got: $CURRENT"
fi
if [[ -f "testfile-epic.txt" ]]; then
    pass "Changes present on epic/release-1"
else
    fail "Changes not found on epic/release-1"
fi
# Return to main for next tests
git checkout -q main
echo

# =====================================================
# Test 4: Close with non-existent merge_to branch fails
# =====================================================
echo "4. Testing close with non-existent merge_to branch..."
./ticket.sh new bad-target >/dev/null
TICKET_FILE=$(ls tickets/*bad-target.md | head -1)
TICKET_NAME=$(basename "$TICKET_FILE" .md)
sed -i.bak "s/merge_to: default/merge_to: nonexistent-branch/" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with bad merge_to"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "bad content" > testfile-bad.txt
git add testfile-bad.txt && git commit -q -m "add bad file"
if ./ticket.sh close --no-push --force 2>&1 | grep -q "does not exist"; then
    pass "Error shown for non-existent merge_to branch"
else
    fail "Should error for non-existent merge_to branch"
fi
# Clean up - we're still on feature branch
git checkout -q main
echo

# =====================================================
# Test 5: merge_to with empty string uses default_branch
# =====================================================
echo "5. Testing close with empty merge_to..."
./ticket.sh new empty-merge >/dev/null
TICKET_FILE=$(ls tickets/*empty-merge.md | head -1)
TICKET_NAME=$(basename "$TICKET_FILE" .md)
sed -i.bak 's/merge_to: default/merge_to: ""/' "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with empty merge_to"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "empty merge content" > testfile-empty.txt
git add testfile-empty.txt && git commit -q -m "add empty merge file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" ]]; then
    pass "Empty merge_to falls back to default_branch"
else
    fail "Expected main, got: $CURRENT"
fi
echo

# =====================================================
# Test 6: merge_to is case-insensitive for "default"
# =====================================================
echo "6. Testing merge_to case-insensitivity for 'default'..."
./ticket.sh new case-test >/dev/null
TICKET_FILE=$(ls tickets/*case-test.md | head -1)
TICKET_NAME=$(basename "$TICKET_FILE" .md)
sed -i.bak "s/merge_to: default/merge_to: Default/" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with Default merge_to"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "case test content" > testfile-case.txt
git add testfile-case.txt && git commit -q -m "add case test file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" ]]; then
    pass "'Default' (capitalized) treated as default"
else
    fail "Expected main, got: $CURRENT"
fi

./ticket.sh new case-upper >/dev/null
TICKET_FILE=$(ls tickets/*case-upper.md | head -1)
TICKET_NAME=$(basename "$TICKET_FILE" .md)
sed -i.bak "s/merge_to: default/merge_to: DEFAULT/" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with DEFAULT merge_to"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "upper case content" > testfile-upper.txt
git add testfile-upper.txt && git commit -q -m "add upper case file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" ]]; then
    pass "'DEFAULT' (all caps) treated as default"
else
    fail "Expected main, got: $CURRENT"
fi
echo

# =====================================================
# Test 7: merge_to with null uses default_branch
# =====================================================
echo "7. Testing close with merge_to=null..."
./ticket.sh new null-merge >/dev/null
TICKET_FILE=$(ls tickets/*null-merge.md | head -1)
TICKET_NAME=$(basename "$TICKET_FILE" .md)
sed -i.bak "s/merge_to: default/merge_to: null/" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with null merge_to"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "null merge content" > testfile-null.txt
git add testfile-null.txt && git commit -q -m "add null merge file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" ]]; then
    pass "null merge_to falls back to default_branch"
else
    fail "Expected main, got: $CURRENT"
fi
echo

# =====================================================
# Test 8: Ticket without merge_to field uses default_branch
# =====================================================
echo "8. Testing close without merge_to field in ticket..."
./ticket.sh new no-field >/dev/null
TICKET_FILE=$(ls tickets/*no-field.md | head -1)
TICKET_NAME=$(basename "$TICKET_FILE" .md)
# Remove merge_to line entirely
sed -i.bak "/merge_to:/d" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket without merge_to field"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "no field content" > testfile-nofield.txt
git add testfile-nofield.txt && git commit -q -m "add no-field file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" ]]; then
    pass "Missing merge_to field falls back to default_branch"
else
    fail "Expected main, got: $CURRENT"
fi
echo

# =====================================================
# Summary
# =====================================================
echo "=== merge_to Field Tests Complete ==="
echo "Passed: $PASSED, Failed: $FAILED"

# Cleanup
cd ..
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
