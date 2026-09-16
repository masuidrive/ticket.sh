#!/usr/bin/env bash

# Test for close --no-merge option (finalize a PR that was already merged)

# Source helper functions
source "$(dirname "$0")/test-helpers.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_DIR="tmp/test-close-no-merge-$(date +%s)"

echo -e "${YELLOW}=== Testing close --no-merge option ===${NC}"
echo

PASS=0
FAIL=0
test_result() {
    if [[ $1 -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} $2"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $2"
        [[ -n "${3:-}" ]] && echo "    Details: $3"
        FAIL=$((FAIL + 1))
    fi
}

mkdir -p tmp
setup_test_repo "$TEST_DIR"

# A no-merge finalize runs on the base branch; the ticket file is committed
# there directly (simulating the state after a GitHub PR merge).
create_ticket_on_main() {
    local slug="$1"
    timeout 5 ./ticket.sh new "$slug" >/dev/null 2>&1
    # Commit ticket files AND the config so the working tree is clean
    # before finalize (mirrors a real base branch after a PR merge).
    git add tickets .ticket-config.yaml >/dev/null 2>&1
    git commit -q -m "add ticket $slug"
    safe_get_ticket_name "*${slug}.md"
}

echo "1. Testing --no-merge with explicit --closed-at..."
TICKET=$(create_ticket_on_main "merged-feature")
BEFORE_BRANCH=$(git branch --show-current)
OUT=$(timeout 10 ./ticket.sh close --no-merge --no-push --closed-at "2026-05-29T12:17:36Z" "$TICKET" 2>&1)
AFTER_BRANCH=$(git branch --show-current)

DONE_TICKET=$(ticket_body_path "$TICKET" --done)
if [[ -n "$DONE_TICKET" ]]; then
    test_result 0 "Ticket moved to done/ ($DONE_TICKET)"
else
    test_result 1 "Ticket should be moved to done/" "$OUT"
fi

if [[ -n "$DONE_TICKET" ]] && grep -q 'closed_at: 2026-05-29T12:17:36Z' "$DONE_TICKET"; then
    test_result 0 "closed_at set to the provided value"
else
    test_result 1 "closed_at should equal --closed-at value" "$(grep closed_at "$DONE_TICKET" 2>/dev/null)"
fi

# Regression: closed_at must be in the COMMIT, not just the working tree.
if [[ -n "$DONE_TICKET" ]] && git show "HEAD:$DONE_TICKET" 2>/dev/null | grep -q 'closed_at: 2026-05-29T12:17:36Z'; then
    test_result 0 "closed_at is committed (HEAD), not left in working tree"
else
    test_result 1 "closed_at should be committed at HEAD" "$(git show HEAD:$DONE_TICKET 2>/dev/null | grep closed_at)"
fi

# Regression: working tree must be clean after finalize.
STATUS_OUT=$(git status --short)
if [[ -z "$STATUS_OUT" ]]; then
    test_result 0 "Working tree is clean after finalize"
else
    test_result 1 "Working tree should be clean after finalize" "$STATUS_OUT"
fi

# Regression: note must be moved to done/ in the same commit as the ticket.
# Legacy layout uses tickets/done/<name>-note.md; new layout uses tickets/done/<name>/note.md.
if git show --name-status HEAD | grep -qE "tickets/done/${TICKET}(-note\.md|/note\.md)"; then
    test_result 0 "Note moved to done/ in the finalize commit"
else
    test_result 1 "Note should be moved to done/ in the same commit" "$(git show --name-status HEAD | grep -i note)"
fi

if [[ "$BEFORE_BRANCH" == "$AFTER_BRANCH" ]]; then
    test_result 0 "Branch unchanged (no merge/checkout): $AFTER_BRANCH"
else
    test_result 1 "Branch should be unchanged" "before=$BEFORE_BRANCH after=$AFTER_BRANCH"
fi

# A no-merge finalize must not create or switch to a feature branch.
if ! git show-ref --verify --quiet "refs/heads/feature/${TICKET}"; then
    test_result 0 "No feature branch created"
else
    test_result 1 "Should not create a feature branch"
fi

echo -e "\n2. Testing --no-merge without --closed-at (defaults to now-UTC)..."
TICKET2=$(create_ticket_on_main "merged-feature-2")
NOW_PREFIX=$(date -u '+%Y-%m-%dT%H:%M')
timeout 10 ./ticket.sh close --no-merge --no-push "$TICKET2" >/dev/null 2>&1
DONE_TICKET2=$(ticket_body_path "$TICKET2" --done)
CLOSED_LINE=$(git show "HEAD:$DONE_TICKET2" 2>/dev/null | grep closed_at)
if echo "$CLOSED_LINE" | grep -q "closed_at: ${NOW_PREFIX}"; then
    test_result 0 "closed_at defaults to current UTC time (committed at HEAD)"
else
    test_result 1 "closed_at should default to now-UTC ($NOW_PREFIX) and be committed" "$CLOSED_LINE"
fi

if [[ -z "$(git status --short)" ]]; then
    test_result 0 "Working tree clean after default-time finalize"
else
    test_result 1 "Working tree should be clean (default-time finalize)" "$(git status --short)"
fi

echo -e "\n3. Testing idempotency (already finalized)..."
OUT=$(timeout 10 ./ticket.sh close --no-merge --no-push "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -qi "already finalized"; then
    test_result 0 "Already-finalized ticket is a no-op (exit 0)"
else
    test_result 1 "Re-finalizing should exit 0 and report already finalized" "rc=$RC out=$OUT"
fi

echo -e "\n4. Testing error: nonexistent ticket..."
if ! timeout 10 ./ticket.sh close --no-merge --no-push "does-not-exist" >/dev/null 2>&1; then
    test_result 0 "Nonexistent ticket fails with non-zero exit"
else
    test_result 1 "Nonexistent ticket should fail"
fi

echo -e "\n5. Testing error: missing <ticket-name>..."
OUT=$(timeout 10 ./ticket.sh close --no-merge --no-push 2>&1)
if [[ $? -ne 0 ]] && echo "$OUT" | grep -q "required with --no-merge"; then
    test_result 0 "Missing ticket-name fails with a clear error"
else
    test_result 1 "Missing ticket-name should fail" "$OUT"
fi

echo -e "\n6. Testing error: invalid --closed-at format..."
OUT=$(timeout 10 ./ticket.sh close --no-merge --no-push --closed-at "2026-05-29" "$TICKET" 2>&1)
if [[ $? -ne 0 ]] && echo "$OUT" | grep -q "ISO8601"; then
    test_result 0 "Invalid --closed-at fails and shows expected format"
else
    test_result 1 "Invalid --closed-at should fail" "$OUT"
fi

echo -e "\n7. Testing error: <ticket-name> without --no-merge..."
OUT=$(timeout 10 ./ticket.sh close "$TICKET" 2>&1)
if [[ $? -ne 0 ]] && echo "$OUT" | grep -q "only valid with --no-merge"; then
    test_result 0 "Positional ticket-name rejected without --no-merge"
else
    test_result 1 "Positional ticket-name should require --no-merge" "$OUT"
fi

# ---------------------------------------------------------------------------
# The gates (issue #10).
#
# --no-merge was written for the run that happens on the base branch after a PR
# has been merged, and skipped the checklist / append-only gates because there
# is nothing left to measure there. The same command now also runs BEFORE the
# PR exists, on the ticket's own branch - a workflow token cannot push to a
# protected default branch, so the move into done/ has to ride in on the PR.
# There the gates are measurable, and skipping them let a gate that refuses
# --force be walked around by changing where close was called from, silently.
echo -e "\n8. Testing gates on the ticket's own branch..."

cd ..
rm -rf "$TEST_DIR"
TEST_DIR="tmp/test-close-no-merge-gates-$(date +%s)"
setup_test_repo "$TEST_DIR"

sed_i 's/^require_checklist: false/require_checklist: true/' .ticket-config.yaml
cat >> .ticket-config.yaml << 'CFGEOF'

ticket_files:
  - path: progress.md
    content: |
      # Progress: $$TICKET_NAME$$
append_only_files:
  - progress.md
CFGEOF
git add -A && git commit -q -m "Turn the gates on"

timeout 5 ./ticket.sh new gated >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*gated*")
git add tickets && git commit -q -m "add ticket"
timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1

# The stock template's Tasks list is unchecked, so require_checklist bites.
OUT=$(timeout 20 ./ticket.sh close --no-merge --no-push "$TICKET" 2>&1)
RC=$?
if [[ $RC -ne 0 ]] && echo "$OUT" | grep -q "unchecked items remain"; then
    test_result 0 "an unchecked checklist refuses --no-merge on a feature branch"
else
    test_result 1 "--no-merge ignored the checklist" "$OUT"
fi
if [[ -z "$(ticket_body_path "$TICKET" --done)" ]]; then
    test_result 0 "nothing was moved to done/"
else
    test_result 1 "the ticket was finalized despite the gate" "$OUT"
fi
if git diff --quiet && git diff --cached --quiet; then
    test_result 0 "nothing was written before the refusal"
else
    test_result 1 "the tree was touched before the gate refused" "$(git status --porcelain)"
fi

# --dry-run used to be accepted and silently ignored alongside --no-merge.
OUT=$(timeout 20 ./ticket.sh close --no-merge --dry-run "$TICKET" 2>&1)
if [[ $? -ne 0 ]] && echo "$OUT" | grep -q "unchecked items remain"; then
    test_result 0 "--dry-run surfaces the refusal"
else
    test_result 1 "--dry-run did not show the gate" "$OUT"
fi

# Settle the checklists; the append-only file is still intact, so it passes.
# sed, not python3/perl: Alpine has neither, and a rewrite that silently does
# nothing would leave the assertions below failing for the wrong reason.
for _f in "tickets/${TICKET}/ticket.md" "tickets/${TICKET}/note.md"; do
    [[ -f "$_f" ]] && sed_i 's/- \[ \]/- [x]/g' "$_f"
done
if grep -rq -- '- \[ \]' "tickets/${TICKET}/"; then
    test_result 1 "test setup: checklists were not settled" "$(grep -rn -- '- \[ \]' "tickets/${TICKET}/")"
fi
git add -A && git commit -q -m "Settle the checklists"

OUT=$(timeout 20 ./ticket.sh close --no-merge --dry-run "$TICKET" 2>&1)
if [[ $? -eq 0 ]] && echo "$OUT" | grep -q "gates:          applied"; then
    test_result 0 "a settled ticket passes, and says the gates were applied"
else
    test_result 1 "a settled ticket was still refused" "$OUT"
fi

# Now break the append-only file.
printf -- '- a line I will remove\n' >> "tickets/${TICKET}/progress.md"
git add -A && git commit -q -m "progress: note it"
grep -v -F -x -- '- a line I will remove' "tickets/${TICKET}/progress.md" > "tickets/${TICKET}/progress.md.new"
mv "tickets/${TICKET}/progress.md.new" "tickets/${TICKET}/progress.md"
git add -A && git commit -q -m "progress: remove it"

OUT=$(timeout 20 ./ticket.sh close --no-merge --no-push "$TICKET" 2>&1)
if [[ $? -ne 0 ]] && echo "$OUT" | grep -q "Append-only file is missing lines"; then
    test_result 0 "a lost append-only line refuses --no-merge too"
else
    test_result 1 "--no-merge ignored append_only_files" "$OUT"
fi

# ---------------------------------------------------------------------------
echo -e "\n9. Testing that the base branch still skips the gates..."
# After the PR has merged, the gates are deliberately not applied: refusing then
# would strand the ticket outside done/ without giving anyone a useful action.
git checkout -q main
git merge -q --no-edit "$(git rev-parse --abbrev-ref '@{-1}')" >/dev/null 2>&1

# Put the ticket back into the state the gates would refuse.
sed_i 's/- \[x\]/- [ ]/g' "tickets/${TICKET}/ticket.md"
if ! grep -q -- '- \[ \]' "tickets/${TICKET}/ticket.md"; then
    test_result 1 "test setup: the ticket was not un-checked again" "$(head -30 "tickets/${TICKET}/ticket.md")"
fi
git add -A && git commit -q -m "on main: unchecked again"

OUT=$(timeout 20 ./ticket.sh close --no-merge --dry-run "$TICKET" 2>&1)
if [[ $? -eq 0 ]] && echo "$OUT" | grep -q "gates:          skipped"; then
    test_result 0 "on the base branch the gates are skipped"
else
    test_result 1 "the base branch applied the gates" "$OUT"
fi

OUT=$(timeout 20 ./ticket.sh close --no-merge --no-push "$TICKET" 2>&1)
if [[ $? -eq 0 ]] && [[ -n "$(ticket_body_path "$TICKET" --done)" ]]; then
    test_result 0 "and the ticket is finalized as before"
else
    test_result 1 "finalizing on the base branch broke" "$OUT"
fi

# ---------------------------------------------------------------------------
echo -e "\n10. Testing that undeclared gates change nothing..."
cd ..
rm -rf "$TEST_DIR"
TEST_DIR="tmp/test-close-no-merge-ungated-$(date +%s)"
setup_test_repo "$TEST_DIR"

timeout 5 ./ticket.sh new ungated >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*ungated*")
git add tickets .ticket-config.yaml && git commit -q -m "add ticket"
timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1

# Stock config: require_checklist false, no groups, no append_only_files. The
# template's Tasks list is unchecked and that must still be fine.
OUT=$(timeout 20 ./ticket.sh close --no-merge --no-push "$TICKET" 2>&1)
if [[ $? -eq 0 ]] && [[ -n "$(ticket_body_path "$TICKET" --done)" ]]; then
    test_result 0 "with no gate configured, a feature branch finalizes as before"
else
    test_result 1 "an unconfigured gate blocked --no-merge" "$OUT"
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo
echo -e "${YELLOW}=== close --no-merge Test Results ===${NC}"
echo -e "  Passed: ${GREEN}${PASS}${NC}, Failed: ${RED}${FAIL}${NC}"

[[ $FAIL -eq 0 ]]
