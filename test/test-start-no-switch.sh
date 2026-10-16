#!/usr/bin/env bash

# Tests that in-place `start` looks before it leaps (issue #21).
#
# Creating the feature branch means checking out the ticket's base branch first,
# and the ticket's existence used to be checked after that. A ticket the base
# branch does not carry therefore produced "Ticket not found" from a tree that
# genuinely did not have it - with the caller left standing on the base branch
# and never told it had moved.
#
# Three separate things were wrong, and the tests below are one per thing: start
# failed and yet HEAD had changed; "does not exist" was false, since the ticket
# was right there a moment earlier; and the message's own advice made it worse,
# because `list` on the base branch answers "(No tickets found)" and hardens the
# wrong conclusion. That third one is why section 2 runs `list` afterwards - a
# refusal that leaves the next command lying is not fixed.
#
# Section 4 is the other half of the bargain: the ways out that the message
# offers are run exactly as printed, because advice nobody tried is a guess.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== start: no branch switch before the ticket is found ==="
echo

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/tmp/test-start-no-switch-$(date +%s)"
mkdir -p "${REPO_ROOT}/tmp"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

(cd "$REPO_ROOT" && ./build.sh >/dev/null 2>&1)

PASSED=0
FAILED=0
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; [[ -n "${2:-}" ]] && echo "    $2"; FAILED=$((FAILED + 1)); }

# A repo with a 'release' branch cut before the ticket exists, and a ticket
# committed on main whose base_branch names 'release'. That is the reported
# shape: a perfectly ordinary ticket (made and committed where the work was
# happening) pointed at a branch that does not carry it.
# Sets REPO and TICKET.
# Usage: setup <dir-name> [worktree-mode:true|false]
setup() {
    local name="$1"
    local wt_mode="${2:-false}"
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
    [[ "$wt_mode" == "true" ]] && printf '\nworktree_mode: true\n' >> .ticket-config.yaml
    git add . && git commit -q -m "Init ticket system"

    # Cut the base branch before the ticket is committed, so it cannot have it.
    git branch release

    timeout 5 ./ticket.sh new "$name" >/dev/null 2>&1
    TICKET=$(safe_get_ticket_name "*${name}*")
    sed_i "s|^base_branch: default.*|base_branch: release|" "tickets/${TICKET}/ticket.md"
    git add tickets && git commit -q -m "Add ticket on main only"

    REPO="$dir"
}

# ---------------------------------------------------------------------------
echo "1. it refuses without moving"
setup refuses
cd "$REPO"
BEFORE=$(git rev-parse --abbrev-ref HEAD)
HEAD_BEFORE=$(git rev-parse HEAD)
OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
RC=$?
if [[ $RC -ne 0 ]]; then
    pass "start fails"
else
    fail "start claimed to succeed" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "$BEFORE" ]]; then
    pass "we are still on '$BEFORE'"
else
    fail "start moved us to '$(git rev-parse --abbrev-ref HEAD)'" "$OUT"
fi
if [[ "$(git rev-parse HEAD)" == "$HEAD_BEFORE" ]]; then
    pass "HEAD did not move"
else
    fail "HEAD moved" "$(git log --oneline -2)"
fi
if ! echo "$OUT" | grep -q "Switching to"; then
    pass "it never announced a switch"
else
    fail "it switched branches" "$OUT"
fi
if [[ -f "tickets/${TICKET}/ticket.md" ]]; then
    pass "the ticket is still in the working tree"
else
    fail "the ticket was taken out of the tree" "$(ls -R tickets)"
fi

# ---------------------------------------------------------------------------
echo
echo "2. it says what is actually wrong, and leaves 'list' honest"
cd "$REPO"
OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if echo "$OUT" | grep -q "Ticket is not on its base branch"; then
    pass "the error names the real problem"
else
    fail "the error does not say what is wrong" "$OUT"
fi
# The old message said the ticket does not exist. It did exist; it was the
# switch that would have made that true.
if ! echo "$OUT" | grep -q "does not exist"; then
    pass "it does not claim the ticket does not exist"
else
    fail "it still claims the ticket does not exist" "$OUT"
fi
if echo "$OUT" | grep -q "base_branch:  release"; then
    pass "it names the base branch"
else
    fail "the base branch is not named" "$OUT"
fi
if echo "$OUT" | grep -q "Nothing was switched"; then
    pass "it says nothing was switched"
else
    fail "it does not say the tree was left alone" "$OUT"
fi
# The whole point of refusing where we stand: the next thing the user runs has
# to still be able to see the ticket.
LIST=$(timeout 20 ./ticket.sh list 2>&1)
if echo "$LIST" | grep -q "$TICKET"; then
    pass "'list' still shows the ticket afterwards"
