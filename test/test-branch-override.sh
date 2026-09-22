#!/usr/bin/env bash

# Tests for the ticket's `branch:` frontmatter override and `new --branch`
# (issue #8).
#
# The feature branch name used to be {branch_prefix}<ticket-name> and nothing
# else. A branch created by something outside ticket.sh - a CI bot that checks
# out agent/issue-12 from the issue number before a ticket exists - could not be
# expressed, so every command had to be worked around: `check` reported a
# permanent mismatch, `close` was limited to --no-merge, and `start` was
# unusable. Letting the ticket say which branch it lives on is what puts those
# commands back in play, so the sections below walk one such ticket through the
# whole lifecycle rather than testing the field in isolation.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== branch override Test Suite ==="
echo

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/tmp/test-branch-override-$(date +%s)"
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

# Read started_at out of the ticket as it stands on main. Empty when main has no
# copy of the ticket, or the value is null.
# Usage: started_at_on_main <ticket-name>
started_at_on_main() {
    git show "main:tickets/${1}/ticket.md" 2>/dev/null \
        | awk '/^started_at:/ { sub(/^started_at:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); if ($0 != "null") print; exit }'
}

# ---------------------------------------------------------------------------
echo "1. new --branch writes the field"
REPO=$(make_repo newbranch)
cd "$REPO"
OUT=$(timeout 5 ./ticket.sh new botwork --branch agent/issue-12 2>&1)
TICKET=$(safe_get_ticket_name "*botwork*")
BODY="tickets/${TICKET}/ticket.md"

if grep -q "^branch: agent/issue-12$" "$BODY" 2>/dev/null; then
    pass "the frontmatter carries branch: agent/issue-12"
else
    fail "branch: not written" "$(sed -n '1,10p' "$BODY" 2>/dev/null)"
fi
if echo "$OUT" | grep -q "branch: agent/issue-12"; then
    pass "new says which branch the ticket will use"
else
    fail "new did not mention the branch" "$OUT"
fi
# The field sits inside the frontmatter fence, not after it - a `branch:` in the
# body would parse as nothing and the ticket would quietly revert to the prefix.
FENCES=$(awk '/^---[[:space:]]*$/ { n++ } /^branch:/ && n == 1 { found = 1 } END { print found + 0 }' "$BODY")
if [[ "$FENCES" == "1" ]]; then
    pass "the field is inside the frontmatter"
else
    fail "branch: landed outside the frontmatter" "$(sed -n '1,12p' "$BODY")"
fi

# ---------------------------------------------------------------------------
echo
echo "2. an unusable branch name is refused"
cd "$REPO"
for BAD in "foo..bar" "has space" "ends.lock" "-dashfirst" "ref@{0}"; do
    OUT=$(timeout 5 ./ticket.sh new "rejected" --branch "$BAD" 2>&1)
    RC=$?
    if [[ $RC -ne 0 ]] && echo "$OUT" | grep -q "Invalid branch name"; then
        pass "'$BAD' is refused"
    else
        fail "'$BAD' was accepted" "$OUT"
    fi
done
if [[ -z "$(safe_get_ticket_name "*rejected*")" ]]; then
    pass "no ticket is left behind by a refused --branch"
else
    fail "a ticket was created despite the bad branch name" "$(ls tickets)"
fi

# ---------------------------------------------------------------------------
echo
echo "3. start uses the named branch"
cd "$REPO"
git add -A && git commit -q -m "Add ticket"
OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "agent/issue-12" ]]; then
    pass "start checks out agent/issue-12"
else
    fail "start used a different branch" "$(git rev-parse --abbrev-ref HEAD)"
fi
if ! git show-ref --verify --quiet "refs/heads/feature/${TICKET}"; then
    pass "the prefix-named branch is not created as well"
else
    fail "a feature/<name> branch was created too" "$(git branch --list)"
