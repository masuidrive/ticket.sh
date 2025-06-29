#!/usr/bin/env bash

# Verify priority sorting with correct branch handling

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test directory
TEST_DIR="test-verify-$(date +%s)"

echo -e "${YELLOW}=== Verifying Priority Sorting ===${NC}"
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
for i in 3 1 2; do
    ./ticket.sh new "priority-$i" >/dev/null 2>&1
    TICKET=$(ls tickets/*priority-$i.md | tail -1)
    sed -i.bak "s/priority: 2/priority: $i/" "$TICKET" 2>/dev/null || \
    sed -i '' "s/priority: 2/priority: $i/" "$TICKET"
done

echo -e "\n2. Committing all tickets..."
git add . && git commit -q -m "add all tickets"

echo -e "\n3. Starting priority-2 ticket..."
TICKET_2=$(ls tickets/*priority-2.md | xargs basename | sed 's/.md$//')
./ticket.sh start "$TICKET_2" --no-push >/dev/null 2>&1

echo -e "\n4. We are now on feature branch. Committing the started_at change..."
git add . && git commit -q -m "start ticket"

echo -e "\n5. Merging back to develop to make started_at visible there..."
git checkout -q develop
git merge --no-ff -q "feature/$TICKET_2" -m "Merge feature branch"

echo -e "\n6. Now checking list from develop branch..."
./ticket.sh list

echo -e "\n7. Verifying first ticket in list..."
FIRST_TICKET=$(./ticket.sh list 2>&1 | grep "ticket_name:" | head -1 | awk '{print $2}')
echo "First ticket shown: $FIRST_TICKET"

if [[ "$FIRST_TICKET" == *"priority-2"* ]]; then
    echo -e "${GREEN}✓ Correct! Priority-2 (doing) is shown first${NC}"
else
    echo -e "${RED}✗ Incorrect. Expected priority-2 to be first${NC}"
fi

# Cleanup
cd ../..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== Verification Complete ===${NC}"