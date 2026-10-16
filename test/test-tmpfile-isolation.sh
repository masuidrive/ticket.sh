#!/usr/bin/env bash

# Tests that nothing reads or writes a temp path it did not create (issue #20).
#
# `close`, `start` and `cancel` parse the ticket's frontmatter by handing a file
# to yaml_parse, and the frontmatter is a string in hand, so three callers used
# to bridge that with a path of their own naming: /tmp/ticket_yaml.yml and
# /tmp/ticket_yaml_early.yml. A fixed name in a world-writable directory is two
# bugs, not a style problem.
#
# Section 1 is the one that found it. Two closes in parallel - the arrangement
# this script advertises for multiple agents - wrote and read the same path, and
# in a hundred paired dry-runs forty-eight read the other repo's ticket. Where
# the other ticket's base_branch happened to name a branch that also exists in
# the first repo, the run passed every preflight check and aimed the
# squash-merge at the wrong branch. So the assertion is not "it usually works":
# the fixtures are built so that reading the wrong frontmatter is visible in the
# output, and the test fails on a single occurrence.
#
# Section 2 covers the other half: a predictable name can be pre-created by
# somebody else as a symlink, which `>|` follows, and the `rm -f` afterwards
# takes the symlink rather than the file it clobbered.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== Temp-file isolation Test Suite ==="
echo

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/tmp/test-tmpfile-$(date +%s)"
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

# Build a repo with one started ticket. $2 is a sed expression applied to the
# ticket's frontmatter before it is committed (empty for none).
# Echoes the repo path into REPO and the ticket name into TICKET.
# Usage: setup <dir-name> [<frontmatter-sed>]
setup() {
    local name="$1"
    local fm_sed="${2:-}"
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

    timeout 5 ./ticket.sh new "$name" >/dev/null 2>&1
    TICKET=$(safe_get_ticket_name "*${name}*")
    [[ -n "$fm_sed" ]] && sed_i "$fm_sed" "tickets/${TICKET}/ticket.md"
    git add tickets && git commit -q -m "Add ticket"
    git branch release-b main
    timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1

    REPO="$dir"
}

# ---------------------------------------------------------------------------
echo "1. two closes in parallel do not read each other's ticket"
# Repo A's ticket merges into main. Repo B's names release-b, and A has a branch
# of that name too - so A reading B's frontmatter does not error, it just aims
# somewhere else, which is the quiet form of the bug and the one worth pinning.
setup para-a
A_REPO="$REPO"
setup para-b "s|^base_branch: default.*|base_branch: release-b|"
B_REPO="$REPO"

# Both must be right on their own before the pair means anything.
cd "$A_REPO"
A_SOLO=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
cd "$B_REPO"
B_SOLO=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
if echo "$A_SOLO" | grep -q "base branch:    main"; then
    pass "repo A alone targets main"
else
    fail "repo A alone is already wrong" "$A_SOLO"
fi
if echo "$B_SOLO" | grep -q "base branch:    release-b"; then
    pass "repo B alone targets release-b"
else
    fail "repo B alone is already wrong" "$B_SOLO"
fi

# 40 paired runs. At the hit rate the original defect had (roughly half), a
# single surviving fixed path shows up here with near-certainty; the test fails
# on one occurrence, not on a ratio.
OUT_DIR="${TEST_DIR}/outs"
mkdir -p "$OUT_DIR"
A_WRONG=0
B_WRONG=0
OTHER=0
for i in $(seq 1 40); do
    ( cd "$A_REPO" && timeout 20 ./ticket.sh close --dry-run > "${OUT_DIR}/a.out" 2>&1 ) &
    ( cd "$B_REPO" && timeout 20 ./ticket.sh close --dry-run > "${OUT_DIR}/b.out" 2>&1 ) &
    wait
    if grep -q "base branch:    release-b" "${OUT_DIR}/a.out"; then
        A_WRONG=$((A_WRONG + 1))
        [[ $A_WRONG -eq 1 ]] && FIRST_A=$(cat "${OUT_DIR}/a.out")
    fi
    if grep -q "base branch:    main" "${OUT_DIR}/b.out"; then
        B_WRONG=$((B_WRONG + 1))
        [[ $B_WRONG -eq 1 ]] && FIRST_B=$(cat "${OUT_DIR}/b.out")
    fi
    if ! grep -q "all preflight checks passed" "${OUT_DIR}/a.out" || \
       ! grep -q "all preflight checks passed" "${OUT_DIR}/b.out"; then
        OTHER=$((OTHER + 1))
        [[ $OTHER -eq 1 ]] && FIRST_OTHER="$(cat "${OUT_DIR}/a.out")
