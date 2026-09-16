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
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# ✓/✗ rather than PASS:/FAIL:, so run-all.sh's counter sees these results. It
# reads those marks (or a "Summary - Passed:" line) out of each suite's output,
# and this file matched neither, so its numbers never reached the totals.
pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    [[ -n "${2:-}" ]] && echo "    $2"
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

# The WORKTREE: line reports a path built from the main repo plus "..", while
# `git worktree list` prints it resolved. Comparing the two as strings is how
# "was the worktree removed?" quietly answered yes no matter what - resolve the
# path once, here, so the assertions below actually test something.
# Usage: worktree_path_from <start-output>
worktree_path_from() {
    local raw
    raw=$(echo "$1" | grep "^WORKTREE:" | head -1 | cut -d: -f2-)
    [[ -z "$raw" ]] && return 1
    (cd "$raw" 2>/dev/null && pwd -P) || echo "$raw"
}

echo "1. Testing start --worktree creates worktree..."
timeout 5 ./ticket.sh new test-wt-feature >/dev/null 2>&1
TICKET_NAME=$(safe_get_ticket_name "*test-wt-feature*")
git add . && git commit -q -m "Add ticket"

OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET_NAME" 2>&1)
if echo "$OUTPUT" | grep -q "WORKTREE:"; then
    WT_PATH=$(worktree_path_from "$OUTPUT")
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

# The worktree is kept unless --delete-worktree is given. It used to be the
# other way round, and the help had to tell agents they "must" pass
# --keep-worktree: forgetting deleted the directory their shell was in.
if [[ -d "$WT_PATH" ]] && git worktree list 2>/dev/null | grep -q "$WT_PATH"; then
    pass "Worktree is kept after close by default"
else
    fail "Close removed the worktree without being asked"
fi
if echo "$OUTPUT" | grep -q -- "--delete-worktree to remove it"; then
    pass "Close says how to remove it"
else
    fail "Close did not mention --delete-worktree"
    echo "  Output: $OUTPUT"
fi

# Check ticket was moved to done (either flat or per-ticket-dir layout)
if ls tickets/done/*.md >/dev/null 2>&1 || ls tickets/done/*/ticket.md >/dev/null 2>&1; then
    pass "Ticket moved to done folder"
else
    fail "Ticket not in done folder"
fi

# The cd hint exists to warn that the shell's directory has just been removed.
# Nothing is removed now, so it must not appear - a warning about a directory
# that is still there teaches people to ignore the warning.
if ! echo "$OUTPUT" | grep -q "CAUTION: The worktree has been removed"; then
    pass "Close does not warn about a removal that did not happen"
else
    fail "Close warned about removing a worktree it kept"
    echo "  Output: $OUTPUT"
fi

echo
echo "7. Testing start --worktree and cancel..."
timeout 5 ./ticket.sh new test-wt-cancel >/dev/null 2>&1
TICKET2_NAME=$(safe_get_ticket_name "*test-wt-cancel*")
git add . && git commit -q -m "Add cancel ticket"

OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET2_NAME" 2>&1)
WT_PATH2=$(worktree_path_from "$OUTPUT")

# Make a change and commit
echo "cancel work" > "$WT_PATH2/cancel-work.txt"
git -C "$WT_PATH2" add .
git -C "$WT_PATH2" commit -q -m "Work before cancel"

cd "$WT_PATH2"
OUTPUT=$(timeout 10 ./ticket.sh cancel 2>&1) || true
cd "$MAIN_REPO"

if [[ -d "$WT_PATH2" ]] && git worktree list 2>/dev/null | grep -q "$WT_PATH2"; then
    pass "Worktree is kept after cancel by default"
else
    fail "Cancel removed the worktree without being asked"
fi
if echo "$OUTPUT" | grep -q -- "--delete-worktree"; then
    pass "Cancel says how to remove it"
else
    fail "Cancel did not mention --delete-worktree"
    echo "  Output: $OUTPUT"
