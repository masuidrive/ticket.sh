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

# The point of the fallback: a skipped fast-forward must not make work in
# progress read as untouched.
git checkout -q -- "tickets/${TICKET}/ticket.md" 2>/dev/null || true
LIST_OUT=$(timeout 10 ./ticket.sh list 2>&1)
if echo "$LIST_OUT" | grep -q "status: doing"; then
    pass "list reports doing even though the fast-forward was skipped"
else
    fail "list should read the feature branch when the base branch has no stamp" "$LIST_OUT"
fi

if echo "$LIST_OUT" | grep -q "started_at_only_on: feature/${TICKET}"; then
    pass "list marks which branch the start time came from"
else
    fail "list should mark a start time that only exists on the feature branch" "$LIST_OUT"
fi

# The base branch really is missing it - that is what the mark is for.
if started_at_on main "$TICKET" | grep -q "null"; then
    pass "the base branch's ticket file is indeed still null"
else
    fail "expected the base branch to lack the start time in this scenario"
fi

if timeout 10 ./ticket.sh list --status doing 2>&1 | grep -q "$TICKET"; then
    pass "--status doing includes a ticket recovered from its feature branch"
else
    fail "--status doing should include the recovered ticket"
fi

# An untouched ticket must stay todo: the fallback only fires when a branch
# exists and carries a stamp.
UNTOUCHED=$(make_ticket never-started)
git add tickets && git commit -q -m "Add untouched ticket"
LIST_OUT=$(timeout 10 ./ticket.sh list 2>&1)
if echo "$LIST_OUT" | grep -A1 "ticket_path: tickets/${UNTOUCHED}/ticket.md" >/dev/null &&
   echo "$LIST_OUT" | grep -B2 "ticket_path: tickets/${UNTOUCHED}/ticket.md" | grep -q "status: todo"; then
    pass "a ticket that was never started stays todo"
else
    fail "an unstarted ticket should still read as todo" "$LIST_OUT"
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
echo "7. start never pushes, whatever auto_push says"
# ---------------------------------------------------------------------------
# start declares that work is beginning; it is not a request to publish the base
# branch. Pushing there would carry along whatever unpushed commits happen to be
# sitting on it - someone else's, in a repo where several worktrees share a base.
REPO=$(make_repo repo5)
cd "$REPO"
sed_i 's/^auto_push: false/auto_push: true/' .ticket-config.yaml
git add . && git commit -q -m "Enable auto_push"
TICKET=$(make_ticket push-choice)
git add tickets && git commit -q -m "Add ticket"

START_OUT=$(timeout 10 ./ticket.sh start "$TICKET" 2>&1)
if echo "$START_OUT" | grep -q "push origin"; then
    fail "start must not push even when auto_push is enabled" "$START_OUT"
else
    pass "start does not push the base branch when auto_push is enabled"
fi

if echo "$START_OUT" | grep -q "Recorded start time"; then
    pass "the start time still reaches the base branch without pushing"
else
    fail "start should still record the start time" "$START_OUT"
fi

# --no-push was removed along with the push itself. An older invocation still
# carrying the flag must keep working - unknown flags are ignored.
REPO=$(make_repo repo6)
cd "$REPO"
TICKET=$(make_ticket stale-flag)
git add tickets && git commit -q -m "Add ticket"

if timeout 10 ./ticket.sh start --no-push "$TICKET" >/dev/null 2>&1; then
    pass "a leftover --no-push is harmlessly ignored"
else
    fail "start should still succeed when handed a leftover --no-push"
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

# The feature-branch fallback has to resolve the flat layout's name too.
REPO=$(make_repo repo8)
cd "$REPO"
LEGACY2="250101-130000-legacy-blocked"
cat > "tickets/${LEGACY2}.md" <<'EOF'
---
priority: 2
description: "legacy flat ticket, blocked fast-forward"
created_at: "2025-01-01T13:00:00Z"
started_at: null
closed_at: null
---

# Legacy

Body.
EOF
git add tickets && git commit -q -m "Add legacy ticket"
echo "# edited in the main repo" >> "tickets/${LEGACY2}.md"
timeout 20 ./ticket.sh start --worktree "$LEGACY2" >/dev/null 2>&1
git checkout -q -- "tickets/${LEGACY2}.md" 2>/dev/null || true

LIST_OUT=$(timeout 10 ./ticket.sh list 2>&1)
if echo "$LIST_OUT" | grep -q "started_at_only_on: feature/${LEGACY2}"; then
    pass "the feature-branch fallback works for legacy flat tickets"