---
$(cat "${OUT_DIR}/b.out")"
    fi
done

if [[ $A_WRONG -eq 0 ]]; then
    pass "repo A never read repo B's base_branch (40 paired runs)"
else
    fail "repo A read repo B's ticket in ${A_WRONG}/40 runs" "${FIRST_A:-}"
fi
if [[ $B_WRONG -eq 0 ]]; then
    pass "repo B never read repo A's base_branch (40 paired runs)"
else
    fail "repo B read repo A's ticket in ${B_WRONG}/40 runs" "${FIRST_B:-}"
fi
if [[ $OTHER -eq 0 ]]; then
    pass "no run failed for any other reason"
else
    fail "${OTHER}/40 paired runs did not pass their checks" "${FIRST_OTHER:-}"
fi

# ---------------------------------------------------------------------------
echo
echo "2. a file planted at the old fixed paths is not touched"
# The paths themselves are gone, so this is a guard against them coming back
# under any name a third party can predict: write to one and the content shows up
# in a file this test owns.
setup planted
cd "$REPO"
PLANTED_DIR="${TEST_DIR}/planted-target"
mkdir -p "$PLANTED_DIR"
for p in /tmp/ticket_yaml.yml /tmp/ticket_yaml_early.yml; do
    echo "KEEP THIS" > "${PLANTED_DIR}/$(basename "$p")"
    ln -sf "${PLANTED_DIR}/$(basename "$p")" "$p" 2>/dev/null || true
done

timeout 20 ./ticket.sh close --dry-run >/dev/null 2>&1
timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1
INTACT=true
for p in /tmp/ticket_yaml.yml /tmp/ticket_yaml_early.yml; do
    f="${PLANTED_DIR}/$(basename "$p")"
    [[ "$(cat "$f" 2>/dev/null)" == "KEEP THIS" ]] || INTACT=false
done
if [[ "$INTACT" == "true" ]]; then
    pass "close and start left the planted files alone"
else
    fail "a planted file was clobbered through the symlink" \
         "$(head -3 "${PLANTED_DIR}/ticket_yaml.yml" 2>/dev/null)"
fi
# cancel reads the frontmatter the same way, and it is the one that cannot be
# repeated afterwards - so check it last, on its own run.
timeout 20 ./ticket.sh cancel --force >/dev/null 2>&1
INTACT=true
for p in /tmp/ticket_yaml.yml /tmp/ticket_yaml_early.yml; do
    f="${PLANTED_DIR}/$(basename "$p")"
    [[ "$(cat "$f" 2>/dev/null)" == "KEEP THIS" ]] || INTACT=false
done
if [[ "$INTACT" == "true" ]]; then
    pass "cancel left them alone too"
else
    fail "cancel clobbered a planted file" \
         "$(head -3 "${PLANTED_DIR}/ticket_yaml.yml" 2>/dev/null)"
fi
rm -f /tmp/ticket_yaml.yml /tmp/ticket_yaml_early.yml

# ---------------------------------------------------------------------------
echo
echo "3. a block-scalar description still reads as its content"
# The temptation when removing yaml_parse's temp file is to drop yaml_parse and
# read the field with awk instead. `description: |` is why that is wrong: yaml_get
# returns the folded content, and a line-matching reader returns "|". The commit
# subject is where it would show.
setup blockdesc
cd "$REPO"
# Written out in full rather than edited in place: a block scalar is a shape,
# not a value, and sed would have to invent the continuation line anyway.
STARTED_AT=$(grep '^started_at:' "tickets/${TICKET}/ticket.md")
cat > "tickets/${TICKET}/ticket.md" << EOF
---
priority: 2
base_branch: default
description: |
  a description written as a block scalar
created_at: "2026-10-16T00:00:00Z"
${STARTED_AT}
closed_at: null
canceled_at: null
---

# Ticket Overview

body

## Tasks

