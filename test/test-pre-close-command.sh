#!/usr/bin/env bash

# Tests for config's pre_close_command (issue #18).
#
# `close` has always judged a ticket by ticket.sh's own standards - a clean
# tree, the checklists, the append-only files - and a project with a standard of
# its own had nowhere to put it. A Git hook is not that place: `.git/hooks` is
# not in the repo, a hook cannot tell the close commit from any other, and it
# never runs under `--dry-run`.
#
# What needs testing most is not that a failing command stops the close - that
# part is one `if` - but the promises around it: that the project's own output is
# what the user sees, that `--force` does not get past it, that `--dry-run` says
# so before anything is written, that `cancel` never runs it, and that the check
# is handed the ticket rather than left to guess at it. Each of those is a line
# someone could "simplify" away without any other test noticing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== pre_close_command Test Suite ==="
echo

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/tmp/test-pre-close-$(date +%s)"
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

# Build a repo and start a ticket in it. $2 is the config line to add (empty for
# none), $3 the body of check.sh (empty for no script at all).
# Echoes the repo path into REPO and the ticket name into TICKET.
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
    # The checks below report what they were handed by writing a file. Keep those
    # files out of Git, or deleting one between runs leaves the tree dirty and
    # close refuses for a reason that has nothing to do with what is being tested.
    printf 'seen.txt\nran.txt\n' >> .gitignore
    if [[ -n "$config_line" ]]; then
        printf '\n%s\n' "$config_line" >> .ticket-config.yaml
    fi
    git add . && git commit -q -m "Init ticket system"

    timeout 5 ./ticket.sh new gated >/dev/null 2>&1
    TICKET=$(safe_get_ticket_name "*gated*")
    git add tickets && git commit -q -m "Add ticket"
    timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1

    REPO="$dir"
}

# ---------------------------------------------------------------------------
echo "1. with nothing declared, close behaves exactly as before"
setup default
cd "$REPO"
OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "all preflight checks passed"; then
    pass "close passes with no pre_close_command key"
else
    fail "close changed behaviour with the key absent" "$OUT"
fi
if ! echo "$OUT" | grep -q "pre_close_command"; then
    pass "close says nothing about a check nobody asked for"
else
    fail "close mentioned pre_close_command" "$OUT"
fi

# A key written with no value is a declaration of nothing, not a command named
# "null" - which is what yaml_get hands back for it.
setup empty-value "pre_close_command:"
cd "$REPO"
OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && ! echo "$OUT" | grep -q "Running pre_close_command"; then
    pass "an empty value runs nothing"
else
    fail "an empty value was treated as a command" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "2. a command that exits 0 lets the close through"
setup passing 'pre_close_command: "bash check.sh"' '#!/usr/bin/env bash
echo "project check: looks finished"
exit 0'
cd "$REPO"
OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "all preflight checks passed"; then
    pass "close --dry-run passes"
else
    fail "close refused a check that succeeded" "$OUT"
fi
if echo "$OUT" | grep -q "Running pre_close_command: bash check.sh"; then
    pass "the run is announced with the command"
else
    fail "the command was run silently" "$OUT"
fi
if echo "$OUT" | grep -q "project check: looks finished"; then
    pass "the command's own output is shown"
else
    fail "the command's output was swallowed" "$OUT"
fi

OUT=$(timeout 20 ./ticket.sh close 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]]; then
    pass "the real close finishes"
else
    fail "the real close did not finish" "$OUT"
fi
if [[ -f "tickets/done/${TICKET}/ticket.md" ]]; then
    pass "the ticket reached done/"
else
    fail "the ticket is not in done/" "$(ls -R tickets)"
fi

# ---------------------------------------------------------------------------
echo
echo "3. a command that fails stops the close"
setup failing 'pre_close_command: "bash check.sh"' '#!/usr/bin/env bash
echo "project check: progress.md has no entry for the fix" >&2
exit 3'
cd "$REPO"
BEFORE=$(git rev-parse main)
OUT=$(timeout 20 ./ticket.sh close 2>&1)
RC=$?
if [[ $RC -ne 0 ]]; then
    pass "close refuses"
else
    fail "close went ahead anyway" "$OUT"
fi
if echo "$OUT" | grep -q "project check: progress.md has no entry for the fix"; then
    pass "the command's own reason is shown"
else
    fail "the reason was swallowed" "$OUT"
fi
if echo "$OUT" | grep -q "pre_close_command failed (exit 3)"; then
    pass "the exit status is reported"
else
    fail "the exit status is not reported" "$OUT"
fi
if echo "$OUT" | grep -q "Nothing was closed"; then
    pass "close says nothing was closed"
else
    fail "close did not say it stopped" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
    pass "we are still on the feature branch"
else
    fail "close switched branches anyway" "$(git log --oneline -3)"
fi
if [[ "$(git rev-parse main)" == "$BEFORE" ]]; then
    pass "the base branch did not move"
