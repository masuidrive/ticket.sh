#!/usr/bin/env bash

# Tests for `reopen`, and for the hole it closes in `close --no-merge` (issue #22).
#
# `close --no-merge` is also used before a PR is merged, on the ticket's own
# branch, because the move into done/ has to ride in on the PR rather than
# follow it. So a ticket can sit in done/ while the work is still being argued
# about - and there was no way back: `start` only looks at the open location.
#
# The second half is the one worth testing hardest. Re-running
# `close --no-merge` on a ticket already in done/ returned 0 and ran nothing,
# which meant the gates - checklist, append-only, pre_close_command - could be
# walked around by finalizing first and fixing after, silently. The fix refuses
# that only where the gates would have applied, and decides "has the branch
# moved" from the commit that *added* the done/ path. Both halves of that
# sentence are a line someone could simplify away: taking the newest commit
# that touched the ticket instead would pass for every branch that keeps notes
# (section 6.3), and refusing on the base branch too would break the
# idempotence a retrying bot relies on (section 6.4).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== reopen Test Suite ==="
echo

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/tmp/test-reopen-$(date +%s)"
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

# Build a repo with one started ticket and leave the shell in it.
# $2 is an optional config line, $3 an optional pre_close check script body.
# Sets REPO, TICKET, BRANCH.
# Usage: setup <dir-name> [<config-line>] [<check-script-body>]
setup() {
    local name="$1"
    local config_line="${2:-}"
    local script_body="${3:-}"
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

    if [[ -n "$script_body" ]]; then
        printf '%s\n' "$script_body" > check.sh
        chmod +x check.sh
    fi
    # The check below is steered by a flag file. Keep it out of Git, or removing
    # it leaves the tree dirty and a later close refuses for the wrong reason.
    printf 'ok.flag\n' >> .gitignore
    if [[ -n "$config_line" ]]; then
        printf '\n%s\n' "$config_line" >> .ticket-config.yaml
    fi
    git add . && git commit -q -m "Init ticket system"

    timeout 5 ./ticket.sh new reopen-me >/dev/null 2>&1
    TICKET=$(safe_get_ticket_name "*reopen-me*")
    git add tickets && git commit -q -m "Add ticket"
    timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1
    BRANCH="feature/${TICKET}"
    REPO="$dir"
}