fi
if grep -q "^started_at: \"\?20" "tickets/${TICKET}/ticket.md"; then
    pass "started_at is stamped as usual"
else
    fail "started_at not set" "$(sed -n '1,10p' "tickets/${TICKET}/ticket.md")"
fi

# ---------------------------------------------------------------------------
echo
echo "4. check and restore pair the branch with the ticket"
cd "$REPO"
OUT=$(timeout 20 ./ticket.sh check 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "active and synchronized"; then
    pass "check reports the ticket in sync"
else
    fail "check reported a mismatch" "$OUT"
fi
if ! echo "$OUT" | grep -q "mismatch"; then
    pass "no mismatch is reported"
else
    fail "mismatch text present" "$OUT"
fi

rm -f current-ticket.md current-note.md
rm -rf current-ticket
OUT=$(timeout 20 ./ticket.sh restore 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && echo "$OUT" | grep -q "$TICKET"; then
    pass "restore finds the ticket from the branch alone"
else
    fail "restore could not resolve the branch" "$OUT"
fi

# check recreates the link by itself when the symlink is gone, which is the
# path a bot takes: it never ran start, so nothing made the link.
rm -f current-ticket.md current-note.md
rm -rf current-ticket
OUT=$(timeout 20 ./ticket.sh check 2>&1)
if echo "$OUT" | grep -q "Found matching ticket for current branch"; then
    pass "check alone re-establishes the link"
else
    fail "check did not recover the link" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "5. close squash-merges the named branch"
cd "$REPO"
timeout 20 ./ticket.sh restore >/dev/null 2>&1
echo "work" >> README.md
git add -A && git commit -q -m "Do the work"
OUT=$(timeout 30 ./ticket.sh close --no-push 2>&1)
RC=$?
if [[ $RC -eq 0 ]]; then
    pass "close succeeds"
else
    fail "close failed" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]]; then
    pass "we end up on main"
else
    fail "not on main after close" "$(git rev-parse --abbrev-ref HEAD)"
fi
if [[ -f "tickets/done/${TICKET}/ticket.md" ]]; then
    pass "the ticket directory is in done/"
else
    fail "ticket not moved to done/" "$(ls -R tickets | head -20)"
fi
if git log --format='%s' -1 | grep -q "\[${TICKET}\]"; then
    pass "the squash commit is on main"
else
    fail "no squash commit" "$(git log --oneline -3)"
fi
if grep -q "^work$" README.md; then
    pass "the branch's work came across"
else
    fail "the work is missing from main" "$(cat README.md)"
fi

# ---------------------------------------------------------------------------
echo
echo "6. a branch created before the ticket is adopted, not duplicated"
REPO=$(make_repo preexisting)
cd "$REPO"
timeout 5 ./ticket.sh new adopted --branch agent/issue-99 >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*adopted*")
git add -A && git commit -q -m "Add ticket"
# The bot's machinery gets there first.
git branch agent/issue-99 main

OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if echo "$OUT" | grep -q "already exists. Resuming work"; then
    pass "start resumes the existing branch"
else
    fail "start did not recognise the branch" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "agent/issue-99" ]]; then
    pass "and checks it out"
else
    fail "start left us elsewhere" "$(git rev-parse --abbrev-ref HEAD)"
fi

# ---------------------------------------------------------------------------
echo
echo "7. list follows the override"
# The case list has to cover is a start whose fast-forward onto the base branch
# did not land: the ticket file on main still reads todo while the feature
# branch carries the start time. Reading only main would call work in progress
# 'todo', and with an overridden branch name list has to know where to look.
REPO=$(make_repo listing)
cd "$REPO"
timeout 5 ./ticket.sh new listed --branch agent/issue-7 >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*listed*")
git add -A && git commit -q -m "Add ticket"
timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1
# Undo the fast-forward, leaving main's copy of the ticket as it was before.
git checkout -q main
git reset -q --hard HEAD~1