else
    fail "the base branch moved" "$(git log --oneline -3 main)"
fi
# closed_at is written before the commit, so a refusal that happened after it
# would leave the ticket claiming to be closed on a branch that was not.
if grep -q '^closed_at: null' "tickets/${TICKET}/ticket.md"; then
    pass "closed_at was not stamped"
else
    fail "closed_at was stamped by a refused close" "$(head -10 "tickets/${TICKET}/ticket.md")"
fi

# ---------------------------------------------------------------------------
echo
echo "4. --force does not bypass it, and --dry-run shows it"
cd "$REPO"
OUT=$(timeout 20 ./ticket.sh close --force 2>&1)
RC=$?
if [[ $RC -ne 0 ]] && echo "$OUT" | grep -q "pre_close_command failed"; then
    pass "--force still refuses"
else
    fail "--force bypassed the check" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
    pass "--force merged nothing"
else
    fail "--force closed the ticket" "$(git log --oneline -3)"
fi
OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
RC=$?
if [[ $RC -ne 0 ]] && echo "$OUT" | grep -q "pre_close_command failed"; then
    pass "--dry-run reports the refusal"
else
    fail "--dry-run hid the refusal" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "5. the check is handed the ticket, not left to guess"
setup env-vars 'pre_close_command: "bash check.sh"' '#!/usr/bin/env bash
{
    echo "name=$TICKET_NAME"
    echo "dir=$TICKET_DIR"
    echo "file=$TICKET_FILE"
    echo "branch=$TICKET_BRANCH"
    echo "base=$TICKET_BASE_BRANCH"
    echo "cwd=$(pwd)"
} > seen.txt
exit 0'
cd "$REPO"
timeout 20 ./ticket.sh close --dry-run >/dev/null 2>&1
if [[ -f seen.txt ]]; then
    pass "the command ran"
else
    fail "the command did not run"
fi
SEEN=$(cat seen.txt 2>/dev/null)
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
if echo "$SEEN" | grep -q "^cwd=${REPO}$"; then
    pass "the command runs at the repo root"
else
    fail "the command ran somewhere else" "$SEEN"
fi

# A ticket that names its own base_branch is about to be merged somewhere else,
# and a check told "main" would measure against the wrong branch.
cd "$REPO"
git checkout -q main
git checkout -q -b release
git checkout -q "feature/${TICKET}"
sed_i "s|^base_branch: default.*|base_branch: release|" "tickets/${TICKET}/ticket.md"
git add -A && git commit -q -m "retarget"
rm -f seen.txt
timeout 20 ./ticket.sh close --dry-run >/dev/null 2>&1
if grep -q "^base=release$" seen.txt 2>/dev/null; then
    pass "TICKET_BASE_BRANCH follows the ticket's own base_branch"
else
    fail "TICKET_BASE_BRANCH ignored base_branch" "$(cat seen.txt 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
echo
echo "6. cancel never runs it"
setup cancelling 'pre_close_command: "bash check.sh"' '#!/usr/bin/env bash
echo "project check ran" > ran.txt
exit 3'
cd "$REPO"
OUT=$(timeout 20 ./ticket.sh cancel --force 2>&1)
RC=$?
if [[ ! -f ran.txt ]]; then
    pass "the check did not run"
else
    fail "cancel ran the close check" "$OUT"
fi
if [[ $RC -eq 0 ]]; then
    pass "cancel succeeded"
else
    fail "cancel failed" "$OUT"
