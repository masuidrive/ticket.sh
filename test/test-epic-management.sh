#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This test requires bash. Run with 'bash test/test-epic-management.sh'"
    exit 1
fi

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Epic Management Tests ==="
echo

source "${SCRIPT_DIR}/test-helpers.sh"

PASS=0
FAIL=0

assert_ok() {
    local label="$1"
    if [[ $? -eq 0 ]]; then
        echo "   ✓ $label"
        PASS=$((PASS + 1))
    else
        echo "   ✗ $label"
        FAIL=$((FAIL + 1))
    fi
}

ok() {
    echo "   ✓ $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "   ✗ $1"
    FAIL=$((FAIL + 1))
}

start_test() {
    cd "${SCRIPT_DIR}/.."
    mkdir -p tmp
    local dir="tmp/test-epic-$1-$(date +%s)"
    setup_test_repo "$dir" >/dev/null 2>&1
    if git status --porcelain | grep -q .; then
        git add -A && git commit -q -m "test setup"
    fi
}

# ------------------------------------------------------------------
# Test 1: Happy path (epic-branch case)
# ------------------------------------------------------------------
echo "Test 1: Happy path (epic-branch case)"
start_test "happy-path"

./ticket.sh epic new alpha --title "Test alpha" >/dev/null 2>&1
if [[ -f epics/alpha.md ]]; then ok "epic file created at epics/alpha.md"; else fail "epic file missing"; fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "epic/alpha" ]]; then
    ok "checked out on epic/alpha"
else
    fail "branch should be epic/alpha, got $(git rev-parse --abbrev-ref HEAD)"
fi

# Create a ticket linked to the epic
./ticket.sh new feat-1 --epic alpha >/dev/null 2>&1
TICKET_NAME=$(safe_get_ticket_name "*-feat-1*")
TICKET_FILE=$(ticket_body_path "$TICKET_NAME")
if [[ -n "$TICKET_FILE" ]] && [[ -f "$TICKET_FILE" ]]; then
    ok "ticket file created"
    if grep -q '^epic_id: alpha' "$TICKET_FILE"; then ok "ticket has epic_id: alpha"; else fail "ticket missing epic_id"; fi
    if grep -q '^base_branch: epic/alpha' "$TICKET_FILE"; then ok "ticket has base_branch: epic/alpha"; else fail "ticket missing base_branch"; fi
else
    fail "ticket file not found"
fi

# Drive ticket through start/work/close
git add -A && git commit -q -m "add ticket"
./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1
git add -A && git commit -q -m "start"
mkdir -p src && echo "feature" > src/feat.js
git add . && git commit -q -m "work"
./ticket.sh close --no-push >/dev/null 2>&1

# We should be back on epic/alpha after close (since base_branch was epic/alpha)
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "epic/alpha" ]]; then
    ok "after ticket close, back on epic/alpha"
else
    fail "expected epic/alpha after close, got $(git rev-parse --abbrev-ref HEAD)"
fi

# Close the epic
./ticket.sh epic close alpha --no-push --no-delete-remote >/dev/null 2>&1
if [[ -f epics/done/alpha/index.md ]]; then ok "epics/done/alpha/index.md exists"; else fail "epics/done not created"; fi
if grep -q '^status: closed' epics/done/alpha/index.md 2>/dev/null; then ok "status: closed in done file"; else fail "status not closed"; fi
if [[ -f src/feat.js ]]; then ok "feature file present on main"; else fail "feature file missing"; fi
if git rev-parse --verify refs/heads/epic/alpha >/dev/null 2>&1; then
    fail "epic/alpha branch should be deleted"
else
    ok "epic/alpha branch deleted"
fi

echo

# ------------------------------------------------------------------
# Test 2: Cancel discards impl
# ------------------------------------------------------------------
echo "Test 2: Cancel discards impl"
start_test "cancel"

./ticket.sh epic new beta-doomed >/dev/null 2>&1
echo "wip" > beta-feature.js
git add . && git commit -q -m "wip"
./ticket.sh epic cancel beta-doomed --reason "scope changed" --no-push --no-delete-remote >/dev/null 2>&1

git switch main 2>/dev/null || git checkout main 2>/dev/null

if [[ ! -f beta-feature.js ]]; then ok "impl file NOT on main"; else fail "impl file leaked to main"; fi
if grep -q 'cancel_reason: "scope changed"' epics/done/beta-doomed/index.md 2>/dev/null; then
    ok "cancel_reason recorded"
