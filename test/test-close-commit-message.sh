#!/usr/bin/env bash

# Tests for the squash commit message that 'close' writes.
#
# The message embeds the ticket on purpose - it is what lets `git blame` reach
# the "why" without opening tickets/done/ - but it embeds the Markdown body
# only. These cover that split, plus two ways the message used to get mangled:
# `echo -e` expanding backslash escapes that came from the ticket body, and a
# block-scalar description spilling the subject across several lines.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== close commit message Test Suite ==="
echo

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/tmp/test-close-commit-message-$(date +%s)"
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

# new -> overwrite the ticket file -> start -> make a commit -> close.
# Usage: close_with <repo-dir> <slug> <ticket-file-contents>
# Leaves the caller in the repo with the close commit at main's tip.
close_with() {
    local dir="$1" slug="$2" contents="$3"
    cd "$dir" || return 1

    timeout 5 ./ticket.sh new "$slug" >/dev/null 2>&1
    local ticket
    ticket=$(safe_get_ticket_name "*${slug}*")
    printf '%s' "$contents" > "tickets/${ticket}/ticket.md"
    git add tickets && git commit -q -m "Add ticket"

    timeout 10 ./ticket.sh start "$ticket" >/dev/null 2>&1
    echo "work" >> README.md
    git add README.md && git commit -q -m "Do the work"
    timeout 20 ./ticket.sh close >/dev/null 2>&1

    echo "$ticket"
}

# ---------------------------------------------------------------------------
echo "1. The body carries the Markdown, not the YAML frontmatter"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo1)
close_with "$REPO" strip-fm '---
priority: 2
description: "short description"
created_at: "2026-08-10T00:00:00Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

The reason this change was made.

## Tasks
- [x] done
' >/dev/null

MSG=$(git log -1 --format=%B main)

if echo "$MSG" | grep -q "Do not modify manually"; then
    fail "frontmatter comments leaked into the commit message"
else
    pass "frontmatter comments stay out of the commit message"
fi

if echo "$MSG" | grep -q "^created_at:"; then
    fail "frontmatter keys leaked into the commit message"
else
    pass "frontmatter keys stay out of the commit message"
fi

if echo "$MSG" | grep -q "The reason this change was made."; then
    pass "the Markdown body is still embedded"
else
    fail "the Markdown body should be embedded" "$MSG"
fi

# The frontmatter is dropped from the message, not lost: the same commit
# carries the ticket file itself.
DONE_PATH=$(git ls-tree -r --name-only main | grep "^tickets/done/.*/ticket\.md$" | head -1)
if [[ -n "$DONE_PATH" ]] && git show "main:${DONE_PATH}" | grep -q "^created_at:"; then
    pass "the ticket file in the commit still carries the frontmatter"
else
    fail "tickets/done/<name>/ticket.md should still carry the frontmatter"
fi

# Subject, blank line, then the first heading - no stray blank lines from the
# gap that sat between the closing fence and the body.
if [[ "$(echo "$MSG" | sed -n '2p')" == "" ]] && [[ "$(echo "$MSG" | sed -n '3p')" == "# Ticket Overview" ]]; then
    pass "exactly one blank line separates the subject from the body"
else
    fail "unexpected spacing after the subject" "line2='$(echo "$MSG" | sed -n '2p')' line3='$(echo "$MSG" | sed -n '3p')'"
fi

# ---------------------------------------------------------------------------
echo
echo "2. Backslash escapes in the body survive verbatim"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo2)
close_with "$REPO" escapes '---
priority: 2
description: "escape handling"
created_at: "2026-08-10T00:00:00Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Overview

Run `printf "a\nb"` and mind the \t tab and the \\ backslash.
' >/dev/null

BODY=$(git log -1 --format=%B main)

if echo "$BODY" | grep -qF 'printf "a\nb"'; then
    pass "a literal backslash-n in the body is left alone"
else
    fail "backslash-n in the body was expanded" "$BODY"
fi

if echo "$BODY" | grep -qF '\t tab'; then
    pass "a literal backslash-t in the body is left alone"
else
    fail "backslash-t in the body was expanded" "$BODY"
fi

if echo "$BODY" | grep -qF '\\ backslash'; then
    pass "a doubled backslash in the body is left alone"
else
    fail "a doubled backslash in the body was collapsed" "$BODY"
fi

# ---------------------------------------------------------------------------
echo
echo "3. A block-scalar description stays on the subject line"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo3)
close_with "$REPO" multiline-desc '---
priority: 2
description: |
  first line of desc
  second line of desc
created_at: "2026-08-10T00:00:00Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Overview

body content
' >/dev/null

MSG=$(git log -1 --format=%B main)
LINE1=$(echo "$MSG" | sed -n '1p')

