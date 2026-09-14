#!/usr/bin/env bash

# Tests for config's append_only_files (issue #7).
#
# A ticket file kept as a record of how the work went is only worth keeping if
# nobody goes back and tidies the wrong turns out of it. `close` is the one
# command that always runs before a ticket is finished, so it is where lines
# that went missing get refused.
#
# The part worth testing carefully is what "went missing" means. Judging per
# commit would make the only available repair - appending the lines again,
# since history is not to be rewritten - fail to clear the gate, leaving
# force-push as the sole way forward. So a removal is forgiven once the line is
# back in the file, and section 4 is the test that says so.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== append_only_files Test Suite ==="
echo

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/tmp/test-append-only-$(date +%s)"
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

# Build a repo whose config declares progress.md both as a ticket_files entry
# and as append-only, then create a ticket and start it. Echoes the repo path
# into REPO and the ticket name into TICKET.
# Usage: setup <dir-name> [declare-append-only:true|false]
setup() {
    local name="$1"
    local declare_ao="${2:-true}"
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

    cat >> .ticket-config.yaml << 'EOF'

ticket_files:
  - path: progress.md
    content: |
      # Progress: $$TICKET_NAME$$

      - opened
EOF
    if [[ "$declare_ao" == "true" ]]; then
        cat >> .ticket-config.yaml << 'EOF'

append_only_files:
  - progress.md
EOF
    fi
    git add . && git commit -q -m "Init ticket system"

    timeout 5 ./ticket.sh new logged >/dev/null 2>&1
    TICKET=$(safe_get_ticket_name "*logged*")
    git add tickets && git commit -q -m "Add ticket"
    timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1

    REPO="$dir"
    PROGRESS="tickets/${TICKET}/progress.md"
}

# Append a line to the progress file and commit.
append_progress() {
    printf '%s\n' "$1" >> "$PROGRESS"
    git add -A && git commit -q -m "${2:-progress}"
}

# Drop a line from the progress file and commit.
drop_progress() {
    grep -v -F -x -- "$1" "$PROGRESS" > "${PROGRESS}.new"
    mv "${PROGRESS}.new" "$PROGRESS"
    git add -A && git commit -q -m "${2:-tidy progress}"
}

# ---------------------------------------------------------------------------
echo "1. appending only is fine"
setup appending
cd "$REPO"
append_progress "- step one" "progress: step one"
append_progress "- step two" "progress: step two"

OUT=$(timeout 20 ./ticket.sh check 2>&1)
if echo "$OUT" | grep -q "Append-only files intact"; then
    pass "check reports the file intact"
else
    fail "check did not report the file" "$OUT"
fi
OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
if [[ $? -eq 0 ]] && echo "$OUT" | grep -q "all preflight checks passed"; then
    pass "close --dry-run passes"
else
    fail "close refused a file that only grew" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "2. a commit that removes a line makes close refuse"
setup removing
cd "$REPO"
append_progress "- tried the obvious thing, it did not work" "progress: first attempt"
append_progress "- second approach" "progress: second attempt"
drop_progress "- tried the obvious thing, it did not work" "progress: tidy up the false start"

OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
RC=$?
if [[ $RC -ne 0 ]]; then
    pass "close refuses"
else
    fail "close allowed a removal" "$OUT"
fi
if echo "$OUT" | grep -q "$PROGRESS"; then
    pass "the message names the file"
else
    fail "the file is not named" "$OUT"
fi
if echo "$OUT" | grep -q "tidy up the false start"; then
    pass "the message names the commit"
else
    fail "the commit is not named" "$OUT"
fi
if echo "$OUT" | grep -q "1 line(s) gone"; then
    pass "the message gives the count"
else
    fail "no line count" "$OUT"
fi
if echo "$OUT" | grep -q -- "- tried the obvious thing, it did not work"; then
    pass "the message shows the missing line"
else
    fail "the missing line is not shown" "$OUT"
fi
if echo "$OUT" | grep -q "Nothing was closed"; then
    pass "close says nothing was closed"
else
    fail "close did not say it stopped" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "3. --force does not get past it, and --dry-run shows it"
cd "$REPO"
OUT=$(timeout 20 ./ticket.sh close --force 2>&1)
RC=$?
if [[ $RC -ne 0 ]] && echo "$OUT" | grep -q "Append-only file is missing lines"; then
    pass "--force still refuses"
else
    fail "--force bypassed the check" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
    pass "nothing was merged"
else
    fail "the branch was closed anyway" "$(git log --oneline -3)"
fi
# Already exercised in section 2, but state it as its own claim: the refusal
# has to be visible from a run that changes nothing.
OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
if echo "$OUT" | grep -q "Append-only file is missing lines"; then
    pass "--dry-run shows the refusal"
else
    fail "--dry-run hid the refusal" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "4. appending the line again clears it"
cd "$REPO"
append_progress "- tried the obvious thing, it did not work" "progress: restore the line I removed"
OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "all preflight checks passed"; then
    pass "close passes once the line is back"
else
    fail "close still refuses after the repair" "$OUT"
fi
if [[ "$(git log --format='%s' -1)" == "progress: restore the line I removed" ]]; then
    pass "the repair did not need history to be rewritten"
else
    fail "history was rewritten" "$(git log --oneline -3)"
fi

# ---------------------------------------------------------------------------
echo
echo "5. plain check reports the loss but exits 0"
setup checking
cd "$REPO"
append_progress "- a line I will regret removing" "progress: note it"
drop_progress "- a line I will regret removing" "progress: remove it"

OUT=$(timeout 20 ./ticket.sh check 2>&1)
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "check exits 0"
else
    fail "check failed mid-ticket (exit $RC)" "$OUT"
fi
if echo "$OUT" | grep -q "Append-only file is missing lines"; then
    pass "check still shows the loss"
else
    fail "check said nothing about it" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "6. a modified line counts as a removal"
setup modifying
cd "$REPO"
append_progress "- the API returns 200" "progress: record the result"
sed_i 's/^- the API returns 200$/- the API returns 201/' "$PROGRESS"
git add -A && git commit -q -m "progress: fix the status code"

OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
if [[ $? -ne 0 ]] && echo "$OUT" | grep -q -- "- the API returns 200"; then
    pass "editing a line already written is refused"
else
    fail "an edit slipped through" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "7. the key being undefined changes nothing"
setup undeclared false
cd "$REPO"
append_progress "- something" "progress: note it"
drop_progress "- something" "progress: remove it"

OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "close passes with append_only_files undefined"
else
    fail "close refused without the key" "$OUT"
fi
if ! echo "$OUT" | grep -q "Append-only"; then
    pass "nothing about append-only is printed"
else
    fail "the check ran without being asked for" "$OUT"
fi
OUT=$(timeout 20 ./ticket.sh check 2>&1)
if ! echo "$OUT" | grep -q "Append-only"; then
    pass "check says nothing about it either"
else
    fail "check printed an append-only line" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "8. a ticket without the file is left alone"
setup missingfile
cd "$REPO"
git rm -q "$PROGRESS"
git commit -q -m "Remove progress.md entirely"
echo "work" >> README.md
git add -A && git commit -q -m "Do the work"

OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "close passes when the declared file is not there"
else
    fail "a missing file was treated as a violation" "$OUT"
fi
OUT=$(timeout 20 ./ticket.sh check 2>&1)
if ! echo "$OUT" | grep -q "Append-only"; then
    pass "check does not claim a file it cannot see is intact"
else
    fail "check reported on a file that is not there" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "=== append_only_files Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "$REPO_ROOT"
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