else
    fail "'list' cannot see the ticket after the refusal" "$LIST"
fi

# ---------------------------------------------------------------------------
echo
echo "3. a ticket that is nowhere is still 'not found' - and still no switch"
setup nowhere
cd "$REPO"
git checkout -q -b somewhere-else
OUT=$(timeout 20 ./ticket.sh start 999999-000000-no-such-ticket 2>&1)
RC=$?
if [[ $RC -ne 0 ]] && echo "$OUT" | grep -q "Error: Ticket not found"; then
    pass "it is reported as not found"
else
    fail "a missing ticket was not reported" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "somewhere-else" ]]; then
    pass "and we did not move to say so"
else
    fail "it switched branches to report a missing ticket" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "4. every way out the message offers actually works"
# Run them exactly as printed. Advice nobody tried is a guess, and this message
# is the whole of what the user has to go on.

# (1) put the ticket on the base branch
setup wayout-carry
cd "$REPO"
CARRY=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1 | grep "git checkout main --" | head -1)
if [[ -n "$CARRY" ]]; then
    pass "the message gives a command to carry the ticket over"
else
    fail "no carry command was printed" "$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)"
fi
# It must name the ticket directory, not ticket.md alone: note.md and any
# ticket_files entries belong to the ticket, and advice that moved one file
# would land the user on the base branch with the note left behind.
if echo "$CARRY" | grep -q "tickets/${TICKET}/\$"; then
    pass "it names the whole ticket directory"
else
    fail "it names a single file" "$CARRY"
fi
git checkout -q release
# Run the printed line itself, trimmed of its indentation - this is the test, so
# it must be that line and not a reconstruction of it.
eval "$(printf '%s' "$CARRY" | sed 's/^[[:space:]]*//')"
git commit -q -m "Add ticket"
if [[ -f "tickets/${TICKET}/note.md" ]]; then
    pass "the note came across with it"
else
    fail "the note was left behind" "$(ls -A "tickets/${TICKET}")"
fi
OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "Started ticket:"; then
    pass "start works after following it"
else
    fail "the way out did not work" "$OUT"
fi

# (2) point base_branch at the branch the work is really based on
setup wayout-retarget
cd "$REPO"
sed_i "s|^base_branch: release.*|base_branch: default|" "tickets/${TICKET}/ticket.md"
git add -A && git commit -q -m "retarget"
OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "Started ticket:"; then
    pass "start works once base_branch names a branch that has the ticket"
else
    fail "retargeting did not work" "$OUT"
fi

# (3) start it in a worktree
setup wayout-worktree
cd "$REPO"
OUT=$(timeout 30 ./ticket.sh start --worktree "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "WORKTREE:"; then
    pass "--worktree starts it as the message says"
else
    fail "--worktree did not work" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]]; then
    pass "and the main checkout stayed where it was"
else
    fail "--worktree moved the main checkout" "$(git branch --show-current)"
fi

# ---------------------------------------------------------------------------
echo
echo "5. the ordinary flows are untouched"
# The ticket committed on the base branch, started from another ticket's feature
# branch: the switch is exactly what should happen here, and the guard must not
# get in its way.
dir="${TEST_DIR}/ordinary"
rm -rf "$dir"; mkdir -p "$dir"; cd "$dir"
git init -q -b main
git config user.name "Test"; git config user.email "test@test.com"
echo "# Test" > README.md; git add README.md; git commit -q -m "Initial"
cp "${REPO_ROOT}/ticket.sh" .; chmod +x ticket.sh
timeout 10 ./ticket.sh init >/dev/null 2>&1
sed_i 's/^auto_push: true/auto_push: false/' .ticket-config.yaml
git add . && git commit -q -m "Init"
timeout 5 ./ticket.sh new alpha >/dev/null 2>&1
timeout 5 ./ticket.sh new beta >/dev/null 2>&1
T_A=$(safe_get_ticket_name "*alpha*")
T_B=$(safe_get_ticket_name "*beta*")
git add tickets && git commit -q -m "Add tickets"
timeout 20 ./ticket.sh start "$T_A" >/dev/null 2>&1
OUT=$(timeout 20 ./ticket.sh start "$T_B" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "Started ticket: ${T_B}"; then
    pass "starting a second ticket from the first's branch still works"
else
    fail "the guard broke the ordinary cross-branch start" "$OUT"
fi
if echo "$OUT" | grep -q "Switching to 'main' branch"; then
    pass "it still switches to the base branch when it should"
else
    fail "it stopped switching when switching was right" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "feature/${T_B}" ]]; then
    pass "and lands on the new feature branch"
else
    fail "it ended up somewhere else" "$(git branch --show-current)"
fi

# ---------------------------------------------------------------------------
echo
echo "=== Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "$REPO_ROOT"
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
