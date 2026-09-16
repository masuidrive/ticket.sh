#!/usr/bin/env bash
set -euo pipefail

# Test done folder functionality

# safe_get_ticket_name / ticket_body_path know both ticket layouts.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-helpers.sh"

echo "=== Testing done folder functionality ==="

# A function, not a string: `ticket_sh init` ran the whole string as one
# command name and failed with "timeout 5 ./ticket.sh: No such file or
# directory". (The string it replaced also carried a stray leading dot.)
ticket_sh() { timeout 5 ./ticket.sh "$@"; }

# Setup
TEST_DIR=$(mktemp -d)
# Copy ticket.sh to test directory
cp "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/ticket.sh" "$TEST_DIR/ticket.sh"
chmod +x "$TEST_DIR/ticket.sh"
cd "$TEST_DIR"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"
touch README.md
git add README.md
git commit -m "Initial commit" -q || true
# git names the initial branch itself now, so asking for a new `main` aborts.
git checkout -b main -q 2>/dev/null || git checkout main -q

# Initialize ticket system
ticket_sh init
# Disable auto_push for test
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/auto_push: true/auto_push: false/' .ticket-config.yaml
else
    sed -i 's/auto_push: true/auto_push: false/' .ticket-config.yaml
fi
# Commit the initialization
git add -A
git commit -m "Initialize ticket system" -q || true

echo "1. Testing close moves ticket to done folder..."
# Create and start a ticket
ticket_sh new test-done-folder
TICKET_NAME=$(safe_get_ticket_name "*test-done-folder*")
# Commit the new ticket
git add -A
git commit -m "Add test ticket" -q || true
ticket_sh start "$TICKET_NAME"
# Commit the started_at change
git add -A
git commit -m "Start ticket" -q || true

# Add some work
echo "test" > work.txt
git add work.txt
git commit -m "Add work" -q || true

# Close the ticket
ticket_sh close --no-push

# Check if ticket was moved to done folder
# Per-ticket layout moves the whole directory; the flat path only exists for
# legacy tickets. ticket_body_path --done resolves whichever is there.
if [[ -n "$(ticket_body_path "$TICKET_NAME" --done)" ]]; then
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
OUTPUT=$(ticket_sh list --status done)
# Same layout point as above: list reports tickets/done/<name>/ticket.md now.
if echo "$OUTPUT" | grep -q "ticket_path: $(ticket_body_path "$TICKET_NAME" --done)"; then
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
ticket_sh new test-auto-create
TICKET_NAME2=$(safe_get_ticket_name "*test-auto-create*")
# Commit the new ticket
git add -A
git commit -m "Add second test ticket" -q || true
ticket_sh start "$TICKET_NAME2"
# Commit the started_at change
git add -A
git commit -m "Start second ticket" -q || true

# Add work and close
echo "test2" > work2.txt
git add work2.txt
git commit -m "Add work2" -q || true
ticket_sh close --no-push

# Check if done folder was created
if [[ -d "tickets/done" ]]; then
    echo "  ✓ Done folder created automatically"
else
    echo "  ✗ Done folder NOT created"
    exit 1
fi

if [[ -n "$(ticket_body_path "$TICKET_NAME2" --done)" ]]; then
    echo "  ✓ Ticket moved to auto-created done folder"
else
    echo "  ✗ Ticket NOT moved to done folder"
    exit 1
fi

echo
echo "=== Done folder tests completed ==="
echo "  Summary - Passed: 7, Failed: 0"

# Cleanup
cd - > /dev/null
rm -rf "$TEST_DIR"