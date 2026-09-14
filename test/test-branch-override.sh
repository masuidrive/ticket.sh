#!/usr/bin/env bash

# Tests for the ticket's `branch:` frontmatter override and `new --branch`
# (issue #8).
#
# The feature branch name used to be {branch_prefix}<ticket-name> and nothing
# else. A branch created by something outside ticket.sh - a CI bot that checks
# out agent/issue-12 from the issue number before a ticket exists - could not be
# expressed, so every command had to be worked around: `check` reported a
# permanent mismatch, `close` was limited to --no-merge, and `start` was
# unusable. Letting the ticket say which branch it lives on is what puts those
# commands back in play, so the sections below walk one such ticket through the
# whole lifecycle rather than testing the field in isolation.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== branch override Test Suite ==="
echo

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/tmp/test-branch-override-$(date +%s)"
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

# Build a fresh repo with the ticket system initialized. No remote, so pushing
# is turned off.
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

# ---------------------------------------------------------------------------
echo "1. new --branch writes the field"
REPO=$(make_repo newbranch)
cd "$REPO"
OUT=$(timeout 5 ./ticket.sh new botwork --branch agent/issue-12 2>&1)
TICKET=$(safe_get_ticket_name "*botwork*")
BODY="tickets/${TICKET}/ticket.md"

if grep -q "^branch: agent/issue-12$" "$BODY" 2>/dev/null; then
    pass "the frontmatter carries branch: agent/issue-12"
else
    fail "branch: not written" "$(sed -n '1,10p' "$BODY" 2>/dev/null)"
fi
if echo "$OUT" | grep -q "branch: agent/issue-12"; then
    pass "new says which branch the ticket will use"
else
    fail "new did not mention the branch" "$OUT"
fi
# The field sits inside the frontmatter fence, not after it - a `branch:` in the
# body would parse as nothing and the ticket would quietly revert to the prefix.
FENCES=$(awk '/^---[[:space:]]*$/ { n++ } /^branch:/ && n == 1 { found = 1 } END { print found + 0 }' "$BODY")
if [[ "$FENCES" == "1" ]]; then
    pass "the field is inside the frontmatter"
else
    fail "branch: landed outside the frontmatter" "$(sed -n '1,12p' "$BODY")"
fi

# ---------------------------------------------------------------------------
echo
echo "2. an unusable branch name is refused"
cd "$REPO"
for BAD in "foo..bar" "has space" "ends.lock" "-dashfirst" "ref@{0}"; do
    OUT=$(timeout 5 ./ticket.sh new "rejected" --branch "$BAD" 2>&1)
    RC=$?
    if [[ $RC -ne 0 ]] && echo "$OUT" | grep -q "Invalid branch name"; then
        pass "'$BAD' is refused"
    else
        fail "'$BAD' was accepted" "$OUT"
    fi
done
if [[ -z "$(safe_get_ticket_name "*rejected*")" ]]; then
    pass "no ticket is left behind by a refused --branch"
else
    fail "a ticket was created despite the bad branch name" "$(ls tickets)"
fi

# ---------------------------------------------------------------------------
echo
echo "3. start uses the named branch"
cd "$REPO"
git add -A && git commit -q -m "Add ticket"
OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "agent/issue-12" ]]; then
    pass "start checks out agent/issue-12"
else
    fail "start used a different branch" "$(git rev-parse --abbrev-ref HEAD)"
fi
if ! git show-ref --verify --quiet "refs/heads/feature/${TICKET}"; then
    pass "the prefix-named branch is not created as well"
else
    fail "a feature/<name> branch was created too" "$(git branch --list)"
fi
if grep -q "^started_at: \"\?20" "tickets/${TICKET}/ticket.md"; then
    pass "started_at is stamped as usual"
else
    fail "started_at not set" "$(sed -n '1,10p' "tickets/${TICKET}/ticket.md")"
fi

# ---------------------------------------------------------------------------
echo
echo "4. check and restore pair the branch with the ticket"
cd "$REPO"
OUT=$(timeout 20 ./ticket.sh check 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "active and synchronized"; then
    pass "check reports the ticket in sync"
else
    fail "check reported a mismatch" "$OUT"
fi
if ! echo "$OUT" | grep -q "mismatch"; then
    pass "no mismatch is reported"
else
    fail "mismatch text present" "$OUT"
fi

rm -f current-ticket.md current-note.md
rm -rf current-ticket
OUT=$(timeout 20 ./ticket.sh restore 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "$TICKET"; then
    pass "restore finds the ticket from the branch alone"
else
    fail "restore could not resolve the branch" "$OUT"
fi

# check recreates the link by itself when the symlink is gone, which is the
# path a bot takes: it never ran start, so nothing made the link.
rm -f current-ticket.md current-note.md
rm -rf current-ticket
OUT=$(timeout 20 ./ticket.sh check 2>&1)
if echo "$OUT" | grep -q "Found matching ticket for current branch"; then
    pass "check alone re-establishes the link"
else
    fail "check did not recover the link" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "5. close squash-merges the named branch"
cd "$REPO"
timeout 20 ./ticket.sh restore >/dev/null 2>&1
echo "work" >> README.md
git add -A && git commit -q -m "Do the work"
OUT=$(timeout 30 ./ticket.sh close --no-push 2>&1)
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "close succeeds"
else
    fail "close failed" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]]; then
    pass "we end up on main"