else
    fail "legacy flat tickets should also be recovered from their branch" "$LIST_OUT"
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
echo "10. The base branch is held back when the resumed branch has work of its own (issue #17)"
# ---------------------------------------------------------------------------
# The fast-forward is safe where the feature branch is the base plus the one
# stamp commit, which is the shape of every branch `start` creates itself. A
# branch `start` only resumes need not be that shape - a bot can have cut it and
# committed before anyone ran `start`, an interrupted `start` leaves the branch
# behind with started_at still null, and the already-started error tells people
# to reset started_at by hand. Fast-forwarding there carried the branch's own
# commits into the base branch: a merge nobody asked `start` for, which broke
# close's one-commit-per-ticket history and survived `cancel`.
REPO=$(make_repo repo10)
cd "$REPO"
TICKET=$(make_ticket held-back)
git add tickets && git commit -q -m "Add ticket"
MAIN_BEFORE=$(git rev-parse main)

# The branch exists and carries work, and the ticket was never started.
git checkout -q -b "feature/${TICKET}"
echo "half-finished" > work.txt
git add work.txt && git commit -q -m "WIP: not reviewed"
git checkout -q main

START_OUT=$(timeout 10 ./ticket.sh start "$TICKET" 2>&1)

if [[ "$(git rev-parse main)" == "$MAIN_BEFORE" ]]; then
    pass "the base branch is left where it was"
else
    fail "the base branch was advanced" "$(git log --oneline main | head -3)"
fi
if ! git cat-file -e "main:work.txt" 2>/dev/null; then
    pass "and the branch's work did not reach it"
else
    fail "unreviewed work was carried onto the base branch" "$START_OUT"
fi
if echo "$START_OUT" | grep -q "'main' was left where it is"; then
    pass "and start says so"
else
    fail "the run did not report holding the base branch back" "$START_OUT"
fi
if echo "$START_OUT" | grep -q "1 commit(s) ahead of it and carries changes"; then
    pass "and says why, with the count"
else
    fail "the reason is not given" "$START_OUT"
fi
# The note record_start_on_base prints for itself names a different reason - no
# copy of the ticket on the base branch - which is false here.
if ! echo "$START_OUT" | grep -q "has no copy of this ticket"; then
    pass "and does not also claim the base branch lacks the ticket"
else
    fail "two notes, one of them untrue" "$START_OUT"
fi
if started_at_on "feature/${TICKET}" "$TICKET" | grep -q "^started_at: 2"; then
    pass "the start time is still committed on the branch"
else
    fail "the start time was not recorded" "$(started_at_on "feature/${TICKET}" "$TICKET")"
fi
LIST_OUT=$(timeout 10 ./ticket.sh list 2>&1)
if echo "$LIST_OUT" | grep -q "status: doing"; then
    pass "and list still reports the ticket as doing"
else
    fail "the ticket no longer reads as doing" "$LIST_OUT"
fi

# close is what brings the work over, as one commit for the whole ticket.
git checkout -q "feature/${TICKET}"
echo "done" >> work.txt
git add work.txt && git commit -q -m "Finish"
COUNT_BEFORE=$(git rev-list --count main)
timeout 15 ./ticket.sh close >/dev/null 2>&1
COUNT_AFTER=$(git rev-list --count main)
if [[ $((COUNT_AFTER - COUNT_BEFORE)) -eq 1 ]]; then
    pass "close leaves exactly one new commit on the base branch"
else
    fail "close added $((COUNT_AFTER - COUNT_BEFORE)) commits" "$(git log --oneline main | head -5)"
fi
if git cat-file -e "main:work.txt" 2>/dev/null; then
    pass "and the work is there once it is closed"
else
    fail "close did not bring the work over"
fi

# ---------------------------------------------------------------------------
echo
echo "11. A resumed branch with nothing of its own still advances the base"
# ---------------------------------------------------------------------------
# The hold is specifically about commits that are not the stamp. Resuming a
# branch that is level with the base must behave as it always did, or the fix
# would have turned the fast-forward off for everybody.
REPO=$(make_repo repo11)
cd "$REPO"
TICKET=$(make_ticket level-branch)
git add tickets && git commit -q -m "Add ticket"
git branch "feature/${TICKET}" main
MAIN_BEFORE=$(git rev-parse main)

START_OUT=$(timeout 10 ./ticket.sh start "$TICKET" 2>&1)

if [[ "$(git rev-parse main)" != "$MAIN_BEFORE" ]]; then
    pass "the base branch is advanced as before"
else
    fail "the base branch stopped being advanced" "$START_OUT"
fi
if git log -1 --format=%s main | grep -q "^\[start\]"; then
    pass "and sits on the start commit"
else
    fail "unexpected subject on the base branch" "$(git log -1 --format=%s main)"
