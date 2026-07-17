#!/usr/bin/env bash

# Check if running with bash (POSIX compatible check)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This test requires bash. Please run with 'bash test/test-merge-to.sh'"
    echo "Current shell: $0"
    exit 1
fi

# Test suite for base_branch field in ticket YAML frontmatter
# Also tests backward compatibility with merge_to field
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== base_branch Field Tests ==="
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
# Test 1: New ticket includes base_branch field
# =====================================================
echo "1. Testing new ticket includes base_branch field..."
./ticket.sh new test-merge-field >/dev/null
TICKET_NAME=$(safe_get_ticket_name "*test-merge-field*")
TICKET_FILE=$(ticket_body_path "$TICKET_NAME")
if grep -q "base_branch:" "$TICKET_FILE"; then
    pass "base_branch field exists in new ticket"
else
    fail "base_branch field missing from new ticket"
fi
if grep -q "base_branch: default" "$TICKET_FILE"; then
    pass "base_branch defaults to 'default'"
else
    fail "base_branch should default to 'default'"
fi
# Clean up
git add -A && git commit -q -m "add test ticket"

# =====================================================
# Test 2: Close with base_branch=default merges to default_branch
# =====================================================
echo "2. Testing close with base_branch=default (should use default_branch)..."
./ticket.sh new default-merge >/dev/null
TICKET_NAME=$(safe_get_ticket_name "*default-merge*")
TICKET_FILE=$(ticket_body_path "$TICKET_NAME")
git add -A && git commit -q -m "add ticket"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "test content" > testfile-default.txt
git add testfile-default.txt && git commit -q -m "add test file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" ]]; then
    pass "Returned to main branch with base_branch=default"
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
# Test 3: Start branches from base_branch, close merges to it
# =====================================================
echo "3. Testing start branches from base_branch and close merges to it..."
./ticket.sh new custom-target >/dev/null
TICKET_NAME=$(safe_get_ticket_name "*custom-target*")
TICKET_FILE=$(ticket_body_path "$TICKET_NAME")
# Set base_branch to the epic branch
sed -i.bak "s/base_branch: default/base_branch: epic\/release-1/" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with custom base_branch"
# Create the target branch AFTER committing the ticket so the ticket file
# is visible from both main and epic/release-1 (start checks it out).
git branch epic/release-1
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1

# Verify the feature branch was created from epic/release-1
MERGE_BASE=$(git merge-base HEAD epic/release-1)
EPIC_HEAD=$(git rev-parse epic/release-1)
if [[ "$MERGE_BASE" == "$EPIC_HEAD" ]]; then
    pass "Feature branch created from base_branch epic/release-1"
else
    fail "Feature branch not based on epic/release-1"
fi

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
# Test 4: Start with non-existent base_branch fails
# =====================================================
echo "4. Testing start with non-existent base_branch..."
./ticket.sh new bad-target >/dev/null
TICKET_NAME=$(safe_get_ticket_name "*bad-target*")
TICKET_FILE=$(ticket_body_path "$TICKET_NAME")
sed -i.bak "s/base_branch: default/base_branch: nonexistent-branch/" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with bad base_branch"
# A non-existent base_branch must be reported as an error somewhere in the
# start/close workflow. Current ticket.sh warns and falls back at start
# time, then errors at close time — either signal is acceptable, so long as
# some "does not exist" (or equivalent) message surfaces.
START_OUT=$(./ticket.sh start "$TICKET_NAME" 2>&1 || true)
if echo "$START_OUT" | grep -q "does not exist"; then
    pass "Error shown for non-existent base_branch on start"
else
    # Not surfaced at start — drive through close and check there.
    echo "content" > testfile-bad.txt
    git add -A && git commit -q -m "add file" || true
    CLOSE_OUT=$(./ticket.sh close --no-push --force 2>&1 || true)
    if echo "$CLOSE_OUT" | grep -q "does not exist"; then
        pass "Error shown for non-existent base_branch on close"
    else
        fail "Should error for non-existent base_branch on start or close"
    fi
    # Recover to main to allow the next test to run cleanly.
    git checkout -q --force main 2>/dev/null || true
fi
# Cleanup so subsequent tests start from a clean main branch.
git checkout -q main 2>/dev/null || true
git branch -D "feature/$TICKET_NAME" 2>/dev/null || true
echo

