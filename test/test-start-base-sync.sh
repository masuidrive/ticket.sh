#!/usr/bin/env bash

# Tests for recording started_at on the base branch.
#
# 'start' commits the start-time stamp on the feature branch and fast-forwards
# the base branch onto that commit, so a 'list' run from the base branch sees
# the ticket as doing. These cover both fast-forward mechanisms (merge into a
# checked-out branch, fetch into one nobody holds), the untracked ticket file
# that 'new' leaves behind, and the fallback when the fast-forward can't happen.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== ticket.sh start base-branch sync Test Suite ==="
echo

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/tmp/test-start-base-sync-$(date +%s)"
mkdir -p "${REPO_ROOT}/tmp"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# Always rebuild so the harness runs against current sources.
(cd "$REPO_ROOT" && ./build.sh >/dev/null 2>&1)

PASSED=0
FAILED=0
# Use ✓/✗ marks so run-all.sh's grep-based counter picks them up.
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; [[ -n "${2:-}" ]] && echo "    $2"; FAILED=$((FAILED + 1)); }

# Build a fresh repo with the ticket system initialized. Pushing is off unless a
# test asks for it: these repos have no remote.
# Usage: make_repo <dir-name>  (echoes the absolute path)
make_repo() {
    local name="$1"
    local dir="${TEST_DIR}/${name}"
    rm -rf "$dir"
    mkdir -p "$dir"
    cd "$dir" || return 1

    git init -q -b main
    git config user.name "Test"
    git config user.email "test@test.com"
    echo "# Test" > README.md
    git add README.md
    git commit -q -m "Initial"

    cp "${REPO_ROOT}/ticket.sh" .
    chmod +x ticket.sh
    timeout 10 ./ticket.sh init >/dev/null 2>&1
    sed_i 's/^auto_push: true/auto_push: false/' .ticket-config.yaml
    git add . && git commit -q -m "Init ticket system"

    echo "$dir"
}

# Create a ticket and echo its bare name. Leaves it uncommitted.
make_ticket() {
    local slug="$1"
    timeout 5 ./ticket.sh new "$slug" >/dev/null 2>&1
    safe_get_ticket_name "*${slug}*"
}

started_at_on() {
    local branch="$1" ticket="$2"
    git show "${branch}:tickets/${ticket}/ticket.md" 2>/dev/null | grep "^started_at:" || echo "MISSING"
}

# ---------------------------------------------------------------------------
echo "1. Non-worktree start records started_at on the base branch"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo1)
cd "$REPO"
TICKET=$(make_ticket base-sync)
git add tickets && git commit -q -m "Add ticket"

timeout 10 ./ticket.sh start "$TICKET" >/dev/null 2>&1

MAIN_STAMP=$(started_at_on main "$TICKET")
FEATURE_STAMP=$(started_at_on "feature/${TICKET}" "$TICKET")

if [[ "$MAIN_STAMP" == "MISSING" ]] || echo "$MAIN_STAMP" | grep -q "null"; then
    fail "started_at should be recorded on the base branch" "got: $MAIN_STAMP"
else
    pass "started_at is recorded on the base branch"
fi

if [[ "$MAIN_STAMP" == "$FEATURE_STAMP" ]]; then
    pass "base branch and feature branch carry the same start time"
else
    fail "base and feature start times differ" "main: $MAIN_STAMP / feature: $FEATURE_STAMP"
fi

if [[ "$(git rev-parse main)" == "$(git rev-parse "feature/${TICKET}")" ]]; then
    pass "base branch is fast-forwarded onto the start commit"
else
    fail "base branch was not fast-forwarded onto the start commit"
fi

# The base branch was not checked out at that point (start had switched to the
# feature branch), so this exercised the fetch mechanism.
if git log -1 --format=%s main | grep -q "^\[start\]"; then
    pass "start commit is titled [start] <branch>"
else
    fail "start commit has an unexpected subject" "$(git log -1 --format=%s main)"
