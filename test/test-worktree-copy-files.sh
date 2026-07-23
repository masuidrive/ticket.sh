#!/usr/bin/env bash

# Regression tests for worktree_copy_files (config + --copy-file flag).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo "=== ticket.sh worktree_copy_files Test Suite ==="
echo

TEST_DIR="tmp/test-worktree-copy-files-$(date +%s)"
mkdir -p tmp
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Always rebuild so the harness runs against current sources.
(cd "${SCRIPT_DIR}/.." && ./build.sh >/dev/null 2>&1)
cp "${SCRIPT_DIR}/../ticket.sh" .
chmod +x ticket.sh

PASSED=0
FAILED=0
# Use ✓/✗ marks so run-all.sh's grep-based counter picks them up.
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAILED=$((FAILED + 1)); }

# ---------------------------------------------------------------------------
# Setup git repo
# ---------------------------------------------------------------------------
echo "Setting up git repo..."
git init -q -b main
git config user.name "Test"
git config user.email "test@test.com"
echo "# Test" > README.md
# Test fixtures are gitignored — this is the documented prerequisite for
# worktree_copy_files (target file must not already be materialized in the
# worktree via git checkout).
cat > .gitignore <<'EOF'
.env
.env.local
file_b.txt
file_c.txt
EOF
git add README.md .gitignore
git commit -q -m "Initial"

timeout 10 ./ticket.sh init >/dev/null 2>&1
git add . && git commit -q -m "Init ticket system"

MAIN_REPO=$(pwd)
CONFIG=".ticket-config.yaml"
echo "  Setup complete"
echo

# ---------------------------------------------------------------------------
# Helper: make a fresh ticket, echo its bare name, commit it.
# ---------------------------------------------------------------------------
make_ticket() {
    local slug="$1"
    timeout 5 ./ticket.sh new "$slug" >/dev/null 2>&1
    local name
    name=$(safe_get_ticket_name "*${slug}*")
    git add . && git commit -q -m "Add ticket $slug"
    echo "$name"
}

# Helper: read WORKTREE:<abs> line out of start output.
extract_wt() {
    echo "$1" | grep "^WORKTREE:" | head -1 | cut -d: -f2-
}

