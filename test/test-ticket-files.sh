#!/usr/bin/env bash

# Tests for config's ticket_files (issue #6).
#
# `new` used to create exactly one companion file, note.md, from note_content.
# A project that wants a second one - a progress log kept apart from the note,
# say - had no way to ask for it, so the rule "create it if it isn't there" fell
# to whoever was working the ticket, and in practice it did not get created.
# ticket_files lets the config list any number of (path, content) pairs, and
# `new` writes them the same way it writes the note.
#
# The list is read through yaml-sh's one level of map-inside-a-list, which is
# the part of this that is new parsing rather than new plumbing - section 2
# covers a multi-line `content:` block surviving the round trip.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== ticket_files Test Suite ==="
echo

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/tmp/test-ticket-files-$(date +%s)"
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

# Append raw YAML to the config and commit.
# Usage: config_append <repo-dir> <yaml-text>
config_append() {
    local dir="$1" text="$2"
    cd "$dir" || return 1
    printf '\n%s\n' "$text" >> .ticket-config.yaml
    git add -A && git commit -q -m "Declare ticket_files"
}

# ---------------------------------------------------------------------------
echo "1. ticket_files undefined behaves exactly as before"
REPO=$(make_repo undefined)
cd "$REPO"
timeout 5 ./ticket.sh new plain >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*plain*")
if [[ -f "tickets/${TICKET}/note.md" ]]; then
    pass "note.md is still created from note_content"
else
    fail "note.md missing" "$(ls -R tickets)"
fi
EXTRA=$(cd "tickets/${TICKET}" && ls | grep -v -E '^(ticket|note)\.md$' | grep -v '^tmp$' || true)
if [[ -z "$EXTRA" ]]; then
    pass "no other files appear in the ticket directory"
else
    fail "unexpected files created" "$EXTRA"
fi

# ---------------------------------------------------------------------------
echo
echo "2. declared files are created, with placeholders substituted"
REPO=$(make_repo declared)
config_append "$REPO" 'ticket_files:
  - path: progress.md
    content: |
      # Progress: $$TICKET_NAME$$

      Working notes live in $$NOTE_PATH$$.
  - path: docs/design.md
    content: |
      # Design: $$TICKET_NAME$$'
cd "$REPO"
timeout 5 ./ticket.sh new logged >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*logged*")
PROGRESS="tickets/${TICKET}/progress.md"

if [[ -f "$PROGRESS" ]]; then
    pass "progress.md is created"
else
    fail "progress.md missing" "$(ls -R tickets)"
fi
if grep -q "^# Progress: ${TICKET}$" "$PROGRESS" 2>/dev/null; then
    pass "\$\$TICKET_NAME\$\$ is substituted"
else
    fail "ticket name not substituted" "$(cat "$PROGRESS" 2>/dev/null)"
fi
if grep -q "Working notes live in note.md." "$PROGRESS" 2>/dev/null; then
    pass "\$\$NOTE_PATH\$\$ is substituted"
else
    fail "note path not substituted" "$(cat "$PROGRESS" 2>/dev/null)"
fi
# The blank line between the two paragraphs is what proves the multi-line
# `content:` block came through yaml-sh intact rather than folded.
if [[ "$(awk 'NR==2' "$PROGRESS")" == "" ]] && [[ "$(awk 'END{print NR}' "$PROGRESS")" -ge 3 ]]; then
    pass "the multi-line content block keeps its line structure"
else
    fail "content block was flattened" "$(cat -A "$PROGRESS" 2>/dev/null | head -5)"
fi
if [[ -f "tickets/${TICKET}/docs/design.md" ]]; then
    pass "a nested path creates its directory"
else
    fail "docs/design.md missing" "$(ls -R tickets)"
fi
if [[ -f "tickets/${TICKET}/note.md" ]]; then
    pass "note_content still produces note.md alongside them"
else
    fail "note.md missing" "$(ls -R tickets)"
fi

# ---------------------------------------------------------------------------
echo
echo "3. an existing file is never overwritten"
cd "$REPO"
# Two ways a file can already be there when the loop reaches it, and neither
# may cost the content that is already on disk.
#
# First: the whole ticket directory pre-exists. `new` refuses before it writes
# anything, so a hand-placed file survives untouched.
FUTURE="tickets/251231-235959-preseeded"
mkdir -p "$FUTURE"
echo "hand-written, keep me" > "${FUTURE}/progress.md"
OUT=$(timeout 5 ./ticket.sh new preseeded --created-at 251231-235959 2>&1)
if [[ "$(cat "${FUTURE}/progress.md")" == "hand-written, keep me" ]] && \
   echo "$OUT" | grep -q "Ticket already exists"; then
    pass "new refuses outright when the ticket directory already exists"
else
    fail "a pre-existing ticket directory was written into" "$OUT"
fi
rm -rf "$FUTURE"