OUT=$(timeout 20 ./ticket.sh list 2>&1)
if echo "$OUT" | grep -q "status: doing"; then
    pass "the ticket reads doing from the base branch"
else
    fail "list fell back to todo" "$OUT"
fi
if echo "$OUT" | grep -q "started_at_only_on: agent/issue-7"; then
    pass "started_at_only_on names the overridden branch"
else
    fail "list did not look at the overridden branch" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "8. start works when the ticket exists only on its own branch"
# The bot's shape (issue #9): the machinery creates and checks out the branch
# first, the ticket is created and committed there, and the base branch never
# sees it. `start` used to check out the base branch before looking for the
# ticket, which walked away from the only copy of it.
REPO=$(make_repo ownbranch)
cd "$REPO"
git checkout -q -b agent/issue-77
timeout 5 ./ticket.sh new issue-77 --branch agent/issue-77 >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*issue-77*")
git add tickets && git commit -q -m "Add ticket on its own branch"
# Nothing on main: that is the whole point of this case.
if ! git cat-file -e "main:tickets/${TICKET}/ticket.md" 2>/dev/null; then
    pass "the ticket is absent from the base branch (fixture)"
else
    fail "fixture wrong: the ticket reached main" "$(git log --oneline main -3)"
fi

OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
RC=$?
if [[ $RC -eq 0 ]] && ! echo "$OUT" | grep -q "Ticket not found"; then
    pass "start succeeds"
else
    fail "start could not find the ticket" "$OUT"
fi
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "agent/issue-77" ]]; then
    pass "start stays on the branch instead of switching to the base"
else
    fail "start switched away" "$(git rev-parse --abbrev-ref HEAD)"
fi
if grep -q "^started_at: \"\?20" "tickets/${TICKET}/ticket.md"; then
    pass "started_at is stamped"
else
    fail "started_at not set" "$(sed -n '1,10p' "tickets/${TICKET}/ticket.md")"
fi
if git log --format='%s' -1 | grep -q "^\[start\] agent/issue-77$"; then
    pass "the stamp is committed on this branch"
else
    fail "no start commit" "$(git log --oneline -3)"
fi
if echo "$OUT" | grep -q "has no copy of this ticket"; then
    pass "the skipped fast-forward is explained"
else
    fail "nothing said about the base branch" "$OUT"
fi
if [[ "$(git rev-parse main)" == "$(git rev-parse main@{0})" ]] && \
   ! git cat-file -e "main:tickets/${TICKET}/ticket.md" 2>/dev/null; then
    pass "the base branch is left alone"
else
    fail "main was modified" "$(git log --oneline main -3)"
fi
if [[ -L current-ticket.md ]] && [[ -d current-ticket ]]; then
    pass "the active-ticket symlinks are created"
else
    fail "symlinks missing" "$(ls -l current-ticket* 2>&1)"
fi
if echo "$OUT" | grep -q "Active ticket paths:"; then
    pass "the resolved paths are emitted"
else
    fail "no Active ticket paths block" "$OUT"
fi

# Running it again must not re-stamp: started_at is the time work began, and a
# second start is how an interrupted session gets its links back.
STAMP_BEFORE=$(grep '^started_at:' "tickets/${TICKET}/ticket.md")
OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if echo "$OUT" | grep -q "already started"; then
    pass "a second start resumes instead of restarting"
else
    fail "second start did not resume" "$OUT"
fi
if [[ "$(grep '^started_at:' "tickets/${TICKET}/ticket.md")" == "$STAMP_BEFORE" ]]; then
    pass "the start time is not rewritten"
else
    fail "started_at was overwritten" "$(grep '^started_at:' "tickets/${TICKET}/ticket.md")"
fi

# And the rest of the lifecycle still works from here.
echo "work" >> README.md
git add -A && git commit -q -m "Do the work"
OUT=$(timeout 30 ./ticket.sh close --no-push 2>&1)
if [[ $? -eq 0 ]] && [[ -f "tickets/done/${TICKET}/ticket.md" ]]; then
    pass "close squash-merges it to the base branch"