# =====================================================
# Test 5: base_branch with empty string uses default_branch
# =====================================================
echo "5. Testing close with empty base_branch..."
./ticket.sh new empty-merge >/dev/null
TICKET_NAME=$(safe_get_ticket_name "*empty-merge*")
TICKET_FILE=$(ticket_body_path "$TICKET_NAME")
sed -i.bak 's/base_branch: default/base_branch: ""/' "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with empty base_branch"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "empty merge content" > testfile-empty.txt
git add testfile-empty.txt && git commit -q -m "add empty merge file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" ]]; then
    pass "Empty base_branch falls back to default_branch"
else
    fail "Expected main, got: $CURRENT"
fi
echo

# =====================================================
# Test 6: base_branch is case-insensitive for "default"
# =====================================================
echo "6. Testing base_branch case-insensitivity for 'default'..."
./ticket.sh new case-test >/dev/null
TICKET_NAME=$(safe_get_ticket_name "*case-test*")
TICKET_FILE=$(ticket_body_path "$TICKET_NAME")
sed -i.bak "s/base_branch: default/base_branch: Default/" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with Default base_branch"
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
TICKET_NAME=$(safe_get_ticket_name "*case-upper*")
TICKET_FILE=$(ticket_body_path "$TICKET_NAME")
sed -i.bak "s/base_branch: default/base_branch: DEFAULT/" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with DEFAULT base_branch"
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
# Test 7: base_branch with null uses default_branch
# =====================================================
echo "7. Testing close with base_branch=null..."
./ticket.sh new null-merge >/dev/null
TICKET_NAME=$(safe_get_ticket_name "*null-merge*")
TICKET_FILE=$(ticket_body_path "$TICKET_NAME")
sed -i.bak "s/base_branch: default/base_branch: null/" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with null base_branch"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "null merge content" > testfile-null.txt
git add testfile-null.txt && git commit -q -m "add null merge file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" ]]; then
    pass "null base_branch falls back to default_branch"
else
    fail "Expected main, got: $CURRENT"
fi
echo

# =====================================================
# Test 8: Ticket without base_branch field uses default_branch
# =====================================================
echo "8. Testing close without base_branch field in ticket..."
./ticket.sh new no-field >/dev/null
TICKET_NAME=$(safe_get_ticket_name "*no-field*")
TICKET_FILE=$(ticket_body_path "$TICKET_NAME")
# Remove base_branch line entirely
sed -i.bak "/base_branch:/d" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket without base_branch field"
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1
echo "no field content" > testfile-nofield.txt
git add testfile-nofield.txt && git commit -q -m "add no-field file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" ]]; then
    pass "Missing base_branch field falls back to default_branch"
else
    fail "Expected main, got: $CURRENT"
fi
echo

# =====================================================
# Test 9: Backward compat - merge_to field still works
# =====================================================
echo "9. Testing backward compatibility with merge_to field..."
./ticket.sh new compat-test >/dev/null
TICKET_NAME=$(safe_get_ticket_name "*compat-test*")
TICKET_FILE=$(ticket_body_path "$TICKET_NAME")
# Replace base_branch with old merge_to field
sed -i.bak "s/base_branch: default.*/merge_to: compat\/target/" "$TICKET_FILE"
rm -f "${TICKET_FILE}.bak"
git add -A && git commit -q -m "add ticket with old merge_to field"
# Create the target branch AFTER committing so the ticket is visible from it.
git branch compat/target
./ticket.sh start "$TICKET_NAME" >/dev/null 2>&1

# Verify branched from compat/target
MERGE_BASE=$(git merge-base HEAD compat/target)
COMPAT_HEAD=$(git rev-parse compat/target)
if [[ "$MERGE_BASE" == "$COMPAT_HEAD" ]]; then
    pass "merge_to backward compat: branched from compat/target"
else
    fail "merge_to backward compat: did not branch from compat/target"
fi

echo "compat content" > testfile-compat.txt
git add testfile-compat.txt && git commit -q -m "add compat file"
./ticket.sh close --no-push --force >/dev/null 2>&1
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "compat/target" ]]; then
    pass "merge_to backward compat: merged to compat/target"
else
    fail "merge_to backward compat: expected compat/target, got: $CURRENT"
fi
git checkout -q main
echo

# =====================================================
# Summary
# =====================================================
echo "=== base_branch Field Tests Complete ==="
echo "Passed: $PASSED, Failed: $FAILED"

# Cleanup
cd ..
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