else
    fail "not on main after close" "$(git rev-parse --abbrev-ref HEAD)"
fi
if [[ -f "tickets/done/${TICKET}/ticket.md" ]]; then
    pass "the ticket directory is in done/"
else
    fail "ticket not moved to done/" "$(ls -R tickets | head -20)"
fi
if git log --format='%s' -1 | grep -q "\[${TICKET}\]"; then
    pass "the squash commit is on main"
else
    fail "no squash commit" "$(git log --oneline -3)"
fi
if grep -q "^work$" README.md; then
    pass "the branch's work came across"
else
    fail "the work is missing from main" "$(cat README.md)"
fi

# ---------------------------------------------------------------------------
echo
echo "6. a branch created before the ticket is adopted, not duplicated"
REPO=$(make_repo preexisting)
cd "$REPO"
timeout 5 ./ticket.sh new adopted --branch agent/issue-99 >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*adopted*")
git add -A && git commit -q -m "Add ticket"
# The bot's machinery gets there first.
git branch agent/issue-99 main

OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if echo "$OUT" | grep -q "already exists. Resuming work"; then
    pass "start resumes the existing branch"
else
    fail "start did not recognise the branch" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "agent/issue-99" ]]; then
    pass "and checks it out"
else
    fail "start left us elsewhere" "$(git rev-parse --abbrev-ref HEAD)"
fi

# ---------------------------------------------------------------------------
echo
echo "7. list follows the override"
# The case list has to cover is a start whose fast-forward onto the base branch
# did not land: the ticket file on main still reads todo while the feature
# branch carries the start time. Reading only main would call work in progress
# 'todo', and with an overridden branch name list has to know where to look.
REPO=$(make_repo listing)
cd "$REPO"
timeout 5 ./ticket.sh new listed --branch agent/issue-7 >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*listed*")
git add -A && git commit -q -m "Add ticket"
timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1
# Undo the fast-forward, leaving main's copy of the ticket as it was before.
git checkout -q main
git reset -q --hard HEAD~1

OUT=$(timeout 20 ./ticket.sh list 2>&1)
if echo "$OUT" | grep -q "status: doing"; then
    pass "the ticket reads doing from the base branch"
else
    fail "list fell back to todo" "$OUT"
fi
if echo "$OUT" | grep -q "started_at_only_on: agent/issue-7"; then
    pass "started_at_only_on names the overridden branch"
else
    fail "list did not look at the overridden branch" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "8. a ticket without the field behaves exactly as before"
REPO=$(make_repo plain)
cd "$REPO"
timeout 5 ./ticket.sh new ordinary >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*ordinary*")
if ! grep -q "^branch:" "tickets/${TICKET}/ticket.md"; then
    pass "no branch: field is written without --branch"
else
    fail "a branch: field appeared unasked" "$(sed -n '1,10p' "tickets/${TICKET}/ticket.md")"
fi
git add -A && git commit -q -m "Add ticket"
timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "feature/${TICKET}" ]]; then
    pass "start still uses {branch_prefix}<ticket-name>"
else
    fail "the default branch naming changed" "$(git rev-parse --abbrev-ref HEAD)"
fi
OUT=$(timeout 20 ./ticket.sh check 2>&1)
if [[ $? -eq 0 ]] && echo "$OUT" | grep -q "active and synchronized"; then
    pass "check is unchanged for such a ticket"
else
    fail "check changed for a plain ticket" "$OUT"
fi

# A branch that is neither prefixed nor claimed by any ticket is still not a
# feature branch - the override must not turn every branch into one.
cd "$REPO"
git checkout -q -b some/other-work
OUT=$(timeout 20 ./ticket.sh restore 2>&1)
if [[ $? -ne 0 ]] && echo "$OUT" | grep -q "Not on a feature branch"; then
    pass "an unrelated branch is still refused"
else
    fail "restore accepted an unrelated branch" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "=== branch override Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "$REPO_ROOT"
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
