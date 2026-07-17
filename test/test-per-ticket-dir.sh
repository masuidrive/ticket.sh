#!/usr/bin/env bash

# Test for per-ticket directory layout:
#   new    → tickets/<TICKETNAME>/{ticket.md,note.md}
#   start  → current-ticket/ (dir symlink) + current-ticket.md + current-note.md
#   close  → git mv of whole directory into tickets/done/<TICKETNAME>/,
#            closed_at committed at HEAD, working tree clean
#   cancel → git mv of whole directory to tickets/done/<CANCELED-NAME>/,
#            cancelled_at + [CANCELED] description committed
#   list   → shows both new-format and legacy-format tickets
#   restore→ rebuilds current-ticket/ + compat symlinks
#   legacy → pre-existing flat tickets still work end-to-end

source "$(dirname "$0")/test-helpers.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_DIR="tmp/test-per-ticket-dir-$(date +%s)"

echo -e "${YELLOW}=== Testing per-ticket directory layout ===${NC}"
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

# Commit .gitignore + config produced by init so the working tree is clean
# before any ticket operation.
git add .gitignore .ticket-config.yaml tickets >/dev/null 2>&1
git commit -q -m "init tickets"

echo "1. Testing new creates per-ticket directory..."
timeout 5 ./ticket.sh new dir-layout-feature >/dev/null 2>&1
TICKET=$(ls -d tickets/*-dir-layout-feature 2>/dev/null | head -1 | sed 's|^tickets/||')

if [[ -n "$TICKET" ]] && [[ -d "tickets/${TICKET}" ]]; then
    test_result 0 "tickets/<TICKETNAME>/ directory created"
else
    test_result 1 "tickets/<TICKETNAME>/ directory should exist"
fi
[[ -f "tickets/${TICKET}/ticket.md" ]] && test_result 0 "ticket.md exists inside the directory" || test_result 1 "ticket.md missing"
[[ -f "tickets/${TICKET}/note.md" ]] && test_result 0 "note.md exists inside the directory" || test_result 1 "note.md missing"
# No flat file should be produced.
if [[ ! -f "tickets/${TICKET}.md" ]] && [[ ! -f "tickets/${TICKET}-note.md" ]]; then
    test_result 0 "no legacy flat files were created"
else
    test_result 1 "legacy flat files should NOT be created by new"
fi

# Commit the ticket so start's clean-working-dir check passes.
git add tickets && git commit -q -m "add new-format ticket ${TICKET}"

echo -e "\n2. Testing start creates dir symlink + compat file symlinks..."
START_OUT=$(timeout 10 ./ticket.sh start "$TICKET" 2>&1)

if [[ -L "current-ticket" ]]; then
    test_result 0 "current-ticket dir symlink created"
    LINK_TARGET=$(readlink current-ticket)
    if [[ "$LINK_TARGET" == "tickets/${TICKET}" ]]; then
        test_result 0 "current-ticket -> tickets/<TICKETNAME>"
    else
        test_result 1 "current-ticket should point at tickets/<TICKETNAME>" "$LINK_TARGET"
    fi
else
    test_result 1 "current-ticket dir symlink should exist"
fi

[[ -L "current-ticket.md" ]] && test_result 0 "current-ticket.md compat symlink created" || test_result 1 "current-ticket.md missing"
[[ -L "current-note.md" ]]   && test_result 0 "current-note.md compat symlink created"   || test_result 1 "current-note.md missing"

# Reachability through the dir symlink
[[ -f "current-ticket/ticket.md" ]] && test_result 0 "current-ticket/ticket.md reachable" || test_result 1 "current-ticket/ticket.md not reachable"
[[ -f "current-ticket/note.md" ]]   && test_result 0 "current-ticket/note.md reachable"   || test_result 1 "current-ticket/note.md not reachable"

# .gitignore excludes the new symlink name so start doesn't dirty the tree
if grep -q "^current-ticket$" .gitignore; then
    test_result 0 ".gitignore excludes current-ticket"
else
    test_result 1 ".gitignore should exclude current-ticket"
fi

# start must emit the "Active ticket paths" block with resolved paths for a
# new-format ticket. A downstream agent must be able to consume this output
# alone (no format guessing) to find the ticket body, note, dir, and symlinks.
if echo "$START_OUT" | grep -q "^Active ticket paths:$"; then
    test_result 0 "start emits 'Active ticket paths:' block"
else
    test_result 1 "start must emit 'Active ticket paths:' block" "$START_OUT"
fi
for KEY in "layout:       new" \
           "ticket:       tickets/${TICKET}/ticket.md" \
           "note:         tickets/${TICKET}/note.md" \
           "ticket_dir:   tickets/${TICKET}/" \
           "tests_dir:    tickets/${TICKET}/tests/" \
           "tmp_dir:      tickets/${TICKET}/tmp/" \
           "symlink_dir:  ./current-ticket -> tickets/${TICKET}" \
           "symlink_file: ./current-ticket.md -> tickets/${TICKET}/ticket.md" \
           "symlink_note: ./current-note.md -> tickets/${TICKET}/note.md"; do
    if echo "$START_OUT" | grep -qF "$KEY"; then
        test_result 0 "start info block contains: ${KEY%% *}..."
    else
        test_result 1 "start info block missing: $KEY" \
            "$(echo "$START_OUT" | grep -A15 'Active ticket paths')"
    fi
done

echo -e "\n3. Testing close moves whole directory + closed_at committed..."
# start left started_at edit uncommitted → commit it before close so close's
# clean-working-dir check passes.
git add tickets && git commit -q -m "start ${TICKET}"

CLOSE_OUT=$(timeout 15 ./ticket.sh close --no-push --no-delete-remote --keep-worktree 2>&1)

# Whole ticket directory should be gone from tickets/, present in done/
if [[ ! -d "tickets/${TICKET}" ]] && [[ -d "tickets/done/${TICKET}" ]]; then
    test_result 0 "ticket directory moved to tickets/done/${TICKET}/"
else
    test_result 1 "ticket directory should live under tickets/done/" "$CLOSE_OUT"
fi

# closed_at must be at HEAD (not just working tree)
if git show "HEAD:tickets/done/${TICKET}/ticket.md" 2>/dev/null | grep -qE 'closed_at: 20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9:Z]+'; then
    test_result 0 "closed_at committed at HEAD (not left in working tree)"
else
    test_result 1 "closed_at should be committed at HEAD" \
        "$(git show HEAD:tickets/done/${TICKET}/ticket.md 2>/dev/null | grep closed_at || echo 'no HEAD entry')"
fi

# note.md must be in the same commit
if git show --name-status HEAD 2>/dev/null | grep -q "tickets/done/${TICKET}/note.md"; then
    test_result 0 "note.md included in the finalize commit"
else
    test_result 1 "note.md should be in the finalize commit"
fi

# Working tree must be clean
if [[ -z "$(git status --short)" ]]; then
    test_result 0 "working tree is clean after close"
else
    test_result 1 "working tree should be clean after close" "$(git status --short)"
fi

# All 3 current-* symlinks should be gone
if [[ ! -e "current-ticket" ]] && [[ ! -L "current-ticket" ]] && \
   [[ ! -e "current-ticket.md" ]] && [[ ! -L "current-ticket.md" ]] && \
   [[ ! -e "current-note.md" ]] && [[ ! -L "current-note.md" ]]; then
    test_result 0 "all current-* symlinks removed"
else
    test_result 1 "current-* symlinks should be removed after close" \
        "$(ls -la current* 2>&1 | head -5)"
fi

echo -e "\n4. Testing list shows new-format ticket (both open and done)..."
# Re-create an open ticket so list has both open and done.
timeout 5 ./ticket.sh new list-check-feature >/dev/null 2>&1
TICKET_OPEN=$(ls -d tickets/*-list-check-feature 2>/dev/null | head -1 | sed 's|^tickets/||')
git add tickets && git commit -q -m "add list-check ticket"
LIST_TODO=$(timeout 10 ./ticket.sh list --status todo 2>&1)
LIST_DONE=$(timeout 10 ./ticket.sh list --status done 2>&1)

if echo "$LIST_TODO" | grep -q "tickets/${TICKET_OPEN}/ticket.md"; then
    test_result 0 "list --status todo shows new-format open ticket"
else
    test_result 1 "list --status todo should show new-format open ticket" "$LIST_TODO"
fi
if echo "$LIST_DONE" | grep -q "tickets/done/${TICKET}/ticket.md"; then
    test_result 0 "list --status done shows new-format closed ticket"
else
    test_result 1 "list --status done should show new-format closed ticket" "$LIST_DONE"
fi

echo -e "\n5. Testing cancel moves dir with CANCELED prefix..."
# cancel needs to be on the ticket's feature branch → start the open ticket.
git checkout -q main
timeout 10 ./ticket.sh start "$TICKET_OPEN" >/dev/null 2>&1
git add tickets && git commit -q -m "start ${TICKET_OPEN}"
CANCEL_OUT=$(timeout 15 ./ticket.sh cancel --keep-worktree 2>&1)

# CANCELED prefix should be inserted after the YYMMDD-hhmmss- timestamp
CANCELED_DIR=$(ls -d "tickets/done/"*"-CANCELED-list-check-feature" 2>/dev/null | head -1)
if [[ -n "$CANCELED_DIR" ]]; then
    test_result 0 "canceled ticket moved to tickets/done/<...-CANCELED-...>/"
else
    test_result 1 "canceled ticket directory not found under done/" "$CANCEL_OUT"
fi

if [[ -f "$CANCELED_DIR/ticket.md" ]] && grep -qE '^description: "?\[CANCELED\]' "$CANCELED_DIR/ticket.md"; then
    test_result 0 "canceled ticket has [CANCELED] description prefix"
else
    test_result 1 "canceled ticket should have [CANCELED] description prefix" \
        "$(grep description "$CANCELED_DIR/ticket.md" 2>/dev/null | head -1)"
fi
# cancelled_at must be at HEAD
if git show "HEAD:${CANCELED_DIR}/ticket.md" 2>/dev/null | grep -qE 'canceled_at: 20[0-9]{2}-'; then
    test_result 0 "canceled_at committed at HEAD"
else
    test_result 1 "canceled_at should be committed at HEAD"
fi

echo -e "\n6. Testing restore rebuilds symlinks for new-format ticket..."
# On the feature branch of the closed ticket, restore should rebuild the dir symlink.
# The first ticket (dir-layout-feature) was closed → its branch was merged but the
# feature branch still exists locally. Switch to it and restore.
git checkout -q "feature/${TICKET}"
# Blow away any lingering symlinks first.
rm -f current-ticket.md current-note.md
rm -rf current-ticket

RESTORE_OUT=$(timeout 10 ./ticket.sh restore 2>&1)

# For a ticket whose files are in done/, restore should still create the file
# compat symlink (no dir symlink for done/, since the "open" per-ticket dir
# doesn't exist there).
if [[ -L "current-ticket.md" ]]; then
    test_result 0 "restore recreates current-ticket.md for done-side new-format ticket"
else
    test_result 1 "restore should recreate current-ticket.md" "$RESTORE_OUT"
fi

# restore must ALSO emit the "Active ticket paths" block so a downstream
# agent can act on its output alone (same contract as start).
if echo "$RESTORE_OUT" | grep -q "^Active ticket paths:$"; then
    test_result 0 "restore emits 'Active ticket paths:' block"
else
    test_result 1 "restore must emit 'Active ticket paths:' block" "$RESTORE_OUT"
fi
# restore is being run on the feature branch, which never got the mv-to-done
# commit (that happened only on main during close). On the feature branch,
# the ticket dir is still at tickets/<T>/. The info block must resolve to
# that actually-present path — not fabricate a done/ path that doesn't exist
# on this branch.
if echo "$RESTORE_OUT" | grep -qF "ticket:       tickets/${TICKET}/ticket.md"; then
    test_result 0 "restore info block resolves to the actually-present ticket path on this branch"
else
    test_result 1 "restore info block should resolve to the ticket path present on this branch" \
        "$(echo "$RESTORE_OUT" | grep -A10 'Active ticket paths')"
fi

echo -e "\n7. Testing legacy flat tickets still work end-to-end..."
git checkout -q main

# Hand-craft a legacy flat ticket (as if it pre-existed the layout change).
LEGACY_NAME="240101-000000-legacy-flat"
cat > "tickets/${LEGACY_NAME}.md" <<LEGACY
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
cat > "tickets/${LEGACY_NAME}-note.md" <<'LEGACY'
Legacy note.
LEGACY
git add tickets && git commit -q -m "add legacy flat ticket"

# list should include it (mix of layouts)
LIST_ALL=$(timeout 10 ./ticket.sh list --status todo 2>&1)
if echo "$LIST_ALL" | grep -q "tickets/${LEGACY_NAME}.md"; then
    test_result 0 "list includes legacy flat ticket alongside new-format"
else
    test_result 1 "list should include legacy flat ticket" "$LIST_ALL"
fi

# start on a legacy ticket
LEGACY_START_OUT=$(timeout 10 ./ticket.sh start "$LEGACY_NAME" 2>&1)
if [[ -L "current-ticket.md" ]] && [[ "$(readlink current-ticket.md)" == "tickets/${LEGACY_NAME}.md" ]]; then
    test_result 0 "start on legacy ticket sets current-ticket.md -> flat path"
else
    test_result 1 "start on legacy ticket should point current-ticket.md at flat path" \
        "$(readlink current-ticket.md 2>/dev/null)"
fi
# For legacy tickets, there is NO current-ticket/ directory symlink
if [[ ! -e "current-ticket" ]] && [[ ! -L "current-ticket" ]]; then
    test_result 0 "start on legacy ticket does not create current-ticket/ dir symlink"
else
    test_result 1 "current-ticket/ dir symlink should not exist for legacy tickets"
fi

# start on a legacy ticket must emit an info block that explicitly identifies
# the layout as "legacy" and shows resolved flat paths (no tests_dir/tmp_dir
# lines, and a legacy_note line explaining the flat convention).
for KEY in "layout:       legacy" \
           "ticket:       tickets/${LEGACY_NAME}.md" \
           "note:         tickets/${LEGACY_NAME}-note.md" \
           "symlink_file: ./current-ticket.md -> tickets/${LEGACY_NAME}.md" \
           "symlink_note: ./current-note.md -> tickets/${LEGACY_NAME}-note.md" \
           "legacy_note:  legacy flat layout"; do
    if echo "$LEGACY_START_OUT" | grep -qF "$KEY"; then
        test_result 0 "legacy start info block contains: ${KEY%% *}..."
    else
        test_result 1 "legacy start info block missing: $KEY" \
            "$(echo "$LEGACY_START_OUT" | grep -A15 'Active ticket paths')"
    fi
done
# Legacy info block must NOT claim ticket_dir/tests_dir/tmp_dir (those don't exist).
if echo "$LEGACY_START_OUT" | grep -qE '^\s*(ticket_dir|tests_dir|tmp_dir):'; then
    test_result 1 "legacy start must not advertise ticket_dir/tests_dir/tmp_dir" \
        "$(echo "$LEGACY_START_OUT" | grep -E 'ticket_dir|tests_dir|tmp_dir')"
else
    test_result 0 "legacy start info block correctly omits ticket_dir/tests_dir/tmp_dir"
fi

# close a legacy ticket → produces legacy flat move to done/
git add tickets && git commit -q -m "start legacy"
timeout 15 ./ticket.sh close --no-push --no-delete-remote --keep-worktree >/dev/null 2>&1
if [[ -f "tickets/done/${LEGACY_NAME}.md" ]]; then
    test_result 0 "close on legacy ticket moves flat .md to done/ (unchanged behavior)"
else
    test_result 1 "close on legacy ticket should keep legacy flat layout"
fi
if git show "HEAD:tickets/done/${LEGACY_NAME}.md" 2>/dev/null | grep -q 'closed_at:'; then
    test_result 0 "legacy close: closed_at committed at HEAD"
else
    test_result 1 "legacy close: closed_at should be at HEAD"
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo
echo -e "${YELLOW}=== per-ticket directory Test Results ===${NC}"
echo -e "  Passed: ${GREEN}${PASS}${NC}, Failed: ${RED}${FAIL}${NC}"

[[ $FAIL -eq 0 ]]
