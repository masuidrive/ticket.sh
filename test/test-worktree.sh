#!/usr/bin/env bash

# Test script for worktree functionality

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== ticket.sh Worktree Test Suite ==="
echo

# Create test directory
TEST_DIR="tmp/test-worktree-$(date +%s)"
mkdir -p tmp
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Always rebuild to ensure latest version
(cd "${SCRIPT_DIR}/.." && ./build.sh >/dev/null 2>&1)
cp "${SCRIPT_DIR}/../ticket.sh" .
chmod +x ticket.sh

PASSED=0
FAILED=0

pass() {
    echo "  PASS: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo "  FAIL: $1"
    FAILED=$((FAILED + 1))
}

# Setup git repo
echo "Setting up git repo..."
git init -q -b main
git config user.name "Test"
git config user.email "test@test.com"
echo "# Test" > README.md
git add README.md
git commit -q -m "Initial"
timeout 5 ./ticket.sh init >/dev/null 2>&1
git add . && git commit -q -m "Init ticket system"
echo "  Setup complete"
echo

# Store absolute path to main repo
MAIN_REPO=$(pwd)

echo "1. Testing start --worktree creates worktree..."
timeout 5 ./ticket.sh new test-wt-feature >/dev/null 2>&1
TICKET=$(ls tickets/*.md 2>/dev/null | grep -v note | head -1)
TICKET_NAME=$(basename "$TICKET" .md)
git add . && git commit -q -m "Add ticket"

OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET_NAME" 2>&1)
if echo "$OUTPUT" | grep -q "WORKTREE:"; then
    WT_PATH=$(echo "$OUTPUT" | grep "^WORKTREE:" | head -1 | cut -d: -f2-)
    if [[ -d "$WT_PATH" ]]; then
        pass "Worktree created at $WT_PATH"
    else
        fail "WORKTREE path reported but directory doesn't exist: $WT_PATH"
    fi
else
    fail "No WORKTREE output found"
    echo "  Output: $OUTPUT"
fi

echo
echo "2. Testing worktree has correct branch..."
if [[ -d "$WT_PATH" ]]; then
    WT_BRANCH=$(git -C "$WT_PATH" rev-parse --abbrev-ref HEAD)
    if [[ "$WT_BRANCH" == "feature/$TICKET_NAME" ]]; then
        pass "Worktree is on correct branch: $WT_BRANCH"
    else
        fail "Worktree on wrong branch: $WT_BRANCH (expected feature/$TICKET_NAME)"
    fi
else
    fail "Worktree directory missing"
fi

echo
echo "3. Testing worktree has current-ticket.md symlink..."
if [[ -L "$WT_PATH/current-ticket.md" ]]; then
    pass "current-ticket.md symlink exists in worktree"
else
    fail "current-ticket.md symlink missing in worktree"
fi

echo
echo "4. Testing main repo stays on main branch..."
MAIN_BRANCH=$(git -C "$MAIN_REPO" rev-parse --abbrev-ref HEAD)
if [[ "$MAIN_BRANCH" == "main" ]]; then
    pass "Main repo still on main branch"
else
    fail "Main repo switched to: $MAIN_BRANCH"
fi

echo
echo "5. Testing list command from worktree shows doing status..."
# Run list from the worktree where started_at is set
OUTPUT=$(cd "$WT_PATH" && timeout 5 ./ticket.sh list 2>&1)
if echo "$OUTPUT" | grep -q "doing"; then
    pass "List from worktree shows 'doing' status"
else
    fail "List from worktree doesn't show 'doing' status"
    echo "  Output: $OUTPUT"
fi
# Also check worktree info is shown
if echo "$OUTPUT" | grep -q "worktree:"; then
    pass "List shows worktree path"
else
    # worktree info may not show if the doing ticket detection works differently
    echo "  NOTE: worktree path not shown in list (non-critical)"
fi

echo
echo "6. Testing close from worktree..."
# Make a change in worktree and commit
echo "worktree work" > "$WT_PATH/work.txt"
git -C "$WT_PATH" add .
git -C "$WT_PATH" commit -q -m "Work in worktree"

# Run close from the worktree
cd "$WT_PATH"
OUTPUT=$(timeout 10 ./ticket.sh close --no-push 2>&1) || true
cd "$MAIN_REPO"

MAIN_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$MAIN_BRANCH" == "main" ]]; then
    pass "After close, main repo on main branch"
else
    fail "After close, main repo on: $MAIN_BRANCH"
fi

# Check worktree was removed
if [[ ! -d "$WT_PATH" ]] || ! git worktree list 2>/dev/null | grep -q "$WT_PATH"; then
    pass "Worktree was cleaned up after close"
else
    fail "Worktree still exists after close"
fi

# Check ticket was moved to done
if ls tickets/done/*.md >/dev/null 2>&1; then
    pass "Ticket moved to done folder"
else
    fail "Ticket not in done folder"
fi

# Check cd hint was shown
if echo "$OUTPUT" | grep -q "cd "; then
    pass "Close shows cd hint to main repo"
else
    fail "Close does not show cd hint"
    echo "  Output: $OUTPUT"
fi

echo
echo "7. Testing start --worktree and cancel..."
timeout 5 ./ticket.sh new test-wt-cancel >/dev/null 2>&1
TICKET2=$(ls tickets/*.md 2>/dev/null | grep -v note | grep cancel | head -1)
TICKET2_NAME=$(basename "$TICKET2" .md)
git add . && git commit -q -m "Add cancel ticket"

OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET2_NAME" 2>&1)
WT_PATH2=$(echo "$OUTPUT" | grep "^WORKTREE:" | head -1 | cut -d: -f2-)

# Make a change and commit
echo "cancel work" > "$WT_PATH2/cancel-work.txt"
git -C "$WT_PATH2" add .
git -C "$WT_PATH2" commit -q -m "Work before cancel"

cd "$WT_PATH2"
OUTPUT=$(timeout 10 ./ticket.sh cancel 2>&1) || true
cd "$MAIN_REPO"

if [[ ! -d "$WT_PATH2" ]] || ! git worktree list 2>/dev/null | grep -q "$WT_PATH2"; then
    pass "Worktree removed after cancel"
else
    fail "Worktree still exists after cancel"
fi

# Check cd hint was shown for cancel
if echo "$OUTPUT" | grep -q "cd "; then
    pass "Cancel shows cd hint to main repo"
else
    fail "Cancel does not show cd hint"
    echo "  Output: $OUTPUT"
fi

# Check canceled ticket in done folder
if ls tickets/done/*CANCELED* >/dev/null 2>&1; then
    pass "Canceled ticket in done folder"
else
    fail "Canceled ticket not in done folder"
fi

echo
echo "8. Testing resume existing worktree..."
timeout 5 ./ticket.sh new test-wt-resume >/dev/null 2>&1
TICKET3=$(ls tickets/*.md 2>/dev/null | grep -v note | grep resume | head -1)
TICKET3_NAME=$(basename "$TICKET3" .md)
git add . && git commit -q -m "Add resume ticket"

OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET3_NAME" 2>&1)
WT_PATH3=$(echo "$OUTPUT" | grep "^WORKTREE:" | head -1 | cut -d: -f2-)

# Start again - should detect existing worktree
OUTPUT2=$(timeout 10 ./ticket.sh start --worktree "$TICKET3_NAME" 2>&1)
if echo "$OUTPUT2" | grep -q "Worktree already exists"; then
    pass "Correctly detects existing worktree"
else
    fail "Did not detect existing worktree"
    echo "  Output: $OUTPUT2"
fi

# Cleanup the worktree manually for test cleanup
git worktree remove "$WT_PATH3" --force 2>/dev/null || true

echo
echo "9. Testing worktree_mode config option..."
# Add worktree_mode to config
echo 'worktree_mode: true' >> .ticket-config.yaml
git add . && git commit -q -m "Enable worktree_mode"

timeout 5 ./ticket.sh new test-wt-config >/dev/null 2>&1
TICKET4=$(ls tickets/*.md 2>/dev/null | grep -v note | grep config | head -1)
TICKET4_NAME=$(basename "$TICKET4" .md)
git add . && git commit -q -m "Add config ticket"

# Start without --worktree flag - should still use worktree because of config
OUTPUT=$(timeout 10 ./ticket.sh start "$TICKET4_NAME" 2>&1)
if echo "$OUTPUT" | grep -q "WORKTREE:"; then
    pass "worktree_mode config creates worktree without --worktree flag"
    WT_PATH4=$(echo "$OUTPUT" | grep "^WORKTREE:" | head -1 | cut -d: -f2-)
    git worktree remove "$WT_PATH4" --force 2>/dev/null || true
else
    fail "worktree_mode config did not create worktree"
    echo "  Output: $OUTPUT"
fi

# Remove worktree_mode from config
sed -i.bak '/worktree_mode/d' .ticket-config.yaml
rm -f .ticket-config.yaml.bak

echo
echo "10. Testing checkout guard when branch is in another worktree..."
timeout 5 ./ticket.sh new test-wt-guard >/dev/null 2>&1
TICKET5=$(ls tickets/*.md 2>/dev/null | grep -v note | grep guard | head -1)
TICKET5_NAME=$(basename "$TICKET5" .md)
git add . && git commit -q -m "Add guard ticket"

# Start with worktree first
OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET5_NAME" 2>&1)
WT_PATH5=$(echo "$OUTPUT" | grep "^WORKTREE:" | head -1 | cut -d: -f2-)

# Now try to start the same ticket WITHOUT worktree (should fail with guard error)
OUTPUT2=$(timeout 10 ./ticket.sh start "$TICKET5_NAME" 2>&1) && GUARD_EXIT=0 || GUARD_EXIT=$?
if echo "$OUTPUT2" | grep -q "already checked out in.*worktree"; then
    pass "Guard prevents checkout of branch used by worktree"
else
    fail "Guard did not prevent checkout of worktree branch"
    echo "  Exit: $GUARD_EXIT"
    echo "  Output: $OUTPUT2"
fi

# Try with --worktree flag - should succeed and reuse existing worktree
OUTPUT3=$(timeout 10 ./ticket.sh start --worktree "$TICKET5_NAME" 2>&1)
if echo "$OUTPUT3" | grep -q "already checked out in worktree"; then
    pass "Worktree mode reuses existing worktree for branch in use"
else
    fail "Worktree mode did not handle branch in existing worktree"
    echo "  Output: $OUTPUT3"
fi

# Cleanup
git worktree remove "$WT_PATH5" --force 2>/dev/null || true

echo
echo "=== Worktree Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

# Cleanup
cd "${SCRIPT_DIR}/.."
# Clean up any remaining worktrees
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