else
    fail "close failed" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "9. a ticket that is on the base branch keeps the ordinary path"
# The own-branch case must stay narrow. When the base branch has the ticket,
# start behaves as it always did - branch from the base and fast-forward it, so
# the ticket reads `doing` from either branch. Nothing about `branch:` changes
# that; only where the ticket lives does.
REPO=$(make_repo onbase)
cd "$REPO"
timeout 5 ./ticket.sh new shared --branch agent/issue-88 >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*shared*")
git add tickets && git commit -q -m "Add ticket on main"

OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "agent/issue-88" ]]; then
    pass "start ends up on the named branch"
else
    fail "wrong branch" "$(git rev-parse --abbrev-ref HEAD)"
fi
if ! echo "$OUT" | grep -q "has no copy of this ticket"; then
    pass "the own-branch path is not taken"
else
    fail "took the own-branch path when the base had the ticket" "$OUT"
fi
if [[ -n "$(started_at_on_main "$TICKET")" ]]; then
    pass "the start time still reaches the base branch"
else
    fail "the base branch was not fast-forwarded" "$(git log --oneline main -3)"
fi

# The same ticket, reached from a branch that is not its own: start must still
# be free to return to the base branch, or the own-branch test above would have
# pinned every feature branch in place.
REPO=$(make_repo elsewhere)
cd "$REPO"
timeout 5 ./ticket.sh new fromelsewhere --branch agent/issue-89 >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*fromelsewhere*")
git add tickets && git commit -q -m "Add ticket on main"
git checkout -q -b some/unrelated-branch

OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "agent/issue-89" ]]; then
    pass "start leaves an unrelated branch and lands on the named one"
else
    fail "start did not switch away" "$(git rev-parse --abbrev-ref HEAD)"
fi

# The same move, with git writing a warning to stderr. `start` decides whether
# to leave a feature branch by reading `git status --porcelain`, and it used to
# capture stderr along with it - so in any environment where git warns (an
# unreadable ~/.config/git/ignore is the normal state of a CI container) a clean
# tree read as uncommitted changes and start refused to move, telling the user
# to commit files that were already committed. Caught by the assertion above
# failing on Docker while passing on macOS.
#
# The warning is produced by a `git` shim on PATH rather than by arranging for a
# real one: making git warn for real needs an unreadable path, and an unreadable
# path is a hard error on some builds and a warning on others - which is how the
# first attempt at this test failed on Linux while passing on macOS. The shim
# warns only for `status`, so this stays a test about one line of code.
REPO=$(make_repo gitwarns)
cd "$REPO"
timeout 5 ./ticket.sh new warned --branch agent/issue-90 >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*warned*")
git add tickets && git commit -q -m "Add ticket on main"
git checkout -q -b some/unrelated-branch

# Outside the repo: an untracked shim/ inside it would make the tree genuinely
# dirty, and the test would pass for the wrong reason.
REAL_GIT=$(command -v git)
SHIM_DIR="${TEST_DIR}/gitshim"
mkdir -p "$SHIM_DIR"
cat > "${SHIM_DIR}/git" << SHIM
#!/usr/bin/env bash
for _a in "\$@"; do
    if [[ "\$_a" == "status" ]]; then
        echo "warning: unable to access '/root/.config/git/ignore': Permission denied" >&2
        break
    fi
done
exec "${REAL_GIT}" "\$@"
SHIM
chmod +x "${SHIM_DIR}/git"

# The shim has to actually warn while still succeeding, or the test proves nothing.
SHIM_OUT=$(PATH="${SHIM_DIR}:$PATH" git status --porcelain 2>&1 >/dev/null)
if [[ -n "$SHIM_OUT" ]] && PATH="${SHIM_DIR}:$PATH" git status --porcelain >/dev/null 2>&1; then
    pass "the shim warns on stderr and still succeeds (fixture)"