- [x] done
EOF
git add -A && git commit -q -m "block scalar description"
OUT=$(timeout 20 ./ticket.sh close 2>&1)
SUBJECT=$(git log --format='%s' -1 main)
if echo "$SUBJECT" | grep -q "a description written as a block scalar"; then
    pass "the squash subject carries the description's content"
else
    fail "the block scalar was not read" "subject: $SUBJECT"
fi
if ! echo "$SUBJECT" | grep -q -- "|"; then
    pass "the subject is not the literal block indicator"
else
    fail "the subject is the YAML indicator, not the text" "subject: $SUBJECT"
fi

# ---------------------------------------------------------------------------
echo
echo "4. the frontmatter is not left lying around, and a temp file that cannot"
echo "   be made stops the run"
# TMPDIR is deliberately not asserted on: `mktemp` with no template honours it on
# GNU and busybox but ignores it on macOS, which uses the per-user directory from
# confstr(_CS_DARWIN_USER_TEMP_DIR) instead. Both are private, unpredictable and
# created with O_EXCL, which is the property that matters; where exactly they land
# is the platform's business. What is worth pinning is that nothing is left there.
setup leftover
cd "$REPO"
SHIM_DIR="${TEST_DIR}/shim"
FORCED_TMP="${TEST_DIR}/forced-tmp"
MKTEMP_LOG="${TEST_DIR}/mktemp.log"
rm -rf "$SHIM_DIR" "$FORCED_TMP"
mkdir -p "$SHIM_DIR" "$FORCED_TMP"
: > "$MKTEMP_LOG"
REAL_MKTEMP=$(command -v mktemp)
# A shim that makes every temp file land in a directory this test owns. Reaching
# for one is not elegance: `mktemp` with no template honours TMPDIR on GNU and
# busybox but ignores it on macOS, which uses the per-user directory from
# confstr(_CS_DARWIN_USER_TEMP_DIR) - 30,000 files and 12 GB of other people's
# business on the machine this was written on. Where the file lands is the
# platform's call; that it is gone afterwards is ours, and this is how it can be
# looked at.
cat > "${SHIM_DIR}/mktemp" << SHIM
#!/usr/bin/env bash
echo "called" >> "${MKTEMP_LOG}"
if [ \$# -gt 0 ]; then
    exec "${REAL_MKTEMP}" "\$@"
fi
exec "${REAL_MKTEMP}" "${FORCED_TMP}/tkt.XXXXXX"
SHIM
chmod +x "${SHIM_DIR}/mktemp"

PATH="${SHIM_DIR}:$PATH" timeout 20 ./ticket.sh close --dry-run >/dev/null 2>&1
if [[ -s "$MKTEMP_LOG" ]]; then
    pass "the run did make temp files (so the next assertion means something)"
else
    fail "no temp file was made at all" "$(ls -A "$FORCED_TMP")"
fi
LEFT=$(ls -A "$FORCED_TMP" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$LEFT" == "0" ]]; then
    pass "every temp file it made was removed again"
else
    fail "temp files were left behind" "$(ls -A "$FORCED_TMP"; grep -l . "$FORCED_TMP"/* 2>/dev/null | head -2)"
fi

# When no temp file can be made at all, the run has to say so. Carrying on is
# what let it read a file it had not written in the first place. A shim earlier
# in PATH is the portable way to force it: a bad TMPDIR does not fail everywhere.
cat > "${SHIM_DIR}/mktemp" << 'SHIM'
#!/usr/bin/env bash
exit 1
SHIM
chmod +x "${SHIM_DIR}/mktemp"
OUT=$(PATH="${SHIM_DIR}:$PATH" timeout 20 ./ticket.sh close --dry-run 2>&1)
RC=$?
if [[ $RC -ne 0 ]]; then
    pass "a failing mktemp stops the run"
else
    fail "the run carried on without a temp file" "$OUT"
fi
if echo "$OUT" | grep -qi "temporary"; then
    pass "the error says a temporary file could not be made"
else
    fail "the error does not say what is wrong" "$OUT"
fi
if ! echo "$OUT" | grep -q "all preflight checks passed"; then
    pass "it did not claim the checks passed"
else
    fail "it claimed success" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "=== Temp-file isolation Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "$REPO_ROOT"
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