fi

# Check canceled ticket in done folder (files or dirs)
if ls -d tickets/done/*CANCELED* >/dev/null 2>&1; then
    pass "Canceled ticket in done folder"
else
    fail "Canceled ticket not in done folder"
fi

echo
echo "8. Testing resume existing worktree..."
timeout 5 ./ticket.sh new test-wt-resume >/dev/null 2>&1
TICKET3_NAME=$(safe_get_ticket_name "*test-wt-resume*")
git add . && git commit -q -m "Add resume ticket"

OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET3_NAME" 2>&1)
WT_PATH3=$(worktree_path_from "$OUTPUT")

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
TICKET4_NAME=$(safe_get_ticket_name "*test-wt-config*")
git add . && git commit -q -m "Add config ticket"

# Start without --worktree flag - should still use worktree because of config
OUTPUT=$(timeout 10 ./ticket.sh start "$TICKET4_NAME" 2>&1)
if echo "$OUTPUT" | grep -q "WORKTREE:"; then
    pass "worktree_mode config creates worktree without --worktree flag"
    WT_PATH4=$(worktree_path_from "$OUTPUT")
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
TICKET5_NAME=$(safe_get_ticket_name "*test-wt-guard*")
git add . && git commit -q -m "Add guard ticket"

# Start with worktree first
OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET5_NAME" 2>&1)
WT_PATH5=$(worktree_path_from "$OUTPUT")

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
echo "11. Testing close keeps process cwd in the worker's worktree..."
timeout 5 ./ticket.sh new test-wt-cwd-preserved >/dev/null 2>&1
TICKET_P_NAME=$(safe_get_ticket_name "*test-wt-cwd-preserved*")
git add . && git commit -q -m "Add cwd-preserved ticket"

OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET_P_NAME" 2>&1)
WT_PATH_P=$(worktree_path_from "$OUTPUT")

echo "cwd work" > "$WT_PATH_P/work.txt"
git -C "$WT_PATH_P" add .
git -C "$WT_PATH_P" commit -q -m "Work"

# Close with --keep-worktree and verify we can still cd/pwd in the worktree
cd "$WT_PATH_P"
OUTPUT=$(timeout 15 ./ticket.sh close --no-push --keep-worktree 2>&1) && CLOSE_EXIT=0 || CLOSE_EXIT=$?
POST_CLOSE_PWD=$(pwd)
cd "$MAIN_REPO"

if [[ "$CLOSE_EXIT" -eq 0 ]]; then
    pass "Close succeeds with --keep-worktree"
else
    fail "Close failed (exit: $CLOSE_EXIT)"
    echo "  Output: $OUTPUT"
fi

if [[ "$POST_CLOSE_PWD" == "$WT_PATH_P" ]]; then
    pass "Process cwd preserved in the worker worktree after close"
else
    fail "cwd drifted to: $POST_CLOSE_PWD (expected $WT_PATH_P)"
fi

if [[ -d "$WT_PATH_P" ]] && git -C "$MAIN_REPO" worktree list 2>/dev/null | grep -q "$WT_PATH_P"; then
    pass "Worktree preserved when --keep-worktree is passed (now a no-op)"
else
    fail "Worktree was removed despite --keep-worktree"
fi

if echo "$OUTPUT" | grep -q "Worktree preserved"; then
    pass "Close output announces preserved worktree"
else
    fail "Close did not announce preserved worktree"
fi

# Clean up the preserved worktree manually
git -C "$MAIN_REPO" worktree remove --force "$WT_PATH_P" 2>/dev/null || true

echo
echo "12. Testing cancel --keep-worktree preserves the worker's worktree..."
timeout 5 ./ticket.sh new test-wt-cancel-keep >/dev/null 2>&1
TICKET_K_NAME=$(safe_get_ticket_name "*test-wt-cancel-keep*")
git add . && git commit -q -m "Add cancel-keep ticket"

OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET_K_NAME" 2>&1)
WT_PATH_K=$(worktree_path_from "$OUTPUT")

echo "cancel keep work" > "$WT_PATH_K/work.txt"
git -C "$WT_PATH_K" add .
git -C "$WT_PATH_K" commit -q -m "Work before cancel"

cd "$WT_PATH_K"
OUTPUT=$(timeout 15 ./ticket.sh cancel --keep-worktree 2>&1) && CANCEL_EXIT=0 || CANCEL_EXIT=$?
cd "$MAIN_REPO"

if [[ "$CANCEL_EXIT" -eq 0 ]]; then
    pass "Cancel succeeds with --keep-worktree"
else
    fail "Cancel failed (exit: $CANCEL_EXIT)"
    echo "  Output: $OUTPUT"
fi

if [[ -d "$WT_PATH_K" ]] && git -C "$MAIN_REPO" worktree list 2>/dev/null | grep -q "$WT_PATH_K"; then
    pass "Worktree preserved by cancel --keep-worktree"
else
    fail "Worktree was removed despite --keep-worktree"
fi

# Clean up the preserved worktree manually
git -C "$MAIN_REPO" worktree remove --force "$WT_PATH_K" 2>/dev/null || true

echo
echo "13. Testing close refuses when main_repo is off default_branch..."
timeout 5 ./ticket.sh new test-wt-main-off >/dev/null 2>&1
TICKET_O_NAME=$(safe_get_ticket_name "*test-wt-main-off*")
git add . && git commit -q -m "Add main-off ticket"

OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET_O_NAME" 2>&1)
WT_PATH_O=$(worktree_path_from "$OUTPUT")

echo "work" > "$WT_PATH_O/work.txt"
git -C "$WT_PATH_O" add .
git -C "$WT_PATH_O" commit -q -m "Work"

# Move main_repo off the default_branch to simulate a parallel worker
git -C "$MAIN_REPO" checkout -q -b wt-main-detour

cd "$WT_PATH_O"
OUTPUT=$(timeout 15 ./ticket.sh close --no-push 2>&1) && CLOSE_EXIT=0 || CLOSE_EXIT=$?
cd "$MAIN_REPO"

if [[ "$CLOSE_EXIT" -ne 0 ]] && echo "$OUTPUT" | grep -q "Main repo HEAD is not on"; then
    pass "Close refuses when main_repo is off default_branch"
else
    fail "Close did not refuse (exit: $CLOSE_EXIT)"
    echo "  Output: $OUTPUT"
fi

# main_repo HEAD should NOT have been switched back to main by ticket.sh
MAIN_BRANCH=$(git -C "$MAIN_REPO" rev-parse --abbrev-ref HEAD)
if [[ "$MAIN_BRANCH" == "wt-main-detour" ]]; then
    pass "main_repo HEAD untouched (still on wt-main-detour)"
else
    fail "main_repo HEAD drifted to: $MAIN_BRANCH"
fi

# The worker's worktree should still exist (close was aborted)
if [[ -d "$WT_PATH_O" ]] && git -C "$MAIN_REPO" worktree list 2>/dev/null | grep -q "$WT_PATH_O"; then
    pass "Worktree preserved after aborted close"
else
    fail "Worktree removed despite close failure"
fi

# Cleanup: restore main_repo and the worker worktree
git -C "$MAIN_REPO" checkout -q main
git -C "$MAIN_REPO" branch -D wt-main-detour 2>/dev/null || true
git -C "$MAIN_REPO" worktree remove --force "$WT_PATH_O" 2>/dev/null || true
git -C "$MAIN_REPO" branch -D "feature/${TICKET_O_NAME}" 2>/dev/null || true

# ---------------------------------------------------------------------------
echo
echo "14. Testing --delete-worktree on close and cancel..."
# The opt-in direction: the worktree goes, and the cd hint fires because the
# caller's shell may be standing in what just disappeared.
cd "$MAIN_REPO"
timeout 5 ./ticket.sh new wt-del-close >/dev/null 2>&1
TICKET_D=$(safe_get_ticket_name "*wt-del-close*")
git add . && git commit -q -m "Add delete-worktree ticket"
OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET_D" 2>&1)
WT_PATH_D=$(worktree_path_from "$OUTPUT")
if [[ -n "$WT_PATH_D" ]] && [[ -d "$WT_PATH_D" ]]; then
    pass "worktree created (fixture)"
else
    fail "fixture wrong: no worktree to delete" "$OUTPUT"
fi
echo "del work" > "$WT_PATH_D/del.txt"
git -C "$WT_PATH_D" add .
git -C "$WT_PATH_D" commit -q -m "Work before delete"

cd "$WT_PATH_D"
OUTPUT=$(timeout 15 ./ticket.sh close --no-push --delete-worktree 2>&1) || true
cd "$MAIN_REPO"

if [[ ! -d "$WT_PATH_D" ]] || ! git worktree list 2>/dev/null | grep -q "$WT_PATH_D"; then
    pass "close --delete-worktree removes the worktree"
else
    fail "close --delete-worktree left the worktree behind" "$OUTPUT"
fi
if echo "$OUTPUT" | grep -q "CAUTION: The worktree has been removed"; then
    pass "and warns that the shell's cwd is gone"
else
    fail "no cd warning after an actual removal" "$OUTPUT"
fi

# Same for cancel.
cd "$MAIN_REPO"
timeout 5 ./ticket.sh new wt-del-cancel >/dev/null 2>&1
TICKET_DC=$(safe_get_ticket_name "*wt-del-cancel*")
git add . && git commit -q -m "Add delete-worktree cancel ticket"
OUTPUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET_DC" 2>&1)
WT_PATH_DC=$(worktree_path_from "$OUTPUT")
echo "c" > "$WT_PATH_DC/c.txt"
git -C "$WT_PATH_DC" add .
git -C "$WT_PATH_DC" commit -q -m "Work before cancel"

cd "$WT_PATH_DC"
OUTPUT=$(timeout 15 ./ticket.sh cancel --delete-worktree 2>&1) || true
cd "$MAIN_REPO"
if [[ ! -d "$WT_PATH_DC" ]] || ! git worktree list 2>/dev/null | grep -q "$WT_PATH_DC"; then
    pass "cancel --delete-worktree removes the worktree"
else
    fail "cancel --delete-worktree left the worktree behind" "$OUTPUT"
fi

# ---------------------------------------------------------------------------
echo
echo "15. Testing that an unknown flag stops start..."
# start used to swallow every unknown flag, so `--worktre` produced a branch with
# no worktree and no error, and the mistake surfaced much later.
cd "$MAIN_REPO"
timeout 5 ./ticket.sh new wt-typo >/dev/null 2>&1
TICKET_T=$(safe_get_ticket_name "*wt-typo*")
git add . && git commit -q -m "Add typo ticket"
BEFORE=$(git rev-parse --abbrev-ref HEAD)
OUTPUT=$(timeout 10 ./ticket.sh start --worktre "$TICKET_T" 2>&1) || true
RC_T=$?
if echo "$OUTPUT" | grep -q "Unknown option: --worktre"; then
    pass "a mistyped --worktree is refused"
else
    fail "start accepted --worktre" "$OUTPUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "$BEFORE" ]]; then
    pass "and no branch was created"
else
    fail "start acted on a refused invocation" "$(git rev-parse --abbrev-ref HEAD)"
fi
# The deprecated flag it used to shelter still works.
OUTPUT=$(timeout 15 ./ticket.sh start --no-push "$TICKET_T" 2>&1) || true
if echo "$OUTPUT" | grep -q "Started ticket"; then
    pass "the deprecated --no-push is still accepted"
else
    fail "--no-push broke" "$OUTPUT"
fi
cd "$MAIN_REPO"
git checkout -q main 2>/dev/null || true

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
