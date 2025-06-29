#!/usr/bin/env bash
set -euo pipefail

# Test done folder functionality

echo "=== Testing done folder functionality ==="

# Get ticket.sh path
if [[ -z "${TICKET_SH:-}" ]]; then
    TICKET_SH="../ticket.sh"
fi

# Setup
TEST_DIR=$(mktemp -d)
# Copy ticket.sh to test directory
cp "$TICKET_SH" "$TEST_DIR/ticket.sh"
chmod +x "$TEST_DIR/ticket.sh"
cd "$TEST_DIR"
TICKET_SH="./ticket.sh"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"
touch README.md
git add README.md
git commit -m "Initial commit" -q
git checkout -b develop -q

# Initialize ticket system
"$TICKET_SH" init
# Disable auto_push for test
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/auto_push: true/auto_push: false/' .ticket-config.yml
else
    sed -i 's/auto_push: true/auto_push: false/' .ticket-config.yml
fi
# Commit the initialization
git add -A
git commit -m "Initialize ticket system" -q

echo "1. Testing close moves ticket to done folder..."
# Create and start a ticket
"$TICKET_SH" new test-done-folder
TICKET_NAME=$(ls tickets/*.md | head -1 | xargs basename | sed 's/\.md$//')
# Commit the new ticket
git add -A
git commit -m "Add test ticket" -q
"$TICKET_SH" start "$TICKET_NAME"
# Commit the started_at change
git add -A
git commit -m "Start ticket" -q

# Add some work
echo "test" > work.txt
git add work.txt
git commit -m "Add work" -q

# Close the ticket
"$TICKET_SH" close --no-push

# Check if ticket was moved to done folder
if [[ -f "tickets/done/${TICKET_NAME}.md" ]]; then
    echo "  ✓ Ticket moved to done folder"
else
    echo "  ✗ Ticket NOT moved to done folder"
    exit 1
fi

# Check if original location is empty
if [[ ! -f "tickets/${TICKET_NAME}.md" ]]; then
    echo "  ✓ Ticket removed from original location"
else
    echo "  ✗ Ticket still exists in original location"
    exit 1
fi

echo "2. Testing list shows done tickets with path..."
OUTPUT=$("$TICKET_SH" list --status done)
if echo "$OUTPUT" | grep -q "ticket_path: tickets/done/${TICKET_NAME}.md"; then
    echo "  ✓ List shows correct ticket_path for done tickets"
else
    echo "  ✗ List does not show correct ticket_path"
    echo "$OUTPUT"
    exit 1
fi

if echo "$OUTPUT" | grep -q "closed_at:"; then
    echo "  ✓ List shows closed_at for done tickets"
else
    echo "  ✗ List does not show closed_at"
    exit 1
fi

echo "3. Testing done folder is created automatically..."
# Remove done folder
rm -rf tickets/done

# Create another ticket
"$TICKET_SH" new test-auto-create
TICKET_NAME2=$(ls tickets/*.md | grep -v done | tail -1 | xargs basename | sed 's/\.md$//')
# Commit the new ticket
git add -A
git commit -m "Add second test ticket" -q
"$TICKET_SH" start "$TICKET_NAME2"
# Commit the started_at change
git add -A
git commit -m "Start second ticket" -q

# Add work and close
echo "test2" > work2.txt
git add work2.txt
git commit -m "Add work2" -q
"$TICKET_SH" close --no-push

# Check if done folder was created
if [[ -d "tickets/done" ]]; then
    echo "  ✓ Done folder created automatically"
else
    echo "  ✗ Done folder NOT created"
    exit 1
fi

if [[ -f "tickets/done/${TICKET_NAME2}.md" ]]; then
    echo "  ✓ Ticket moved to auto-created done folder"
else
    echo "  ✗ Ticket NOT moved to done folder"
    exit 1
fi

echo
echo "=== Done folder tests completed ==="
echo "  Summary - All tests passed!"

# Cleanup
cd - > /dev/null
rm -rf "$TEST_DIR"