# Second: two entries name the same path. The first one written wins, and the
# second says so rather than silently replacing it - this is the loop's own
# guard, with nothing else standing in front of it.
REPO_DUP=$(make_repo duplicate)
config_append "$REPO_DUP" 'ticket_files:
  - path: progress.md
    content: |
      first entry
  - path: progress.md
    content: |
      second entry'
cd "$REPO_DUP"
OUT=$(timeout 5 ./ticket.sh new twice 2>&1)
TICKET=$(safe_get_ticket_name "*twice*")
if [[ "$(cat "tickets/${TICKET}/progress.md")" == "first entry" ]]; then
    pass "a second entry for the same path leaves the file alone"
else
    fail "the later entry overwrote the earlier one" "$OUT"
fi
if echo "$OUT" | grep -q "already exists, left as is"; then
    pass "the skipped write is reported"
else
    fail "no note about the skipped write" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "4. a note.md entry wins over note_content"
REPO=$(make_repo noteoverride)
config_append "$REPO" 'ticket_files:
  - path: note.md
    content: |
      # Notes for $$TICKET_NAME$$ (from ticket_files)'
cd "$REPO"
timeout 5 ./ticket.sh new overridden >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*overridden*")
NOTE="tickets/${TICKET}/note.md"
if grep -q "(from ticket_files)" "$NOTE" 2>/dev/null; then
    pass "note.md holds the ticket_files content"
else
    fail "note_content was used instead" "$(cat "$NOTE" 2>/dev/null)"
fi
if [[ "$(grep -c "Work Notes for" "$NOTE" 2>/dev/null)" -eq 0 ]]; then
    pass "the note_content template is not also written"
else
    fail "both templates landed in note.md" "$(cat "$NOTE")"
fi
OUT=$(cd "$REPO" && timeout 5 ./ticket.sh new second 2>&1)
if [[ "$(echo "$OUT" | grep -c "Created note file")" -eq 1 ]]; then
    pass "the note is reported once, not twice"
else
    fail "note creation reported more than once" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "5. a path outside the ticket directory is refused"
REPO=$(make_repo escapes)
config_append "$REPO" 'ticket_files:
  - path: ../escaped.md
    content: |
      should not exist
  - path: /tmp/absolute-escape.md
    content: |
      should not exist
  - path: fine.md
    content: |
      ok'
cd "$REPO"
rm -f /tmp/absolute-escape.md
OUT=$(timeout 5 ./ticket.sh new guarded 2>&1)
TICKET=$(safe_get_ticket_name "*guarded*")
if [[ ! -f "tickets/escaped.md" ]] && [[ ! -f "/tmp/absolute-escape.md" ]]; then
    pass "neither the relative nor the absolute escape is written"
else
    fail "a file was written outside the ticket directory" "$OUT"
fi
if echo "$OUT" | grep -q "not inside the ticket directory"; then
    pass "the skipped entries are reported"
else
    fail "no warning about the skipped entries" "$OUT"
fi
if [[ -f "tickets/${TICKET}/fine.md" ]]; then
    pass "the remaining entries are still created"
else
    fail "a bad entry stopped the good one" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "6. start and restore name the files they created"
REPO=$(make_repo paths)
config_append "$REPO" 'ticket_files:
  - path: progress.md
    content: |
      # Progress: $$TICKET_NAME$$'
cd "$REPO"
timeout 5 ./ticket.sh new tracked >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*tracked*")
git add -A && git commit -q -m "Add ticket"
OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if echo "$OUT" | grep -q "file:         tickets/${TICKET}/progress.md"; then
    pass "start prints the extra file's resolved path"
else
    fail "start did not list progress.md" "$(echo "$OUT" | sed -n '/Active ticket paths/,/^$/p')"
fi
rm -f current-ticket.md current-note.md
rm -rf current-ticket
OUT=$(timeout 20 ./ticket.sh restore 2>&1)
if echo "$OUT" | grep -q "file:         tickets/${TICKET}/progress.md"; then
    pass "restore prints it too"
else
    fail "restore did not list progress.md" "$(echo "$OUT" | sed -n '/Active ticket paths/,/^$/p')"
fi

# ---------------------------------------------------------------------------
echo
echo "7. legacy flat tickets get no extra files"
cd "$REPO"
git checkout -q main
# A flat-layout ticket, as produced by versions before the per-ticket directory.
cat > tickets/250101-000000-legacy.md << 'EOF'
---
priority: 2
base_branch: default
description: "legacy flat ticket"
created_at: "2025-01-01T00:00:00Z"
started_at: null
closed_at: null
canceled_at: null
---

# Legacy
EOF
git add -A && git commit -q -m "Add legacy ticket"
OUT=$(timeout 20 ./ticket.sh start 250101-000000-legacy 2>&1)
if [[ ! -e "tickets/250101-000000-legacy/progress.md" ]] && \
   ! echo "$OUT" | grep -q "  file:"; then
    pass "no progress.md is invented for a flat ticket"
else
    fail "a flat ticket was given extra files" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "=== ticket_files Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "$REPO_ROOT"
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"
rm -f /tmp/absolute-escape.md

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