fi

# ---------------------------------------------------------------------------
echo
echo "2. list from the base branch shows the ticket as doing"
# ---------------------------------------------------------------------------
git checkout -q main
LIST_OUT=$(timeout 10 ./ticket.sh list 2>&1)
if echo "$LIST_OUT" | grep -q "status: doing"; then
    pass "list run from the base branch reports doing"
else
    fail "list from the base branch should report doing" "$LIST_OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "3. close still works after start has moved the base branch"
# ---------------------------------------------------------------------------
git checkout -q "feature/${TICKET}"
echo "work" > work.txt
git add work.txt && git commit -q -m "Do work"

CLOSE_OUT=$(timeout 20 ./ticket.sh close --no-push 2>&1)
if [[ -f "tickets/done/${TICKET}/ticket.md" ]]; then
    pass "close moves the ticket to done/ after a start commit"
else
    fail "close failed after start moved the base branch" "$CLOSE_OUT"
fi

if grep -q "^closed_at: 2" "tickets/done/${TICKET}/ticket.md" 2>/dev/null &&
   grep -q "^started_at: 2" "tickets/done/${TICKET}/ticket.md" 2>/dev/null; then
    pass "closed ticket keeps both timestamps"
else
    fail "closed ticket lost a timestamp"
fi

# ---------------------------------------------------------------------------
echo
echo "4. Worktree start records it even though 'new' left the ticket untracked"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo2)
cd "$REPO"
TICKET=$(make_ticket wt-sync)

# Deliberately NOT committed: 'new' makes no commit, and an untracked file in
# the main repo would block the fast-forward unless start clears the way.
if [[ -n "$(git status --porcelain tickets/)" ]]; then
    pass "ticket is untracked before start (precondition)"
else
    fail "expected the new ticket to be untracked"
fi

timeout 20 ./ticket.sh start --worktree "$TICKET" >/dev/null 2>&1

MAIN_STAMP=$(started_at_on main "$TICKET")
if [[ "$MAIN_STAMP" == "MISSING" ]] || echo "$MAIN_STAMP" | grep -q "null"; then
    fail "started_at should reach the main repo from a worktree start" "got: $MAIN_STAMP"
else
    pass "started_at reaches the main repo from a worktree start"
fi

if [[ -z "$(git status --porcelain tickets/)" ]]; then
    pass "the untracked ticket file is gone - it is tracked on the base branch now"
else
    fail "main repo still has uncommitted ticket files" "$(git status --porcelain tickets/)"
fi

# This one went through the merge mechanism: main was checked out in the main repo.
if [[ "$(git rev-parse main)" == "$(git rev-parse "feature/${TICKET}")" ]]; then
    pass "main repo is fast-forwarded onto the worktree's start commit"
else
    fail "main repo was not fast-forwarded"
fi

WT_PATH=$(git worktree list --porcelain | awk -v b="branch refs/heads/feature/${TICKET}" '/^worktree /{wt=$0} $0==b{print wt}' | sed 's/^worktree //')

# ---------------------------------------------------------------------------
echo
echo "5. Fast-forward is skipped, not fatal, when the base tree conflicts"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo3)
cd "$REPO"
TICKET=$(make_ticket ff-blocked)
git add tickets && git commit -q -m "Add ticket"

# Leave a conflicting local edit on the base branch's working tree. git refuses
# to fast-forward over it, which is exactly the case start must survive.
echo "# edited in the main repo" >> "tickets/${TICKET}/ticket.md"

START_OUT=$(timeout 20 ./ticket.sh start --worktree "$TICKET" 2>&1)
START_RC=$?

if [[ $START_RC -eq 0 ]] && echo "$START_OUT" | grep -q "Started ticket"; then
    pass "start succeeds even when the base branch cannot be fast-forwarded"
else
    fail "start should not fail when the fast-forward is impossible" "rc=$START_RC"
fi