else
    fail "cancel_reason not recorded properly"
    cat epics/done/beta-doomed/index.md 2>&1 | head -15
fi
if grep -q '^status: cancelled' epics/done/beta-doomed/index.md 2>/dev/null; then ok "status: cancelled"; else fail "status not cancelled"; fi

echo

# ------------------------------------------------------------------
# Test 3: Preflight blockers
# ------------------------------------------------------------------
echo "Test 3: Preflight blockers"
start_test "preflight"

./ticket.sh epic new gamma >/dev/null 2>&1
./ticket.sh new still-open --epic gamma >/dev/null 2>&1
git add tickets && git commit -q -m "new ticket"

# Without --force should fail
if ./ticket.sh epic close gamma --no-push 2>&1 | grep -q "open ticket"; then
    ok "preflight blocks on open linked ticket"
else
    fail "preflight did not detect open ticket"
fi

# With --force should succeed
if ./ticket.sh epic close gamma --no-push --no-delete-remote --force >/dev/null 2>&1; then
    ok "--force overrides preflight blocker"
else
    fail "--force did not override blocker"
fi

echo

# ------------------------------------------------------------------
# Test 4: Dirty tree refusal
# ------------------------------------------------------------------
echo "Test 4: Dirty tree refusal"
start_test "dirty"

./ticket.sh epic new delta >/dev/null 2>&1
echo stale > untracked.txt

# epic close should refuse with dirty tree (preflight blocker)
out=$(./ticket.sh epic close delta --no-push 2>&1 || true)
if echo "$out" | grep -qi "dirty"; then
    ok "preflight blocks on dirty tree"
else
    fail "preflight did not detect dirty tree"
    echo "    output: $out"
fi

rm -f untracked.txt
echo

# ------------------------------------------------------------------
# Test 5: epic list and epic show JSON
# ------------------------------------------------------------------
echo "Test 5: list / show output"
start_test "list-show"

./ticket.sh epic new echo-epic --title "Echo test" >/dev/null 2>&1
git switch main 2>/dev/null || git checkout main 2>/dev/null

if ./ticket.sh epic list 2>&1 | grep -q "echo-epic"; then ok "epic list shows the epic"; else fail "epic list missing epic"; fi

JSON=$(./ticket.sh epic list --json 2>/dev/null)
if echo "$JSON" | grep -q '"epic_id":"echo-epic"'; then ok "list --json contains epic_id"; else fail "list --json missing epic_id"; fi
if echo "$JSON" | grep -q '"title":"Echo test"'; then ok "list --json contains title"; else fail "list --json missing title"; fi

SHOW=$(./ticket.sh epic show echo-epic --json 2>/dev/null)
if echo "$SHOW" | grep -q '"epic_id":"echo-epic"'; then ok "show --json contains epic_id"; else fail "show --json missing epic_id"; fi
if echo "$SHOW" | grep -q '"branch":"epic/echo-epic"'; then ok "show --json branch field"; else fail "show --json missing branch"; fi

echo

# ------------------------------------------------------------------
# Test 6: regression — `epic show --json` with non-empty linked_tickets
# parses as valid JSON (was truncating mid-array under set -e because
# get_yaml_field returned 1 inside var=$(...); see gist comment #6142039).
# ------------------------------------------------------------------
echo "Test 6: epic show --json with linked tickets is valid JSON"
start_test "show-json-linked"

./ticket.sh epic new gamma >/dev/null 2>&1
git switch main 2>/dev/null
./ticket.sh new linked-feat --epic gamma >/dev/null 2>&1
git add tickets && git commit -q -m "add ticket"

./ticket.sh epic show gamma --json > /tmp/_epic_show.json 2>/dev/null
if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json; d=json.load(open('/tmp/_epic_show.json')); assert isinstance(d['linked_tickets'], list); assert len(d['linked_tickets']) == 1" 2>/dev/null; then
        ok "JSON parses with non-empty linked_tickets"
    else
        fail "JSON parse failed (truncated or malformed)"
    fi
else
    # Fallback: at least the closing brace must be present at EOF.
    if tail -c 5 /tmp/_epic_show.json | grep -q '}}'; then
        ok "JSON looks complete (no python3 for full parse)"
    else
        fail "JSON appears truncated"
    fi
fi
rm -f /tmp/_epic_show.json
echo

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "  Summary - Passed: $PASS, Failed: $FAIL"

if [[ $FAIL -gt 0 ]]; then exit 1; fi
exit 0