fi
if ls tickets/done/*CANCELED* >/dev/null 2>&1; then
    pass "the ticket was filed as cancelled"
else
    fail "the ticket was not cancelled" "$(ls -R tickets)"
fi

# ---------------------------------------------------------------------------
echo
echo "7. in worktree mode it runs in the worktree, where the work is"
setup worktree 'pre_close_command: "bash check.sh"' '#!/usr/bin/env bash
{
    echo "cwd=$(pwd)"
    echo "dir_exists=$([[ -d "$TICKET_DIR" ]] && echo yes || echo no)"
} > "$(pwd)/seen.txt"
exit 0'
cd "$REPO"
# setup already started the ticket in-place; redo it as a worktree.
timeout 20 ./ticket.sh cancel --force >/dev/null 2>&1
printf '\nworktree_mode: true\n' >> .ticket-config.yaml
git add -A && git commit -q -m "worktree mode"
timeout 5 ./ticket.sh new wt >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*wt*")
git add tickets && git commit -q -m "Add ticket"
START_OUT=$(timeout 30 ./ticket.sh start "$TICKET" 2>&1)
# The WORKTREE: line reports a path built from the main repo plus "..", while a
# `pwd` from inside it comes back resolved. Resolve it here so the comparison
# below tests something.
WT_RAW=$(echo "$START_OUT" | grep "^WORKTREE:" | head -1 | cut -d: -f2-)
WT=$( (cd "$WT_RAW" 2>/dev/null && pwd -P) || echo "$WT_RAW" )
if [[ -n "$WT" ]] && [[ -d "$WT" ]]; then
    pass "the worktree was created"
else
    fail "no worktree" "$START_OUT"
fi
cd "$WT" || true
OUT=$(timeout 30 ./ticket.sh close --dry-run 2>&1)
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "close --dry-run passes from the worktree"
else
    fail "close refused from the worktree" "$OUT"
fi
if grep -q "^cwd=${WT}$" seen.txt 2>/dev/null; then
    pass "the check ran in the worktree, not the main checkout"
else
    fail "the check ran elsewhere" "$(cat seen.txt 2>/dev/null)"
fi
if grep -q "^dir_exists=yes$" seen.txt 2>/dev/null; then
    pass "TICKET_DIR resolves from there"
else
    fail "TICKET_DIR does not resolve in the worktree" "$(cat seen.txt 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
echo
echo "8. --no-merge: gated off the base branch, skipped on it"
setup no-merge 'pre_close_command: "bash check.sh"' '#!/usr/bin/env bash
echo "project check: not finished" >&2
exit 4'
cd "$REPO"
# On the feature branch there is still a close to refuse.
OUT=$(timeout 20 ./ticket.sh close --no-merge --no-push "$TICKET" 2>&1)
RC=$?
if [[ $RC -ne 0 ]] && echo "$OUT" | grep -q "pre_close_command failed (exit 4)"; then
    pass "--no-merge off the base branch refuses"
else
    fail "--no-merge ignored the check" "$OUT"
fi
if [[ ! -f "tickets/done/${TICKET}/ticket.md" ]]; then
    pass "the ticket stayed out of done/"
else
    fail "the ticket was filed anyway" "$(ls -R tickets)"
fi
# On the base branch the merge has already happened, so the gates do not apply -
# refusing there would strand the ticket outside done/ with nothing to do about it.
git checkout -q main
OUT=$(timeout 20 ./ticket.sh close --no-merge --no-push "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && ! echo "$OUT" | grep -q "Running pre_close_command"; then
    pass "--no-merge on the base branch does not run it"
else
    fail "--no-merge on the base branch ran the check" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "9. a legacy flat-layout ticket gets TICKET_FILE and an empty TICKET_DIR"
setup legacy 'pre_close_command: "bash check.sh"' '#!/usr/bin/env bash
{
    echo "dir=[$TICKET_DIR]"
    echo "file=$TICKET_FILE"
    echo "name=$TICKET_NAME"
} > seen.txt
exit 0'
cd "$REPO"
# Flatten the ticket the way a repo from an older version has it.
timeout 20 ./ticket.sh cancel --force >/dev/null 2>&1
LEGACY="251001-120000-flat"
mkdir -p tickets
cat > "tickets/${LEGACY}.md" << 'EOF'
---
priority: 2
description: "legacy flat ticket"
created_at: "2025-10-01T12:00:00Z"
started_at: null
closed_at: null
---

# Overview

flat
EOF
git add -A && git commit -q -m "legacy ticket"
timeout 20 ./ticket.sh start "$LEGACY" >/dev/null 2>&1
rm -f seen.txt
timeout 20 ./ticket.sh close --dry-run >/dev/null 2>&1
SEEN=$(cat seen.txt 2>/dev/null)
if echo "$SEEN" | grep -q "^dir=\[\]$"; then
    pass "TICKET_DIR is empty, because there is no directory"
else
    fail "TICKET_DIR was invented" "$SEEN"
fi
if echo "$SEEN" | grep -q "^file=tickets/${LEGACY}.md$"; then
    pass "TICKET_FILE points at the flat file"
else
    fail "TICKET_FILE is wrong" "$SEEN"
fi
if echo "$SEEN" | grep -q "^name=${LEGACY}$"; then
    pass "TICKET_NAME has no .md on it"
else
    fail "TICKET_NAME is wrong" "$SEEN"
fi

# ---------------------------------------------------------------------------
echo
echo "10. the check cannot derail the close around it"
setup contained 'pre_close_command: "bash check.sh"' '#!/usr/bin/env bash
# A check is one line of shell from another project. It may cd, it may leave
# variables behind, and it may be written in a style that `set -e` would read
# differently than its author did. Close is not entitled to care.
cd /
grep -q nothing-here /dev/null && echo "unreachable"
exit 0'
cd "$REPO"
OUT=$(timeout 20 ./ticket.sh close 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]]; then
    pass "a check that cd's away and ends on a false test still closes"
else
    fail "the check derailed the close" "$OUT"
fi
if [[ -f "tickets/done/${TICKET}/ticket.md" ]]; then
    pass "the ticket reached done/"
else
    fail "the ticket is not in done/" "$(ls -R tickets)"
fi

# ---------------------------------------------------------------------------
echo
echo "=== pre_close_command Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "$REPO_ROOT"
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
