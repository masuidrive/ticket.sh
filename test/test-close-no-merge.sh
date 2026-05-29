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
        ((PASS++))
    else
        echo -e "  ${RED}✗${NC} $2"
        [[ -n "${3:-}" ]] && echo "    Details: $3"
        ((FAIL++))
    fi
}

mkdir -p tmp
setup_test_repo "$TEST_DIR"

# A no-merge finalize runs on the base branch; the ticket file is committed
# there directly (simulating the state after a GitHub PR merge).
create_ticket_on_main() {
    local slug="$1"
    timeout 5 ./ticket.sh new "$slug" >/dev/null 2>&1
    git add tickets >/dev/null 2>&1
    git commit -q -m "add ticket $slug"
    safe_get_ticket_name "*${slug}.md"
}

echo "1. Testing --no-merge with explicit --closed-at..."
TICKET=$(create_ticket_on_main "merged-feature")
BEFORE_BRANCH=$(git branch --show-current)
OUT=$(timeout 10 ./ticket.sh close --no-merge --no-push --closed-at "2026-05-29T12:17:36Z" "$TICKET" 2>&1)
AFTER_BRANCH=$(git branch --show-current)

if [[ -f "tickets/done/${TICKET}.md" ]]; then
    test_result 0 "Ticket moved to done/"
else
    test_result 1 "Ticket should be moved to done/" "$OUT"
fi

if grep -q 'closed_at: 2026-05-29T12:17:36Z' "tickets/done/${TICKET}.md" 2>/dev/null; then
    test_result 0 "closed_at set to the provided value"
else
    test_result 1 "closed_at should equal --closed-at value" "$(grep closed_at tickets/done/${TICKET}.md 2>/dev/null)"
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
CLOSED_LINE=$(grep closed_at "tickets/done/${TICKET2}.md" 2>/dev/null)
if echo "$CLOSED_LINE" | grep -q "closed_at: ${NOW_PREFIX}"; then
    test_result 0 "closed_at defaults to current UTC time"
else
    test_result 1 "closed_at should default to now-UTC ($NOW_PREFIX)" "$CLOSED_LINE"
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

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo
echo -e "${YELLOW}=== close --no-merge Test Results ===${NC}"
echo -e "  Passed: ${GREEN}${PASS}${NC}, Failed: ${RED}${FAIL}${NC}"

[[ $FAIL -eq 0 ]]