# A work commit, then finalize the ticket into done/ from the feature branch -
# the state the bot leaves behind when it readies the PR.
finalize() {
    echo "work" >> work.txt
    git add work.txt
    git commit -q -m "do the work"
    timeout 20 ./ticket.sh close --no-merge "$TICKET" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
echo "1. reopen brings a finalized ticket back into the working set"
setup basic
cd "$REPO"
finalize
if [[ -f "tickets/done/${TICKET}/ticket.md" ]]; then
    pass "the fixture really finalized the ticket into done/"
else
    fail "close --no-merge did not reach done/" "$(ls -R tickets)"
fi

BEFORE_COUNT=$(git rev-list --count HEAD)
OUT=$(timeout 20 ./ticket.sh reopen "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "reopen exits 0 on the ticket's own branch"
else
    fail "reopen failed" "$OUT"
fi
if [[ -f "tickets/${TICKET}/ticket.md" ]] && [[ -f "tickets/${TICKET}/note.md" ]]; then
    pass "ticket.md and note.md are back in the working location"
else
    fail "the ticket did not come back" "$(ls -R tickets)"
fi
if [[ ! -e "tickets/done/${TICKET}" ]]; then
    pass "nothing is left in done/"
else
    fail "the ticket is still in done/" "$(ls -R tickets)"
fi
if grep -q "^closed_at: null" "tickets/${TICKET}/ticket.md"; then
    pass "closed_at is back to null"
else
    fail "closed_at was not cleared" "$(head -10 "tickets/${TICKET}/ticket.md")"
fi
# A reopened ticket was still started, so the start time is not ours to erase.
if grep -q "^started_at: 20" "tickets/${TICKET}/ticket.md"; then
    pass "started_at is left alone"
else
    fail "started_at was touched" "$(head -10 "tickets/${TICKET}/ticket.md")"
fi
AFTER_COUNT=$(git rev-list --count HEAD)
if [[ $((AFTER_COUNT - BEFORE_COUNT)) -eq 1 ]]; then
    pass "exactly one commit was added"
else
    fail "expected 1 commit, got $((AFTER_COUNT - BEFORE_COUNT))" "$(git log --oneline -3)"
fi
if [[ "$(git log -1 --format=%s)" == "[reopen] ${BRANCH}" ]]; then
    pass "the commit is named [reopen] <branch>"
else
    fail "unexpected commit subject" "$(git log -1 --format=%s)"
fi
# The move must be a move in Git's eyes, so the ticket's history survives it.
if git show --name-status --format= HEAD | grep -q "^R"; then
    pass "the commit records a rename, not a delete plus an add"
else
    fail "the move was not recorded as a rename" "$(git show --name-status --format= HEAD)"
fi
if [[ -z "$(git status --porcelain)" ]]; then
    pass "the tree is clean afterwards (nothing left staged)"
else
    fail "the tree is dirty after reopen" "$(git status --porcelain)"
fi
if [[ -L current-ticket ]] && [[ "$(readlink current-ticket)" == "tickets/${TICKET}" ]]; then
    pass "current-ticket/ points at the ticket again"
else
    fail "the symlink was not restored" "$(ls -l current-ticket 2>&1)"
fi
if echo "$OUT" | grep -q "Reopened ticket: ${TICKET}" && echo "$OUT" | grep -q "^Active ticket paths:"; then
    pass "the output says what happened and lists the paths"
else
    fail "output is missing the summary or the paths block" "$OUT"
fi
LIST=$(timeout 10 ./ticket.sh list 2>&1)
if echo "$LIST" | grep -q "$TICKET"; then
    pass "list shows the ticket again"
else
    fail "list does not show the reopened ticket" "$LIST"
fi

# ---------------------------------------------------------------------------
echo
echo "2. work already in the tree is not swept into the reopen commit"
# Being asked for changes is exactly the moment someone has started making
# them, so the commit names the ticket's paths rather than taking everything.
setup keeps-edits
cd "$REPO"
finalize
echo "half-done edit" >> work.txt
echo "scratch" > scratch.txt
OUT=$(timeout 20 ./ticket.sh reopen "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "reopen works with a dirty tree"
else
    fail "reopen refused a dirty tree" "$OUT"
fi
if git status --porcelain | grep -q "work.txt" && git status --porcelain | grep -q "scratch.txt"; then
    pass "the edit and the untracked file are still uncommitted"
else
    fail "reopen committed someone else's work" "$(git status --porcelain)$(git show --stat --format= HEAD)"
fi
if ! git show --name-only --format= HEAD | grep -q "work.txt"; then
    pass "the reopen commit holds only the ticket's files"
else
    fail "work.txt rode in on the reopen commit" "$(git show --name-only --format= HEAD)"
fi

# ---------------------------------------------------------------------------
echo
echo "3. reopen refuses where reopening would mean something else"
setup refusals
cd "$REPO"
finalize
git checkout -q main
git merge -q --ff-only "$BRANCH" 2>/dev/null
HEAD_BEFORE=$(git rev-parse HEAD)
OUT=$(timeout 20 ./ticket.sh reopen "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "Refusing to reopen on the base branch"; then
    pass "on the base branch it refuses"
else
    fail "reopen on the base branch should refuse" "rc=$RC $OUT"
fi
if [[ -f "tickets/done/${TICKET}/ticket.md" ]] && [[ "$(git rev-parse HEAD)" == "$HEAD_BEFORE" ]]; then
    pass "the refusal moved nothing and committed nothing"
else
    fail "the refusal still changed something" "$(git log --oneline -2)"
fi
if echo "$OUT" | grep -q "new <slug>"; then
    pass "it points at a new ticket for the follow-up work"
else
    fail "the refusal does not say what to do instead" "$OUT"
fi

# A branch that is neither the base nor the ticket's own: the commits a second
# close would have to judge are not here.
git checkout -q "$BRANCH"
git checkout -q -b side
OUT=$(timeout 20 ./ticket.sh reopen "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "Not on the ticket's branch"; then
    pass "on an unrelated branch it refuses"
else
    fail "reopen should refuse off the ticket's branch" "rc=$RC $OUT"
fi
if echo "$OUT" | grep -q "its branch:   ${BRANCH}" && echo "$OUT" | grep -q "you are on:   side"; then
    pass "the refusal names both branches"
else
    fail "the refusal does not say which branch is which" "$OUT"
fi

# Already active: reopen has nothing to bring back.
git checkout -q "$BRANCH"
timeout 20 ./ticket.sh reopen "$TICKET" >/dev/null 2>&1
OUT=$(timeout 20 ./ticket.sh reopen "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "Ticket is not in done/"; then
    pass "a ticket already in the working set is refused"
else
    fail "reopening an active ticket should refuse" "rc=$RC $OUT"
fi

OUT=$(timeout 20 ./ticket.sh reopen 240101-000000-nope 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "Ticket not found"; then
    pass "a name that matches nothing is Ticket not found"
else
    fail "unknown ticket should be refused" "rc=$RC $OUT"
fi

OUT=$(timeout 20 ./ticket.sh reopen 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "<ticket-name> is required"; then
    pass "a missing name is refused with the usage line"
else
    fail "reopen with no argument should refuse" "rc=$RC $OUT"
fi

# A flag that is nearly right is a mistake, not a preference.
OUT=$(timeout 20 ./ticket.sh reopen --dry-ru "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "Unknown option: --dry-ru"; then
    pass "a mistyped flag is rejected rather than ignored"
else
    fail "a typo in a flag got through" "rc=$RC $OUT"
fi

# A cancelled ticket is in done/ too, and cancel said the work is not happening.
setup cancelled
cd "$REPO"
finalize
sed_i 's/^canceled_at: null.*/canceled_at: 2026-10-16T10:00:00Z/' "tickets/done/${TICKET}/ticket.md"
git add tickets && git commit -q -m "mark cancelled"
OUT=$(timeout 20 ./ticket.sh reopen "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "was cancelled, not closed"; then
    pass "a cancelled ticket is not reopened"
else
    fail "a cancelled ticket should be refused" "rc=$RC $OUT"
fi

# Both locations occupied: moving one onto the other would lose a copy.
setup taken
cd "$REPO"
finalize
mkdir -p "tickets/${TICKET}"
echo "other copy" > "tickets/${TICKET}/ticket.md"
OUT=$(timeout 20 ./ticket.sh reopen "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "working location is already taken"; then
    pass "a ticket in both places is refused, not overwritten"
else
    fail "reopen should refuse when the destination exists" "rc=$RC $OUT"
fi
if grep -q "other copy" "tickets/${TICKET}/ticket.md" && [[ -f "tickets/done/${TICKET}/ticket.md" ]]; then
    pass "both copies are untouched"
else
    fail "a copy was clobbered" "$(ls -R tickets)"
fi

# ---------------------------------------------------------------------------
echo
echo "4. --dry-run checks and changes nothing"
setup dry
cd "$REPO"
finalize
HEAD_BEFORE=$(git rev-parse HEAD)
OUT=$(timeout 20 ./ticket.sh reopen --dry-run "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "Dry-run: all preflight checks passed"; then
    pass "--dry-run passes and says so"
else
    fail "--dry-run did not pass" "rc=$RC $OUT"
fi
if [[ -f "tickets/done/${TICKET}/ticket.md" ]] && [[ ! -e "tickets/${TICKET}" ]]; then
    pass "--dry-run moved nothing"
else
    fail "--dry-run moved the ticket" "$(ls -R tickets)"
fi
if [[ "$(git rev-parse HEAD)" == "$HEAD_BEFORE" ]] && [[ -z "$(git status --porcelain)" ]]; then
    pass "--dry-run committed nothing and left the tree clean"
else
    fail "--dry-run changed the repository" "$(git log --oneline -2)"
fi
# And it refuses under --dry-run too, where it would refuse for real. The merge
# is what carries the finalized state onto main: the move into done/ happened on
# the feature branch, so without it main still holds the ticket as open.
git checkout -q main
git merge -q --ff-only "$BRANCH"
OUT=$(timeout 20 ./ticket.sh reopen --dry-run "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "Refusing to reopen on the base branch"; then
    pass "--dry-run reports the refusal rather than a pass"
else
    fail "--dry-run passed where the real run would refuse" "rc=$RC $OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "5. after a reopen, close's gates are live again"
# This is the point of the whole exercise: the project's own check has to see
# the work as it stands now, not as it stood when the ticket was finalized.
setup gates-again 'pre_close_command: "bash check.sh"' '#!/usr/bin/env bash
if [ -f ok.flag ]; then
    echo "project check: the reviewer signed off"
    exit 0
fi
echo "project check: the reviewer has not signed off"
exit 1'
cd "$REPO"
touch ok.flag
finalize
if [[ -f "tickets/done/${TICKET}/ticket.md" ]]; then
    pass "the first close passed its own check and finalized"
else
    fail "the fixture did not finalize" "$(ls -R tickets)"
fi
timeout 20 ./ticket.sh reopen "$TICKET" >/dev/null 2>&1
rm -f ok.flag
echo "the fix" >> work.txt
git add work.txt
git commit -q -m "fix what the review asked for"
OUT=$(timeout 20 ./ticket.sh close --no-merge "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "the reviewer has not signed off"; then
    pass "the project's check runs again and stops the second close"
else
    fail "the gate did not run after a reopen" "rc=$RC $OUT"
fi
if [[ ! -e "tickets/done/${TICKET}" ]] && [[ -f "tickets/${TICKET}/ticket.md" ]]; then
    pass "the refused close left the ticket where reopen put it"
else
    fail "the refused close moved the ticket anyway" "$(ls -R tickets)"
fi
touch ok.flag
OUT=$(timeout 20 ./ticket.sh close --no-merge "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && [[ -f "tickets/done/${TICKET}/ticket.md" ]]; then
    pass "with the check passing, the ticket finalizes again"
else
    fail "the second close did not finalize" "rc=$RC $OUT"
fi
if grep -q "^closed_at: 20" "tickets/done/${TICKET}/ticket.md"; then
    pass "closed_at is stamped again"
else
    fail "closed_at was not re-stamped" "$(head -10 "tickets/done/${TICKET}/ticket.md")"
fi

# ---------------------------------------------------------------------------
echo
echo "6. close --no-merge on a ticket that is already in done/"
setup finalized-twice
cd "$REPO"
finalize

# 6.1 nothing has happened since: the retry stays a no-op, as it always was.
OUT=$(timeout 20 ./ticket.sh close --no-merge "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "Ticket already finalized"; then
    pass "an unchanged branch still gets the idempotent 0"
else
    fail "a plain retry should be a no-op" "rc=$RC $OUT"
fi

# 6.2 the branch has moved: the gates never saw this, so it is refused.
echo "more work, unreviewed" >> work.txt
git add work.txt
git commit -q -m "more work"
OUT=$(timeout 20 ./ticket.sh close --no-merge "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "already finalized, and the branch has moved since"; then
    pass "new commits after the finalize are refused"
else
    fail "close reported success for a branch the gates never saw" "rc=$RC $OUT"
fi
if echo "$OUT" | grep -q "new commits:   1" && echo "$OUT" | grep -q "reopen ${TICKET}"; then
    pass "the refusal counts the commits and names reopen"
else
    fail "the refusal does not say what happened or what to do" "$OUT"
fi
OUT=$(timeout 20 ./ticket.sh close --no-merge --dry-run "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 1 ]]; then
    pass "--dry-run refuses it too, rather than reporting a pass"
else
    fail "--dry-run claimed a pass" "rc=$RC $OUT"
fi

# 6.3 the finalize point is the commit that ADDED the done/ path.
# A fix that also writes the ticket's note - the normal case when notes are
# kept as the work goes on - must not become the new reference point, or the
# refusal above would never fire for anyone who keeps notes.
setup notes-touched
cd "$REPO"
finalize
echo "- reviewed again" >> "tickets/done/${TICKET}/note.md"
echo "the fix" >> work.txt
git add -A
git commit -q -m "fix, and note why"
OUT=$(timeout 20 ./ticket.sh close --no-merge "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 1 ]] && echo "$OUT" | grep -q "the branch has moved since"; then
    pass "a commit that touches the ticket is not mistaken for the finalize"
else
    fail "the newest commit touching the ticket was read as the finalize point" "rc=$RC $OUT"
fi

# 6.4 on the base branch the idempotent 0 stands, however far main has moved.
# There the merge has already happened, the gates are skipped by design, and
# refusing would strand a retrying bot with no action that helps.
setup finalized-on-base
cd "$REPO"
finalize
git checkout -q main
git merge -q --ff-only "$BRANCH"
echo "someone else's ticket" > other.txt
git add other.txt
git commit -q -m "unrelated work on main"
OUT=$(timeout 20 ./ticket.sh close --no-merge "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "Ticket already finalized"; then
    pass "on the base branch it is still a no-op after later commits"
else
    fail "the base-branch retry should stay a no-op" "rc=$RC $OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "7. legacy flat tickets come back too"
setup legacy
cd "$REPO"
git checkout -q main
LEG="240101-000000-legacy-flat"
cat > "tickets/${LEG}.md" << 'LEGACY'
---
priority: 2
base_branch: default
description: "legacy flat ticket"
created_at: "2024-01-01T00:00:00Z"
started_at: null
closed_at: null
canceled_at: null
---

# Legacy flat ticket

Legacy body.
LEGACY
printf 'Legacy note.\n' > "tickets/${LEG}-note.md"
git add tickets && git commit -q -m "add legacy flat ticket"
timeout 20 ./ticket.sh start "$LEG" >/dev/null 2>&1
echo "legacy work" > legacy.txt
git add legacy.txt
git commit -q -m "legacy work"
timeout 20 ./ticket.sh close --no-merge "$LEG" >/dev/null 2>&1
if [[ -f "tickets/done/${LEG}.md" ]] && [[ -f "tickets/done/${LEG}-note.md" ]]; then
    pass "the legacy fixture finalized into done/"
else
    fail "the legacy ticket did not finalize" "$(ls -R tickets)"
fi
OUT=$(timeout 20 ./ticket.sh reopen "$LEG" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && [[ -f "tickets/${LEG}.md" ]]; then
    pass "reopen brings the flat ticket back"
else
    fail "the flat ticket did not come back" "rc=$RC $OUT"
fi
if [[ -f "tickets/${LEG}-note.md" ]] && [[ ! -e "tickets/done/${LEG}-note.md" ]]; then
    pass "its sibling note file comes with it"
else
    fail "the note file was left in done/" "$(ls -R tickets)"
fi
if grep -q "^closed_at: null" "tickets/${LEG}.md"; then
    pass "closed_at is cleared in the flat ticket"
else
    fail "closed_at was not cleared" "$(head -10 "tickets/${LEG}.md")"
fi
if [[ "$(readlink current-ticket.md)" == "tickets/${LEG}.md" ]] && [[ ! -e current-ticket ]]; then
    pass "the compat symlink is restored and no directory symlink is made"
else
    fail "the legacy symlinks are wrong" "$(ls -l current-ticket.md current-ticket 2>&1)"
fi
if echo "$OUT" | grep -q "layout:       legacy"; then
    pass "the paths block reports the legacy layout"
else
    fail "the paths block does not say legacy" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "=== reopen Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "$REPO_ROOT"
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
