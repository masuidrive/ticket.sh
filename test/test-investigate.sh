#!/usr/bin/env bash

# Investigate failing test cases
set -e

echo "=== Investigating test failures ==="
echo

# Setup
TEST_DIR="test-investigate"
rm -rf "$TEST_DIR"
mkdir "$TEST_DIR"
cd "$TEST_DIR"
cp ../../ticket.sh .

# Initialize
git init -q
git config user.name "Test"
git config user.email "test@test.com"
echo "test" > README.md
git add . && git commit -q -m "init"
git checkout -q -b develop
./ticket.sh init >/dev/null

# Create and start ticket
./ticket.sh new test-feature >/dev/null
git add . && git commit -q -m "add ticket"
TICKET_NAME=$(ls tickets/*.md | xargs basename | sed 's/.md$//')
./ticket.sh start "$TICKET_NAME" --no-push >/dev/null

echo "1. Current state after start:"
echo "   Branch: $(git branch --show-current)"
echo "   current-ticket.md exists: $(test -L current-ticket.md && echo "yes" || echo "no")"
echo "   current-ticket.md points to: $(readlink current-ticket.md 2>/dev/null || echo "missing")"
echo

# Make work
echo "work" > work.txt
git add work.txt && git commit -q -m "work"

echo "2. Testing close command:"
echo "   Running: ./ticket.sh close --no-push"
CLOSE_OUTPUT=$(./ticket.sh close --no-push 2>&1)
CLOSE_EXIT=$?

echo "   Exit code: $CLOSE_EXIT"
echo "   Output:"
echo "$CLOSE_OUTPUT" | sed 's/^/     /'
echo

echo "3. State after close attempt:"
echo "   Branch: $(git branch --show-current)"
echo "   current-ticket.md exists: $(test -L current-ticket.md && echo "yes" || echo "no")"
echo

echo "4. Checking ticket status:"
if [[ -f tickets/*.md ]]; then
    echo "   Ticket file contents (timestamps only):"
    grep -E "(started_at|closed_at):" tickets/*.md | sed 's/^/     /'
else
    echo "   No ticket files found!"
fi
echo

echo "5. Testing list --status done:"
echo "   Running: ./ticket.sh list --status done"
LIST_OUTPUT=$(./ticket.sh list --status done 2>&1)
echo "   Output:"
echo "$LIST_OUTPUT" | sed 's/^/     /'
echo

echo "6. Debug: What tickets exist?"
ls -la tickets/ | sed 's/^/     /'
echo

echo "7. Debug: Git log"
git log --oneline -5 | sed 's/^/     /'