else
    fail "fixture wrong: the shim did not warn cleanly" "$SHIM_OUT"
fi

OUT=$(PATH="${SHIM_DIR}:$PATH" timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "agent/issue-90" ]]; then
    pass "a git warning on stderr is not mistaken for a dirty tree"
else
    fail "start read a git warning as uncommitted changes" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "9b. start records the start time when resuming a never-started ticket"
# `start` creates the branch before it stamps, so anything that goes wrong in
# between leaves the branch behind with started_at still null. Every later start
# then took the resume path, which never stamped - so the ticket stayed `todo`
# for good and close refused it with "Ticket not started", leaving hand-editing
# the frontmatter as the only way on. Hit for real while working this ticket.
REPO=$(make_repo resumestamp)
cd "$REPO"
timeout 5 ./ticket.sh new interrupted >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*interrupted*")
git add tickets && git commit -q -m "Add ticket"
# The branch exists, the stamp never happened.
git branch "feature/${TICKET}" main
if grep -q '^started_at: null' "tickets/${TICKET}/ticket.md"; then
    pass "the ticket is unstarted with its branch already present (fixture)"
else
    fail "fixture wrong: the ticket is already started" "$(grep '^started_at' "tickets/${TICKET}/ticket.md")"
fi

OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if echo "$OUT" | grep -q "Resuming work on existing ticket"; then
    pass "start takes the resume path"
else
    fail "start did not resume" "$OUT"
fi
if grep -q '^started_at: "\?20' "tickets/${TICKET}/ticket.md"; then
    pass "and records the start time anyway"
else
    fail "resume left started_at null" "$(grep '^started_at' "tickets/${TICKET}/ticket.md")"
fi

echo "work" >> README.md
git add -A && git commit -q -m "Do the work"
OUT=$(timeout 20 ./ticket.sh close --dry-run 2>&1)
if [[ $? -eq 0 ]] && ! echo "$OUT" | grep -q "Ticket not started"; then
    pass "close is no longer blocked"
else
    fail "close still refuses the resumed ticket" "$OUT"
fi

# Resuming again must not move the timestamp: it records when work began.
STAMP=$(grep '^started_at' "tickets/${TICKET}/ticket.md")
timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1
if [[ "$(grep '^started_at' "tickets/${TICKET}/ticket.md")" == "$STAMP" ]]; then
    pass "a second resume does not re-stamp"
else
    fail "started_at was rewritten on the second resume" "$(grep '^started_at' "tickets/${TICKET}/ticket.md")"
fi

# ---------------------------------------------------------------------------
echo
echo "9c. a branch: added on the agent branch wins over the base branch's copy"
# The sister case of section 8 (issue #13): the ticket is on the base branch
# *too*, so the own-branch path above does not apply and `start` checks out the
# base branch as usual. branch_name used to be read after that checkout, off the
# base branch's copy - which has no `branch:` at all when the field was added on
# the agent branch alone. That is exactly the shape a bot produces when it adopts
# a ticket already sitting in the backlog: the override was discarded every time
# and the work piled up on features/<name>, a branch no pull request watched.
# `start` returned 0 and stamped started_at, so nothing said otherwise until the
# PR came up empty.
REPO=$(make_repo adoptonbase)
cd "$REPO"
timeout 5 ./ticket.sh new backlogged >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*backlogged*")
git add tickets && git commit -q -m "Ticket on main, no branch: yet"

git checkout -q -b agent/issue-107
# The adoption: the field can only be written here, main's copy keeps none.
BODY="tickets/${TICKET}/ticket.md"
awk 'NR == 1 { print; print "branch: agent/issue-107"; next } { print }' "$BODY" > "${BODY}.new" \
    && mv "${BODY}.new" "$BODY"