fi
if ! echo "$START_OUT" | grep -q "was left where it is"; then
    pass "and nothing is said about holding it back"
else
    fail "the hold note fired on a level branch" "$START_OUT"
fi

# The hold asks what the branch touches, not how far ahead it is. A branch that
# is ahead only by the ticket's own bookkeeping - a bot adopting a backlog
# ticket writes `branch:` into it and commits, and nothing else - must still
# advance the base branch, or holding back would cost the thing the
# fast-forward exists for.
REPO=$(make_repo repo11b)
cd "$REPO"
TICKET=$(make_ticket own-files-only)
git add tickets && git commit -q -m "Add ticket"
git checkout -q -b "feature/${TICKET}"
printf '\nAdopted.\n' >> "tickets/${TICKET}/note.md"
git add -A && git commit -q -m "Adopt the ticket on the branch"
git checkout -q main
MAIN_BEFORE=$(git rev-parse main)

START_OUT=$(timeout 10 ./ticket.sh start "$TICKET" 2>&1)

if [[ "$(git rev-parse main)" != "$MAIN_BEFORE" ]]; then
    pass "a branch ahead only by the ticket's own files still advances the base"
else
    fail "the base branch was held back over the ticket's own bookkeeping" "$START_OUT"
fi
if [[ -n "$(started_at_on main "$TICKET")" ]] && ! started_at_on main "$TICKET" | grep -q null; then
    pass "and the start time reaches the base branch"
else
    fail "the start time did not reach the base branch" "$(started_at_on main "$TICKET")"
fi
if ! echo "$START_OUT" | grep -q "was left where it is"; then
    pass "and no hold is reported"
else
    fail "the hold note fired on ticket-only commits" "$START_OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "12. Worktree mode holds the base branch back the same way"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo12)
cd "$REPO"
echo 'worktree_mode: true' >> .ticket-config.yaml
git add . && git commit -q -m "Enable worktree_mode"
TICKET=$(make_ticket held-back-wt)
git add tickets && git commit -q -m "Add ticket"
git checkout -q -b "feature/${TICKET}"
echo "half-finished" > work.txt
git add work.txt && git commit -q -m "WIP: not reviewed"
git checkout -q main
MAIN_BEFORE=$(git rev-parse main)

START_OUT=$(timeout 15 ./ticket.sh start "$TICKET" 2>&1)
WT=$(echo "$START_OUT" | grep "^WORKTREE:" | head -1 | cut -d: -f2-)

if [[ -n "$WT" ]] && [[ -d "$WT" ]]; then
    pass "the worktree is created"
else
    fail "no worktree" "$START_OUT"
fi
if [[ "$(git rev-parse main)" == "$MAIN_BEFORE" ]] && ! git cat-file -e "main:work.txt" 2>/dev/null; then
    pass "and the base branch is still where it was"
else
    fail "the base branch moved in worktree mode" "$(git log --oneline main | head -3)"
fi
if echo "$START_OUT" | grep -q "was left where it is"; then
    pass "and the reason is reported"
else
    fail "no note in worktree mode" "$START_OUT"
fi
if started_at_on "feature/${TICKET}" "$TICKET" | grep -q "^started_at: 2"; then
    pass "and the start time is committed on the branch"
else
    fail "the start time was not recorded" "$(started_at_on "feature/${TICKET}" "$TICKET")"
fi
cd "$REPO"
git worktree remove "$WT" --force 2>/dev/null || true
git worktree prune 2>/dev/null || true

# ---------------------------------------------------------------------------
echo
echo "13. cancel leaves no abandoned work on the base branch"
# ---------------------------------------------------------------------------
# cancel is documented as stopping without merging. Where start had already
# fast-forwarded the base branch onto the work, there was nothing left for
# cancel to decline: the work stayed on the base branch for good.
REPO=$(make_repo repo13)
cd "$REPO"
TICKET=$(make_ticket canceled-work)
git add tickets && git commit -q -m "Add ticket"
git checkout -q -b "feature/${TICKET}"
echo "abandoned" > work.txt
git add work.txt && git commit -q -m "WIP: will be abandoned"
git checkout -q main

timeout 10 ./ticket.sh start "$TICKET" >/dev/null 2>&1
timeout 10 ./ticket.sh cancel --force >/dev/null 2>&1

if ! git cat-file -e "main:work.txt" 2>/dev/null; then
    pass "the abandoned work is not on the base branch"
else
    fail "cancel left the work on the base branch" "$(git log --oneline main | head -4)"
fi
if [[ -d "tickets/done" ]] && ls tickets/done | grep -q "CANCELED"; then
    pass "and the ticket is filed as canceled"
else
    fail "the ticket was not canceled" "$(ls tickets tickets/done 2>&1)"
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
