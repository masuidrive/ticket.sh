#!/usr/bin/env bash

# Tests for config's post_start_command (issue #19).
#
# `worktree_copy_files` brings gitignored files into a new worktree, but a
# worktree also needs the things no copy can produce - the directories a package
# manager builds. Projects were documenting "run npm install first in a
# worktree" and relying on whoever read it; the reported case is an agent that
# did not, and a test run that could not start vitest.
#
# This is pre_close_command's counterpart with one deliberate difference, and
# that difference is what most of this file is about. A close check exists to
# refuse. This exists to prepare, and the worktree is already built by the time
# it runs - so a failure warns and start still succeeds. Sections 4 and 5 pin
# that, along with the three cases where it must not run at all: a worktree that
# was already there, a start that makes no worktree, and --no-post-start.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== post_start_command Test Suite ==="
echo

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/tmp/test-post-start-$(date +%s)"
mkdir -p "${REPO_ROOT}/tmp"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# Always rebuild so the harness runs against current sources.
(cd "$REPO_ROOT" && ./build.sh >/dev/null 2>&1)

PASSED=0
FAILED=0
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; [[ -n "${2:-}" ]] && echo "    $2"; FAILED=$((FAILED + 1)); }

# Build a repo in worktree mode with a prep.sh, create a ticket, but do not
# start it. $2 is the body of prep.sh; $3, when "false", leaves
# post_start_command out of the config entirely.
# Sets REPO and TICKET.
# Usage: setup <dir-name> <prep-body> [declare:true|false]
setup() {
    local name="$1"
    local prep_body="$2"
    local declare_it="${3:-true}"
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
    printf '\nworktree_mode: true\n' >> .ticket-config.yaml
    if [[ "$declare_it" == "true" ]]; then
        printf 'post_start_command: "bash prep.sh"\n' >> .ticket-config.yaml
    fi
    printf '%s\n' "$prep_body" > prep.sh
    chmod +x prep.sh
    git add . && git commit -q -m "Init ticket system"

    timeout 5 ./ticket.sh new "$name" >/dev/null 2>&1
    TICKET=$(safe_get_ticket_name "*${name}*")
    git add tickets && git commit -q -m "Add ticket"

    REPO="$dir"
}

# Resolve the worktree path out of start's own WORKTREE: line. It reports a path
# built from the main repo plus "..", while a `pwd` from inside comes back
# resolved, so comparing the two as strings would quietly answer nothing.
wt_from() {
    local raw
    raw=$(echo "$1" | grep "^WORKTREE:" | head -1 | cut -d: -f2-)
    [[ -z "$raw" ]] && return 1
    (cd "$raw" 2>/dev/null && pwd -P) || echo "$raw"
}

PREP_OK='#!/usr/bin/env bash
{
    echo "cwd=$(pwd)"
    echo "name=$TICKET_NAME"
    echo "dir=$TICKET_DIR"
    echo "file=$TICKET_FILE"
    echo "branch=$TICKET_BRANCH"
    echo "base=$TICKET_BASE_BRANCH"
} > "$(pwd)/prep-ran.txt"
mkdir -p node_modules
echo installed > node_modules/.marker
echo "prep: dependencies are in place"
exit 0'

