#!/usr/bin/env bash

# Test script for how a run reports a failure it did not plan for (issue #16)

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== ticket.sh Error Reporting Test Suite ==="
echo

TEST_DIR="tmp/test-error-reporting-$(date +%s)"
mkdir -p tmp
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

(cd "${SCRIPT_DIR}/.." && ./build.sh >/dev/null 2>&1)
cp "${SCRIPT_DIR}/../ticket.sh" .
chmod +x ticket.sh

PASSED=0
FAILED=0
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    [[ -n "${2:-}" ]] && echo "    $2"
    FAILED=$((FAILED + 1))
}

echo "Setting up git repo..."
git init -q -b main
git config user.name "Test"
git config user.email "test@test.com"
echo "# Test" > README.md
git add README.md
git commit -q -m "Initial"
timeout 10 ./ticket.sh init >/dev/null 2>&1
git add . && git commit -q -m "Init ticket system"
MAIN_REPO=$(pwd)
echo "  Setup complete"
echo

# Build a copy of ticket.sh that fails on purpose, right after the traps are
# installed. There is no way in from outside - the thing under test is what the
# script does when one of its own commands fails unexpectedly - and injecting
# into a copy keeps the hook out of the shipped script.
#
# Usage: crash_copy <name> <line>
crash_copy() {
    local name="$1"
    local line="$2"
    awk -v inject="$line" '
        { print }
        /^trap ticket_report_unexpected_exit EXIT$/ { print inject }
    ' ticket.sh > "$name"
    chmod +x "$name"
}

echo "1. A planned refusal says its own piece and nothing more..."
RC=0
OUTPUT=$(timeout 10 ./ticket.sh start no-such-ticket 2>&1) || RC=$?
if [[ $RC -eq 1 ]]; then
    pass "a missing ticket exits 1"
else
    fail "a missing ticket exited $RC" "$OUTPUT"
fi
if echo "$OUTPUT" | grep -q "Error: Ticket not found"; then
    pass "and says so"
else
    fail "the refusal lost its message" "$OUTPUT"
fi
if ! echo "$OUTPUT" | grep -q "stopped unexpectedly"; then
    pass "and is not reported as a crash"
else
    fail "a planned refusal was called a crash" "$OUTPUT"
fi

RC=0
OUTPUT=$(timeout 10 ./ticket.sh help 2>&1) || RC=$?
if [[ $RC -eq 0 ]] && ! echo "$OUTPUT" | grep -q "stopped unexpectedly"; then
    pass "a successful run stays quiet too"
else
    fail "help reported a crash (exit $RC)" "$OUTPUT"
fi
echo

echo "2. An unplanned failure is named instead of swallowed..."
# git's fatal code, which is what the issue hit: the run ended on 128 with
# git's own message already discarded by 2>/dev/null, so the caller got an
# exit code and not one word of explanation.
crash_copy crash128.sh 'git cat-file -e deadbeefdeadbeefdeadbeefdeadbeefdeadbeef:nope 2>/dev/null'
RC=0
OUTPUT=$(timeout 10 ./crash128.sh list 2>&1) || RC=$?
if [[ $RC -eq 128 ]]; then
    pass "the exit code is passed through unchanged (128)"
else
    fail "the exit code became $RC" "$OUTPUT"
fi
if echo "$OUTPUT" | grep -q "stopped unexpectedly (exit 128)"; then
    pass "and the run says it stopped unexpectedly"
else
    fail "the run is still silent" "$OUTPUT"
fi
if echo "$OUTPUT" | grep -q "Last failing command:.*cat-file"; then
    pass "and names the command that failed"
else
    fail "the failing command is not named" "$OUTPUT"
fi
if echo "$OUTPUT" | grep -q "github.com/masuidrive/ticket.sh/issues"; then
    pass "and says where to report it"
else
    fail "no report address" "$OUTPUT"
fi

crash_copy crash127.sh 'definitely_not_a_command_xyz'
RC=0
OUTPUT=$(timeout 10 ./crash127.sh list 2>&1) || RC=$?
if [[ $RC -eq 127 ]] && echo "$OUTPUT" | grep -q "stopped unexpectedly (exit 127)"; then
    pass "a missing command is reported the same way"
else
    fail "exit 127 was not reported (exit $RC)" "$OUTPUT"
fi

# Codes a signal leaves behind are somebody interrupting us, not a bug here.
crash_copy crash130.sh 'exit 130'
RC=0
OUTPUT=$(timeout 10 ./crash130.sh list 2>&1) || RC=$?
if [[ $RC -eq 130 ]] && ! echo "$OUTPUT" | grep -q "stopped unexpectedly"; then
    pass "an interrupted run is not reported as a bug"
else
    fail "exit 130 was called a bug (exit $RC)" "$OUTPUT"
fi
echo

echo "3. A detached main repo HEAD reaches its own message..."
# This already worked, and the point is to keep it working. The read that feeds
# the message is `git symbolic-ref`, which fails on a detached HEAD, and it
# only survives errexit because every caller of check_main_repo_ready wraps it
# in an `|| return 1`. That is a thin thread to hang a message on - one plain
# call site and the refusal goes silent - so the read now tolerates the failure
# itself, and this guards the message either way.
cd "$MAIN_REPO"
echo 'worktree_mode: true' >> .ticket-config.yaml
git add . && git commit -q -m "Enable worktree_mode"
timeout 5 ./ticket.sh new detached-head >/dev/null 2>&1
TICKET_DH=$(safe_get_ticket_name "*detached-head*")
git add . && git commit -q -m "Add detached-head ticket"
OUTPUT=$(timeout 15 ./ticket.sh start "$TICKET_DH" 2>&1)
WT_DH=$(echo "$OUTPUT" | grep "^WORKTREE:" | head -1 | cut -d: -f2-)
if [[ -n "$WT_DH" ]] && [[ -d "$WT_DH" ]]; then
    pass "fixture: the ticket has a worktree"
else
    fail "fixture: no worktree" "$OUTPUT"
fi
git -C "$MAIN_REPO" checkout -q --detach HEAD
RC=0
cd "$WT_DH"
OUTPUT=$(timeout 15 ./ticket.sh close 2>&1) || RC=$?
cd "$MAIN_REPO"
if [[ $RC -ne 0 ]]; then
    pass "close refuses while the main repo is detached"
else
    fail "close went ahead on a detached main repo" "$OUTPUT"
fi
if echo "$OUTPUT" | grep -q "Cannot determine main repo HEAD"; then
    pass "and the refusal says why"
else
    fail "the refusal is silent" "$OUTPUT"
fi

git -C "$MAIN_REPO" checkout -q main
git worktree remove "$WT_DH" --force 2>/dev/null || true
git worktree prune 2>/dev/null || true

echo
echo "=== Error Reporting Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "${SCRIPT_DIR}/.."
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