# Helper: prune leftover worktree so subsequent starts don't collide.
cleanup_wt() {
    local wt="$1"
    [[ -z "$wt" ]] && return 0
    git -C "$MAIN_REPO" worktree remove --force "$wt" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 1. Default config (empty worktree_copy_files) → no copy happens
# ---------------------------------------------------------------------------
echo "1. Default config (empty list) → no copy"
echo 'SECRET_A=a' > .env
TICKET1=$(make_ticket "default-empty")
OUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET1" 2>&1)
WT1=$(extract_wt "$OUT")

if [[ -n "$WT1" ]] && [[ -d "$WT1" ]]; then
    pass "Worktree created"
else
    fail "Worktree not created — output was: $OUT"
fi

if echo "$OUT" | grep -q "worktree_copy_files"; then
    fail "Default config emitted worktree_copy_files output (should have been silent)"
else
    pass "No worktree_copy_files output on default config"
fi

if [[ -e "${WT1}/.env" ]]; then
    fail ".env was copied to worktree despite default config"
else
    pass ".env not present in worktree (default = no copy)"
fi
cleanup_wt "$WT1"
echo

# ---------------------------------------------------------------------------
# 2. Config-enabled + source exists → copied into worktree
# ---------------------------------------------------------------------------
echo "2. Config-enabled + source exists → copied"
# Replace the default empty list with a real entry.
sed -i.bak '/^worktree_copy_files: \[\]/d' "$CONFIG"
rm -f "${CONFIG}.bak"
cat >> "$CONFIG" <<'EOF'

worktree_copy_files:
  - .env
EOF
git add "$CONFIG" && git commit -q -m "Enable worktree_copy_files"

TICKET2=$(make_ticket "config-enabled")
OUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET2" 2>&1)
WT2=$(extract_wt "$OUT")

if echo "$OUT" | grep -q "worktree_copy_files: copied .env"; then
    pass "Emits 'copied' line for .env"
else
    fail "Missing 'copied .env' output"
    echo "  Output: $OUT"
fi

if [[ -f "${WT2}/.env" ]] && grep -q '^SECRET_A=a$' "${WT2}/.env"; then
    pass ".env copied with correct content"
else
    fail ".env missing or wrong content in worktree"
fi
echo

# ---------------------------------------------------------------------------
# 3. Config-enabled + target already exists → skip (no overwrite)
# ---------------------------------------------------------------------------
echo "3. Target exists → skip (no overwrite)"
# WT2 already has .env from #2. Overwrite the target to prove we skip it.
echo 'TARGET_LOCAL_VALUE' > "${WT2}/.env"
# Re-run start on the same ticket → resume path.
OUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET2" 2>&1)

if echo "$OUT" | grep -q "worktree_copy_files: target already exists, skipping: .env"; then
    pass "Emits 'target already exists, skipping' line"
else
    fail "Missing skip output"
    echo "  Output: $OUT"
fi

if grep -q '^TARGET_LOCAL_VALUE$' "${WT2}/.env"; then
    pass "Target .env content preserved (not overwritten)"
else
    fail "Target .env was overwritten"
fi
cleanup_wt "$WT2"
echo

# ---------------------------------------------------------------------------
# 4. Config-enabled + source missing → warn, exit 0, no copy
# ---------------------------------------------------------------------------
echo "4. Source missing → warn only, continue"
rm -f .env  # source no longer exists

TICKET4=$(make_ticket "missing-source")
set +e
OUT=$(timeout 10 ./ticket.sh start --worktree "$TICKET4" 2>&1)
EXIT4=$?
set -e
WT4=$(extract_wt "$OUT")

if [[ "$EXIT4" -eq 0 ]]; then
    pass "start exit code is 0 despite missing source"
else
    fail "start exited non-zero (exit=$EXIT4)"
fi

if echo "$OUT" | grep -q "Warning: worktree_copy_files source not found, skipping: .env"; then
    pass "Warning emitted for missing source"
else
    fail "Missing warning output"
    echo "  Output: $OUT"
fi

if [[ -n "$WT4" ]] && [[ ! -e "${WT4}/.env" ]]; then
    pass "No .env copied when source missing"
else
    fail ".env unexpectedly present or worktree missing"
fi
cleanup_wt "$WT4"
echo

# ---------------------------------------------------------------------------
# 5. Empty config + --copy-file CLI → single override works
# ---------------------------------------------------------------------------
echo "5. Empty config + --copy-file CLI single-flag"
# Reset config back to default empty list.
sed -i.bak '/^worktree_copy_files:/,/^$/d' "$CONFIG"
rm -f "${CONFIG}.bak"
printf '\nworktree_copy_files: []\n' >> "$CONFIG"
git add "$CONFIG" && git commit -q -m "Reset worktree_copy_files to empty"

echo 'CLI_ONLY=1' > .env
TICKET5=$(make_ticket "cli-single")
OUT=$(timeout 10 ./ticket.sh start --worktree --copy-file .env "$TICKET5" 2>&1)
WT5=$(extract_wt "$OUT")

if echo "$OUT" | grep -q "worktree_copy_files: copied .env"; then
    pass "CLI --copy-file triggered copy on empty-config repo"
else
    fail "CLI --copy-file did not trigger copy"
    echo "  Output: $OUT"
fi

if [[ -f "${WT5}/.env" ]] && grep -q '^CLI_ONLY=1$' "${WT5}/.env"; then
    pass "CLI-copied .env has correct content"
else
    fail "CLI-copied .env missing or wrong content"
fi
cleanup_wt "$WT5"
echo

# ---------------------------------------------------------------------------
# 6. Multiple --copy-file flags accumulate
# ---------------------------------------------------------------------------
echo "6. Multiple --copy-file flags"
echo 'B=2' > file_b.txt
echo 'C=3' > file_c.txt

TICKET6=$(make_ticket "cli-multi")
OUT=$(timeout 10 ./ticket.sh start --worktree \
    --copy-file file_b.txt --copy-file file_c.txt "$TICKET6" 2>&1)
WT6=$(extract_wt "$OUT")

if echo "$OUT" | grep -q "worktree_copy_files: copied file_b.txt" \
   && echo "$OUT" | grep -q "worktree_copy_files: copied file_c.txt"; then
    pass "Both files reported as copied"
else
    fail "Missing copied lines for one or both files"
    echo "  Output: $OUT"
fi

if [[ -f "${WT6}/file_b.txt" ]] && [[ -f "${WT6}/file_c.txt" ]]; then
    pass "Both files present in worktree"
else
    fail "One or both files missing from worktree"
fi
cleanup_wt "$WT6"
echo

# ---------------------------------------------------------------------------
# 7. --copy-file merges with config entries (both apply)
# ---------------------------------------------------------------------------
echo "7. Config + --copy-file merged"
# Re-enable config with .env only, then add file_b via CLI.
sed -i.bak '/^worktree_copy_files:/,/^$/d' "$CONFIG"
rm -f "${CONFIG}.bak"
cat >> "$CONFIG" <<'EOF'

worktree_copy_files:
  - .env
EOF
git add "$CONFIG" && git commit -q -m "Enable .env only"

echo 'MERGED_ENV=y' > .env
echo 'MERGED_B=y' > file_b.txt
TICKET7=$(make_ticket "merged")
OUT=$(timeout 10 ./ticket.sh start --worktree --copy-file file_b.txt "$TICKET7" 2>&1)
WT7=$(extract_wt "$OUT")

if [[ -f "${WT7}/.env" ]] && [[ -f "${WT7}/file_b.txt" ]]; then
    pass "Both config entry (.env) and CLI entry (file_b.txt) copied"
else
    fail "Merge failed: .env=$([[ -f ${WT7}/.env ]] && echo present || echo MISSING), file_b.txt=$([[ -f ${WT7}/file_b.txt ]] && echo present || echo MISSING)"
fi
cleanup_wt "$WT7"
echo

# ---------------------------------------------------------------------------
# 8. --copy-file without --worktree is silently ignored (no copy happens)
# ---------------------------------------------------------------------------
echo "8. --copy-file without --worktree → ignored"
TICKET8=$(make_ticket "no-worktree")
# Non-worktree start switches cwd's branch. Fresh repo, main is clean → safe.
OUT=$(timeout 10 ./ticket.sh start --copy-file .env "$TICKET8" 2>&1)

if echo "$OUT" | grep -q "worktree_copy_files"; then
    fail "worktree_copy_files acted despite no --worktree"
    echo "  Output: $OUT"
else
    pass "worktree_copy_files silent when no worktree is created"
fi
# Restore state for next section.
git checkout -q main

echo
echo "=== worktree_copy_files Test Results ==="
echo "  Passed: $PASSED, Failed: $FAILED"
echo

# Cleanup
cd "${SCRIPT_DIR}/.."
git worktree prune 2>/dev/null || true
rm -rf "$TEST_DIR"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