git add -A && git commit -q -m "Adopt the ticket on the agent branch"
if [[ "$(git show "main:tickets/${TICKET}/ticket.md" | grep -c '^branch:')" == "0" ]] && \
   grep -q '^branch: agent/issue-107$' "tickets/${TICKET}/ticket.md"; then
    pass "branch: exists only on the agent branch (fixture)"
else
    fail "fixture wrong" "$(git show "main:tickets/${TICKET}/ticket.md" | sed -n '1,10p')"
fi

OUT=$(timeout 20 ./ticket.sh start "$TICKET" 2>&1)
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "agent/issue-107" ]]; then
    pass "start honours the override and stays on agent/issue-107"
else
    fail "start ignored branch: and moved elsewhere" "$(git rev-parse --abbrev-ref HEAD)
$OUT"
fi
if ! git show-ref --verify --quiet "refs/heads/feature/${TICKET}"; then
    pass "no feature/<name> branch is invented"
else
    fail "start created the prefix-named branch anyway" "$(git branch --list)"
fi
if grep -q '^started_at: "\?20' "tickets/${TICKET}/ticket.md"; then
    pass "started_at is stamped"
else
    fail "started_at not set" "$(grep '^started_at' "tickets/${TICKET}/ticket.md")"
fi
# The base branch has the ticket, so this is not the own-branch path: the
# fast-forward that keeps `list` honest from main must still happen.
if [[ -n "$(started_at_on_main "$TICKET")" ]]; then
    pass "the start time still reaches the base branch"
else
    fail "the base branch was not fast-forwarded" "$(git log --oneline main -3)"
fi
if ! echo "$OUT" | grep -q "has no copy of this ticket"; then
    pass "the own-branch path is not taken"
else
    fail "took the own-branch path when the base had the ticket" "$OUT"
fi
# And it says so plainly: detouring through the base branch, only to check this
# one out again, left a "creating a new feature branch from 'main' instead"
# warning standing that never came true - which reads exactly like the override
# being ignored.
if ! echo "$OUT" | grep -q "Creating new feature branch"; then
    pass "no warning about creating a feature branch from the base"
else
    fail "start still announces a branch it does not create" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "10. a ticket without the field behaves exactly as before"
REPO=$(make_repo plain)
cd "$REPO"
timeout 5 ./ticket.sh new ordinary >/dev/null 2>&1
TICKET=$(safe_get_ticket_name "*ordinary*")
if ! grep -q "^branch:" "tickets/${TICKET}/ticket.md"; then
    pass "no branch: field is written without --branch"
else
    fail "a branch: field appeared unasked" "$(sed -n '1,10p' "tickets/${TICKET}/ticket.md")"
fi
git add -A && git commit -q -m "Add ticket"
timeout 20 ./ticket.sh start "$TICKET" >/dev/null 2>&1
if [[ "$(git rev-parse --abbrev-ref HEAD)" == "feature/${TICKET}" ]]; then
    pass "start still uses {branch_prefix}<ticket-name>"
else
    fail "the default branch naming changed" "$(git rev-parse --abbrev-ref HEAD)"
fi
OUT=$(timeout 20 ./ticket.sh check 2>&1)
if [[ $? -eq 0 ]] && echo "$OUT" | grep -q "active and synchronized"; then
    pass "check is unchanged for such a ticket"
else
    fail "check changed for a plain ticket" "$OUT"
fi

# A branch that is neither prefixed nor claimed by any ticket is still not a
# feature branch - the override must not turn every branch into one.
cd "$REPO"
git checkout -q -b some/other-work
OUT=$(timeout 20 ./ticket.sh restore 2>&1)
if [[ $? -ne 0 ]] && echo "$OUT" | grep -q "Not on a feature branch"; then
    pass "an unrelated branch is still refused"
else
    fail "restore accepted an unrelated branch" "$OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "=== branch override Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

cd "$REPO_ROOT"
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
