#!/usr/bin/env bash

# Investigate priority sorting issue

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test directory
TEST_DIR="test-priority-$(date +%s)"

echo -e "${YELLOW}=== Investigating Priority Sorting ===${NC}"
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

echo "1. Creating tickets with different priorities..."
# Create tickets with different priorities
for i in 3 1 2; do
    ./ticket.sh new "priority-$i" >/dev/null 2>&1
    TICKET=$(ls tickets/*priority-$i.md | tail -1)
    sed -i.bak "s/priority: 2/priority: $i/" "$TICKET" 2>/dev/null || \
    sed -i '' "s/priority: 2/priority: $i/" "$TICKET"
    echo "Created ticket with priority $i"
done

echo -e "\n2. Checking initial list (all todo)..."
./ticket.sh list

echo -e "\n3. Starting priority-2 ticket..."
git add . && git commit -q -m "add all"
TICKET_2=$(ls tickets/*priority-2.md | xargs basename | sed 's/.md$//')
./ticket.sh start "$TICKET_2" --no-push >/dev/null 2>&1
git add . && git commit -q -m "start"
git checkout -q develop

echo -e "\n4. List after starting priority-2 (should be first as 'doing')..."
./ticket.sh list

echo -e "\n5. Detailed list output analysis..."
echo "Raw output:"
./ticket.sh list 2>&1 | cat -n

echo -e "\n6. Extracting first ticket info..."
LIST_OUTPUT=$(./ticket.sh list 2>&1)
echo "Full output between ticket list and first ticket:"
echo "$LIST_OUTPUT" | sed -n '/Ticket List/,/ticket_name:/p'

echo -e "\n7. Testing grep pattern..."
echo "Using grep -A1 pattern:"
echo "$LIST_OUTPUT" | grep -A1 "ticket_name:" | head -2

echo -e "\n8. Getting just the first ticket name:"
FIRST_TICKET=$(echo "$LIST_OUTPUT" | grep "ticket_name:" | head -1 | awk '{print $2}')
echo "First ticket: $FIRST_TICKET"

echo -e "\n9. Checking ticket files and their status..."
for ticket in tickets/*.md; do
    echo -e "\nFile: $ticket"
    echo "Content:"
    head -10 "$ticket"
done

# Cleanup
cd ../..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== Investigation Complete ===${NC}"