# ---------------------------------------------------------------------------
echo "1. with nothing declared, start behaves exactly as before"
setup default "$PREP_OK" false
cd "$REPO"
OUT=$(timeout 30 ./ticket.sh start "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "Started ticket:"; then
    pass "start succeeds with no post_start_command key"
else
    fail "start changed behaviour with the key absent" "$OUT"
fi
if ! echo "$OUT" | grep -q "post_start_command"; then
    pass "start says nothing about a command nobody asked for"
else
    fail "start mentioned post_start_command" "$OUT"
fi
WT=$(wt_from "$OUT")
if [[ -n "$WT" ]] && [[ ! -e "${WT}/prep-ran.txt" ]]; then
    pass "prep.sh did not run"
else
    fail "prep.sh ran without being declared" "$(cat "${WT}/prep-ran.txt" 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
echo
echo "2. on a worktree it creates, it runs there and is handed the ticket"
setup fresh "$PREP_OK"
cd "$REPO"
OUT=$(timeout 30 ./ticket.sh start "$TICKET" 2>&1)
RC=$?
WT=$(wt_from "$OUT")
if [[ $RC -eq 0 ]] && [[ -n "$WT" ]]; then
    pass "start succeeded and made a worktree"
else
    fail "start did not make a worktree" "$OUT"
fi
if echo "$OUT" | grep -q "Running post_start_command: bash prep.sh"; then
    pass "the run is announced with the command"
else
    fail "the command was run silently" "$OUT"
fi
if echo "$OUT" | grep -q "prep: dependencies are in place"; then
    pass "the command's own output is shown"
else
    fail "the command's output was swallowed" "$OUT"
fi
if [[ -f "${WT}/node_modules/.marker" ]]; then
    pass "what it built is in the worktree"
else
    fail "nothing was built in the worktree" "$(ls -A "$WT" 2>/dev/null)"
fi
if [[ ! -e "${REPO}/node_modules" ]]; then
    pass "and not in the main checkout"
else
    fail "it built in the main checkout instead" "$(ls -A "$REPO")"
fi

SEEN=$(cat "${WT}/prep-ran.txt" 2>/dev/null)
if echo "$SEEN" | grep -q "^cwd=${WT}$"; then
    pass "it runs at the new worktree's root"
else
    fail "it ran somewhere else" "$SEEN"
fi
if echo "$SEEN" | grep -q "^name=${TICKET}$"; then
    pass "TICKET_NAME is the ticket name"
else
    fail "TICKET_NAME is wrong" "$SEEN"
fi
if echo "$SEEN" | grep -q "^dir=tickets/${TICKET}$"; then
    pass "TICKET_DIR is the ticket directory"
else
    fail "TICKET_DIR is wrong" "$SEEN"
fi
if echo "$SEEN" | grep -q "^file=tickets/${TICKET}/ticket.md$"; then
    pass "TICKET_FILE is the ticket file"
else
    fail "TICKET_FILE is wrong" "$SEEN"
fi
if echo "$SEEN" | grep -q "^branch=feature/${TICKET}$"; then
    pass "TICKET_BRANCH is the feature branch"
else
    fail "TICKET_BRANCH is wrong" "$SEEN"
fi
if echo "$SEEN" | grep -q "^base=main$"; then
    pass "TICKET_BASE_BRANCH is the base branch"
else
    fail "TICKET_BASE_BRANCH is wrong" "$SEEN"
fi

# The paths block is the one piece of output a downstream agent has to read. An
# install log is long, so the order is not cosmetic.
PREP_LINE=$(echo "$OUT" | grep -n "Running post_start_command" | head -1 | cut -d: -f1)
PATHS_LINE=$(echo "$OUT" | grep -n "^Active ticket paths:" | head -1 | cut -d: -f1)
if [[ -n "$PREP_LINE" ]] && [[ -n "$PATHS_LINE" ]] && [[ "$PREP_LINE" -lt "$PATHS_LINE" ]]; then
    pass "the output comes before the Active ticket paths block"
else
    fail "the paths block was pushed up by the install log" "prep at ${PREP_LINE}, paths at ${PATHS_LINE}"
fi

# ---------------------------------------------------------------------------
echo
echo "3. it does not run again on a worktree that is already there"
cd "$REPO"
rm -f "${WT}/prep-ran.txt"
OUT=$(timeout 30 ./ticket.sh start "$TICKET" 2>&1)
if ! echo "$OUT" | grep -q "post_start_command"; then
    pass "resuming into the existing worktree runs nothing"
else
    fail "it installed again on resume" "$OUT"
fi
if [[ ! -e "${WT}/prep-ran.txt" ]]; then
    pass "the command really did not run"
else
    fail "the command ran on resume" "$(cat "${WT}/prep-ran.txt")"
fi

# ...but it does run when the worktree has to be built again, which is the same
# "this run created it" rule and not a special case for resuming.
git worktree remove --force "$WT" >/dev/null 2>&1
OUT=$(timeout 30 ./ticket.sh start "$TICKET" 2>&1)
WT=$(wt_from "$OUT")
if echo "$OUT" | grep -q "Running post_start_command"; then
    pass "a rebuilt worktree is prepared again"
else
    fail "the rebuilt worktree was left unprepared" "$OUT"
fi
if [[ -f "${WT}/node_modules/.marker" ]]; then
    pass "and what it builds is there"
else
    fail "nothing was built" "$(ls -A "$WT" 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
echo
echo "4. a start that makes no worktree, and --no-post-start, run nothing"
setup noworktree "$PREP_OK"
cd "$REPO"
OUT=$(timeout 30 ./ticket.sh start --no-worktree "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && ! echo "$OUT" | grep -q "post_start_command"; then
    pass "--no-worktree runs nothing"
else
    fail "it ran without a worktree to prepare" "$OUT"
fi
if [[ ! -e "${REPO}/node_modules" ]]; then
    pass "nothing was built in the checkout"
else
    fail "it built in the current checkout" "$(ls -A "$REPO")"
fi

setup skipflag "$PREP_OK"
cd "$REPO"
OUT=$(timeout 30 ./ticket.sh start --no-post-start "$TICKET" 2>&1)
RC=$?
WT=$(wt_from "$OUT")
if [[ $RC -eq 0 ]] && ! echo "$OUT" | grep -q "post_start_command"; then
    pass "--no-post-start runs nothing"
else
    fail "--no-post-start ran it anyway" "$OUT"
fi
if [[ -n "$WT" ]] && [[ -d "$WT" ]]; then
    pass "the worktree is still created"
else
    fail "--no-post-start also skipped the worktree" "$OUT"
fi
# The flag is new, so the check that a near miss is still an error matters: this
# command refuses unknown flags on purpose (issue #11), and a typo that becomes a
# silent no-op is found much later, if at all.
OUT=$(timeout 10 ./ticket.sh start --no-post-sta "$TICKET" 2>&1)
RC=$?
if [[ $RC -ne 0 ]] && echo "$OUT" | grep -q "Unknown option"; then
    pass "a misspelt flag is still an error"
else
    fail "a misspelt flag was accepted" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "5. a failure warns; it does not take the ticket down with it"
setup failing '#!/usr/bin/env bash
echo "prep: the registry is down" >&2
exit 7'
cd "$REPO"
OUT=$(timeout 30 ./ticket.sh start "$TICKET" 2>&1)
RC=$?
WT=$(wt_from "$OUT")
if [[ $RC -eq 0 ]]; then
    pass "start still exits 0"
else
    fail "a failed preparation stopped start" "$OUT"
fi
if echo "$OUT" | grep -q "prep: the registry is down"; then
    pass "the command's own reason is shown"
else
    fail "the reason was swallowed" "$OUT"
fi
if echo "$OUT" | grep -q "Warning: post_start_command failed (exit 7)"; then
    pass "it is reported as a warning with the exit status"
else
    fail "the failure was not reported" "$OUT"
fi
if echo "$OUT" | grep -q "cd .* && bash prep.sh"; then
    pass "the message says what to re-run"
else
    fail "no way forward is given" "$OUT"
fi
if [[ -n "$WT" ]] && [[ -d "$WT" ]] && [[ -f "${WT}/current-ticket.md" ]]; then
    pass "the worktree and its symlinks are there"
else
    fail "the worktree was left unusable" "$(ls -A "$WT" 2>/dev/null)"
fi
if echo "$OUT" | grep -q "Started ticket:"; then
    pass "the ticket is started"
else
    fail "the ticket was not started" "$OUT"
fi
if grep -q '^started_at: 2' "${WT}/tickets/${TICKET}/ticket.md"; then
    pass "started_at is stamped"
else
    fail "started_at was not stamped" "$(head -8 "${WT}/tickets/${TICKET}/ticket.md")"
fi

# ---------------------------------------------------------------------------
echo
echo "6. a command that cd's away or ends on a false test is contained"
setup contained '#!/usr/bin/env bash
cd /
grep -q nothing-here /dev/null && echo "unreachable"
exit 0'
cd "$REPO"
OUT=$(timeout 30 ./ticket.sh start "$TICKET" 2>&1)
RC=$?
WT=$(wt_from "$OUT")
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "Started ticket:"; then
    pass "start finishes normally"
else
    fail "the command derailed start" "$OUT"
fi
if ! echo "$OUT" | grep -q "post_start_command failed"; then
    pass "a trailing false test is not read as a failure"
else
    fail "the exit status was not what was judged" "$OUT"
fi
if [[ -n "$WT" ]] && [[ -f "${WT}/current-ticket.md" ]]; then
    pass "the worktree is intact"
else
    fail "the worktree is broken" "$(ls -A "$WT" 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
echo
echo "=== post_start_command Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "$REPO_ROOT"
git worktree prune 2>/dev/null || true
# The worktrees land at ${TEST_DIR}/<name>.worktrees (worktree_dir defaults to
# ../<project>.worktrees, relative to each test repo), so they go with TEST_DIR.
rm -rf "$TEST_DIR"
if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