if echo "$LINE1" | grep -q "first line of desc second line of desc"; then
    pass "the description is folded onto one line"
else
    fail "the description should be folded onto the subject line" "line1='$LINE1'"
fi

if [[ "$(echo "$MSG" | sed -n '2p')" == "" ]] && [[ "$(echo "$MSG" | sed -n '3p')" == "# Overview" ]]; then
    pass "the folded subject is followed by one blank line and the body"
else
    fail "unexpected spacing after a folded subject" "line2='$(echo "$MSG" | sed -n '2p')' line3='$(echo "$MSG" | sed -n '3p')'"
fi

# ---------------------------------------------------------------------------
echo
echo "4. A ticket with no body still produces a well-formed message"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo4)
close_with "$REPO" empty-body '---
priority: 2
description: "nothing but frontmatter"
created_at: "2026-08-10T00:00:00Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---
' >/dev/null

MSG=$(git log -1 --format=%B main)

if [[ "$(echo "$MSG" | sed -n '1p')" == *"nothing but frontmatter" ]]; then
    pass "the subject is intact when the body is empty"
else
    fail "unexpected subject for an empty body" "$(echo "$MSG" | sed -n '1p')"
fi

# %B keeps one trailing newline, so a well-formed message is a single line here.
if [[ "$(echo "$MSG" | grep -c .)" -eq 1 ]]; then
    pass "an empty body leaves no trailing blank lines"
else
    fail "an empty body should not add blank lines" "$(echo "$MSG" | sed 's/^/|/')"
fi

# ---------------------------------------------------------------------------
echo
echo "5. An empty description still falls back to 'Ticket completed'"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo5)
close_with "$REPO" no-desc '---
priority: 2
description: ""
created_at: "2026-08-10T00:00:00Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Overview

no description here
' >/dev/null

if git log -1 --format=%s main | grep -q "\] Ticket completed$"; then
    pass "an empty description falls back to 'Ticket completed'"
else
    fail "expected the 'Ticket completed' fallback" "$(git log -1 --format=%s main)"
fi

# A description of nothing but whitespace is empty for our purposes too.
REPO=$(make_repo repo5b)
close_with "$REPO" blank-desc '---
priority: 2
description: "   "
created_at: "2026-08-10T00:00:00Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Overview

whitespace description
' >/dev/null

if git log -1 --format=%s main | grep -q "\] Ticket completed$"; then
    pass "a whitespace-only description falls back too"
else
    fail "expected the fallback for a whitespace-only description" "$(git log -1 --format=%s main)"
fi

# ---------------------------------------------------------------------------
echo
echo "6. Legacy flat tickets get the same treatment"
# ---------------------------------------------------------------------------
REPO=$(make_repo repo6)
cd "$REPO"

# Hand-build a flat ticket: tickets/<name>.md + tickets/<name>-note.md.
LEGACY="260810-000000-legacy-close"
cat > "tickets/${LEGACY}.md" <<'EOF'
---
priority: 2
description: "legacy flat layout"
created_at: "2026-08-10T00:00:00Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Legacy Overview

legacy body text
EOF
echo "# Note" > "tickets/${LEGACY}-note.md"
git add tickets && git commit -q -m "Add legacy ticket"

timeout 10 ./ticket.sh start "$LEGACY" >/dev/null 2>&1
echo "work" >> README.md
git add README.md && git commit -q -m "Do the work"
timeout 20 ./ticket.sh close >/dev/null 2>&1

MSG=$(git log -1 --format=%B main)

if echo "$MSG" | grep -q "Do not modify manually"; then
    fail "frontmatter leaked into a legacy ticket's commit message"
else
    pass "legacy tickets drop the frontmatter too"
fi

if echo "$MSG" | grep -q "legacy body text"; then
    pass "legacy tickets keep their Markdown body"
else
    fail "a legacy ticket's body should be embedded" "$MSG"
fi

# ---------------------------------------------------------------------------
echo
echo "7. A ticket with no frontmatter at all falls back to the whole file"
# ---------------------------------------------------------------------------
# extract_markdown_body returns the entire file when there is no frontmatter.
# close still needs its own metadata, so this exercises the fallback through the
# helper directly rather than through a close that could not run.
REPO=$(make_repo repo7)
cd "$REPO"
cat > plain.md <<'EOF'
# Just Markdown

no frontmatter at all
EOF

BODY=$(source "${REPO_ROOT}/lib/yaml-frontmatter.sh"; extract_markdown_body plain.md)

if echo "$BODY" | grep -q "no frontmatter at all" && echo "$BODY" | grep -q "# Just Markdown"; then
    pass "a file without frontmatter comes back whole"
else
    fail "expected the whole file back" "$BODY"
fi

# ---------------------------------------------------------------------------
echo
echo "=== close commit message Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "$REPO_ROOT"
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
