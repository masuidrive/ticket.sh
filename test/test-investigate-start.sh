#!/usr/bin/env bash

# Investigate start command issue

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test directory
TEST_DIR="test-start-$(date +%s)"

echo -e "${YELLOW}=== Investigating Start Command ===${NC}"
echo

# Setup
mkdir "$TEST_DIR"
cd "$TEST_DIR"
cp ../../ticket.sh .
git init -q
git config user.name "Test"
git config user.email "test@test.com"
echo "test" > README.md
git add . && git commit -q -m "init"
git checkout -q -b develop
./ticket.sh init >/dev/null

echo "1. Creating a test ticket..."
./ticket.sh new "test-start" 2>&1
TICKET=$(ls tickets/*test-start.md | xargs basename | sed 's/.md$//')
echo "Ticket created: $TICKET"

echo -e "\n2. Checking initial ticket content..."
cat tickets/*.md

echo -e "\n3. Committing changes before start..."
git add . && git commit -m "add ticket" 2>&1

echo -e "\n4. Current branch before start:"
git branch --show-current

echo -e "\n5. Running start command with verbose output..."
./ticket.sh start "$TICKET" --no-push 2>&1

echo -e "\n6. Current branch after start:"
git branch --show-current

echo -e "\n7. Checking ticket content after start..."
cat tickets/*.md

echo -e "\n8. Checking if current-ticket.md exists:"
ls -la current-ticket.md 2>&1 || echo "current-ticket.md not found"

echo -e "\n9. Git status:"
git status

echo -e "\n10. All branches:"
git branch -a

# Cleanup
cd ../..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== Investigation Complete ===${NC}"