if echo "$START_OUT" | grep -q "Could not fast-forward"; then
    pass "the skipped fast-forward is reported"
else
    fail "start should say the fast-forward was skipped" "$START_OUT"
fi

FEATURE_STAMP=$(started_at_on "feature/${TICKET}" "$TICKET")
if echo "$FEATURE_STAMP" | grep -q "null" || [[ "$FEATURE_STAMP" == "MISSING" ]]; then
    fail "the start time should still be committed on the feature branch" "$FEATURE_STAMP"
else
    pass "the start time is still committed on the feature branch"
fi

# ---------------------------------------------------------------------------
echo
echo "6. The ticket's base_branch override is the branch that advances"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo4)
cd "$REPO"
git checkout -q -b develop
git checkout -q main
TICKET=$(make_ticket custom-base)
sed_i 's/^base_branch: default.*/base_branch: develop/' "tickets/${TICKET}/ticket.md"
git add tickets && git commit -q -m "Add ticket"
git checkout -q develop
git merge -q main

MAIN_BEFORE=$(git rev-parse main)
timeout 10 ./ticket.sh start "$TICKET" >/dev/null 2>&1

if [[ "$(git rev-parse develop)" == "$(git rev-parse "feature/${TICKET}")" ]]; then
    pass "the ticket's base_branch is the branch that gets fast-forwarded"
else
    fail "develop was not fast-forwarded onto the start commit"
fi

if [[ "$(git rev-parse main)" == "$MAIN_BEFORE" ]]; then
    pass "default_branch is left alone when base_branch overrides it"
else
    fail "main moved even though the ticket targets develop"
fi

# ---------------------------------------------------------------------------
echo
echo "7. Push follows auto_push and --no-push"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo5)
cd "$REPO"
sed_i 's/^auto_push: false/auto_push: true/' .ticket-config.yaml
git add . && git commit -q -m "Enable auto_push"
TICKET=$(make_ticket push-choice)
git add tickets && git commit -q -m "Add ticket"

START_OUT=$(timeout 10 ./ticket.sh start --no-push "$TICKET" 2>&1)
if echo "$START_OUT" | grep -q "push origin main"; then
    fail "--no-push should suppress pushing the base branch" "$START_OUT"
else
    pass "--no-push suppresses pushing the base branch"
fi

REPO=$(make_repo repo6)
cd "$REPO"
sed_i 's/^auto_push: false/auto_push: true/' .ticket-config.yaml
git add . && git commit -q -m "Enable auto_push"
TICKET=$(make_ticket push-on)
git add tickets && git commit -q -m "Add ticket"

START_OUT=$(timeout 10 ./ticket.sh start "$TICKET" 2>&1)
if echo "$START_OUT" | grep -q "push origin main"; then
    pass "auto_push pushes the base branch after recording the start time"
else
    fail "auto_push should push the base branch" "$START_OUT"
fi
# No remote exists, so the push fails - start must survive that.
if echo "$START_OUT" | grep -q "Started ticket"; then
    pass "a failed push does not fail start"
else
    fail "start should survive a failed push" "$START_OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "8. Legacy flat tickets record the start time the same way"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo7)
cd "$REPO"
LEGACY="250101-120000-legacy-flat"
cat > "tickets/${LEGACY}.md" <<'EOF'
---
priority: 2
description: "legacy flat ticket"
created_at: "2025-01-01T12:00:00Z"
started_at: null
closed_at: null
---

# Legacy

Body.
EOF
git add tickets && git commit -q -m "Add legacy ticket"

timeout 10 ./ticket.sh start "$LEGACY" >/dev/null 2>&1

LEGACY_STAMP=$(git show "main:tickets/${LEGACY}.md" 2>/dev/null | grep "^started_at:" || echo "MISSING")
if [[ "$LEGACY_STAMP" == "MISSING" ]] || echo "$LEGACY_STAMP" | grep -q "null"; then
    fail "legacy flat tickets should record started_at on the base branch" "got: $LEGACY_STAMP"
