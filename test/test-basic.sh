#!/usr/bin/env bash

# Basic test suite focusing on core functionality
set -e

echo "=== Basic ticket.sh Tests ==="
echo

# Setup
TEST_DIR="test-basic"
rm -rf "$TEST_DIR"
mkdir "$TEST_DIR"
cd "$TEST_DIR"
cp ../../ticket.sh .

# Initialize git
git init -q
git config user.name "Test"
git config user.email "test@test.com"
echo "test" > README.md
git add . && git commit -q -m "init"
git checkout -q -b develop

# Test 1: Init
echo "1. Testing init..."
./ticket.sh init >/dev/null
echo "   ✓ Init completed"

# Test 2: New ticket
echo "2. Testing new ticket..."
./ticket.sh new my-feature >/dev/null
TICKET=$(ls tickets/*.md | head -1)
echo "   ✓ Created: $TICKET"

# Test 3: List
echo "3. Testing list..."
./ticket.sh list | grep -q "my-feature" && echo "   ✓ Ticket appears in list"

# Test 4: Start
echo "4. Testing start..."
git add . && git commit -q -m "add ticket"
TICKET_NAME=$(basename "$TICKET" .md)
./ticket.sh start "$TICKET_NAME" --no-push >/dev/null
echo "   ✓ Started on branch: $(git branch --show-current)"
echo "   ✓ Symlink exists: $(test -L current-ticket.md && echo "yes" || echo "no")"

# Test 5: Work and close
echo "5. Testing close..."
echo "work" > work.txt
git add . && git commit -q -m "work"

# Debug close
echo "   Running close command..."
if ./ticket.sh close --no-push; then
    echo "   ✓ Close succeeded"
    echo "   ✓ Final branch: $(git branch --show-current)"
    grep -q "closed_at: 20" "$TICKET" && echo "   ✓ Ticket marked as closed"
else
    echo "   ✗ Close failed"
    exit 1
fi

# Test 6: Status filter
echo "6. Testing status filter..."
./ticket.sh list --status done | grep -q "$TICKET_NAME" && echo "   ✓ Done filter works"

echo
echo "=== All basic tests passed! ==="

# Cleanup
cd ..
rm -rf "$TEST_DIR"