else
    pass "legacy flat tickets record started_at on the base branch"
fi

# ---------------------------------------------------------------------------
echo
echo "9. advance_branch_ff / drop_untracked_if_unchanged behave as documented"
# ---------------------------------------------------------------------------
source "${REPO_ROOT}/lib/utils.sh"

UNIT="${TEST_DIR}/unit"
rm -rf "$UNIT"; mkdir -p "$UNIT"; cd "$UNIT"
git init -q -b main
git config user.name "Test"
git config user.email "test@test.com"
echo base > base.txt
git add base.txt && git commit -q -m "Initial"
git worktree add -q -b feature wt main
echo work > wt/work.txt
git -C wt add work.txt && git -C wt commit -q -m "Work"

# main is checked out here, so this must go through merge --ff-only.
if advance_branch_ff "$UNIT" main feature && [[ "$(git rev-parse main)" == "$(git rev-parse feature)" ]]; then
    pass "advance_branch_ff merges into a branch that is checked out"
else
    fail "advance_branch_ff failed to merge into the checked-out base"
fi

# Now put main out of reach of a fast-forward and confirm it declines.
git -C wt commit -q --allow-empty -m "Ahead"
git commit -q --allow-empty -m "Diverged"
if advance_branch_ff "$UNIT" main feature; then
    fail "advance_branch_ff should refuse a non-fast-forward"
else
    pass "advance_branch_ff refuses a non-fast-forward"
fi

# A branch nobody holds goes through fetch instead.
UNIT2="${TEST_DIR}/unit2"
rm -rf "$UNIT2"; mkdir -p "$UNIT2"; cd "$UNIT2"
git init -q -b main
git config user.name "Test"
git config user.email "test@test.com"
echo base > base.txt
git add base.txt && git commit -q -m "Initial"
git branch feature
git checkout -q -b elsewhere
git worktree add -q wt feature
echo work > wt/work.txt
git -C wt add work.txt && git -C wt commit -q -m "Work"

if advance_branch_ff "$UNIT2" main feature && [[ "$(git rev-parse main)" == "$(git rev-parse feature)" ]]; then
    pass "advance_branch_ff fetches into a branch nobody has checked out"
else
    fail "advance_branch_ff failed to fetch into an unheld branch"
fi

# drop_untracked_if_unchanged: matching hash goes, differing hash stays.
UNIT3="${TEST_DIR}/unit3"
rm -rf "$UNIT3"; mkdir -p "$UNIT3"; cd "$UNIT3"
git init -q -b main
git config user.name "Test"
git config user.email "test@test.com"
echo base > base.txt
git add base.txt && git commit -q -m "Initial"

echo "untracked" > loose.txt
LOOSE_HASH=$(git hash-object loose.txt)
drop_untracked_if_unchanged "$UNIT3" loose.txt "$LOOSE_HASH"
if [[ ! -f loose.txt ]]; then
    pass "an untracked file matching its snapshot is removed"
else
    fail "the matching untracked file should have been removed"
fi

echo "untracked" > loose2.txt
STALE_HASH=$(git hash-object loose2.txt)
echo "edited after the snapshot" >> loose2.txt
drop_untracked_if_unchanged "$UNIT3" loose2.txt "$STALE_HASH"
if [[ -f loose2.txt ]]; then
    pass "an untracked file that changed since the snapshot is left alone"
else
    fail "the edited untracked file should have been kept"
fi

echo "tracked" > kept.txt
git add kept.txt && git commit -q -m "Track it"
drop_untracked_if_unchanged "$UNIT3" kept.txt "$(git hash-object kept.txt)"
if [[ -f kept.txt ]]; then
    pass "tracked files are left for git to update"
else
    fail "a tracked file should never be removed"
fi

# ---------------------------------------------------------------------------
echo
echo "=== start base-branch sync Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "$REPO_ROOT"
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
