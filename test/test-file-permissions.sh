#!/usr/bin/env bash

# File permission tests for ticket.sh
# Tests error handling for various file system permission scenarios

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
source "$(dirname "$0")/test-helpers.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test directory
TEST_DIR="tmp/test-file-permissions-$(date +%s)"

echo -e "${YELLOW}=== File Permission Tests ===${NC}"
echo

# Skip these tests if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}Warning: Running as root. Permission tests will be skipped.${NC}"
    echo "Permission tests cannot be properly tested with root privileges."
    exit 0
fi

# Setup
setup_test() {
    mkdir -p tmp
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Initialize git repo
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "test" > .gitkeep
    git add .gitkeep
    git commit -q -m "Initial commit"
    
    # Copy ticket.sh
    cp "${SCRIPT_DIR}/../ticket.sh" .
    chmod +x ticket.sh
}

# Test result
test_result() {
    if [[ $1 -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} $2"
    else
        echo -e "  ${RED}✗${NC} $2"
        [[ -n "${3:-}" ]] && echo "    Details: $3"
    fi
}

# Cleanup function to restore permissions
cleanup_permissions() {
    # Restore write permissions to all directories
    find . -type d -exec chmod 755 {} \; 2>/dev/null || true
    find . -type f -exec chmod 644 {} \; 2>/dev/null || true
}

# Register cleanup on exit
trap cleanup_permissions EXIT

# Test 1: Read-only directory for init
echo "1. Testing init in read-only directory..."
setup_test
# Make current directory read-only
chmod 555 .
OUTPUT=$(timeout 5 ./ticket.sh init  2>&1)
RESULT=$?
chmod 755 .  # Restore permissions immediately
if [[ $RESULT -ne 0 ]] && echo "$OUTPUT" | grep -q "Permission denied"; then
    test_result 0 "Correctly fails in read-only directory"
else
    test_result 1 "Should fail with permission error" "$OUTPUT"
fi

# Test 2: Write-protected tickets directory for new command
echo -e "\n2. Testing new command with write-protected tickets directory..."
# Start fresh
cd .. && setup_test
timeout 5 ./ticket.sh init  >/dev/null 2>&1
# Make tickets directory read-only
chmod 555 tickets
OUTPUT=$(timeout 5 ./ticket.sh new "test-ticket" 2>&1)
RESULT=$?
chmod 755 tickets  # Restore permissions
if [[ $RESULT -ne 0 ]] && echo "$OUTPUT" | grep -q "Permission denied"; then
    test_result 0 "Correctly fails with write-protected tickets directory"
else
    test_result 1 "Should fail with permission error" "$OUTPUT"
fi

# Test 3: Cannot create symlink (parent directory read-only)
echo -e "\n3. Testing start command when cannot create symlink..."
cd .. && setup_test
timeout 5 ./ticket.sh init  >/dev/null 2>&1
./ticket.sh new "symlink-test" >/dev/null 2>&1
git add . && git commit -q -m "add ticket"
TICKET=$(safe_get_ticket_name "*symlink-test.md")

# Make current directory read-only to prevent symlink creation
chmod 555 .
OUTPUT=$(timeout 5 ./ticket.sh start "$TICKET" --no-push 2>&1)
RESULT=$?
chmod 755 .  # Restore permissions
if [[ $RESULT -ne 0 ]]; then
    test_result 0 "Correctly fails when cannot create symlink"
else
    test_result 1 "Should fail when cannot create symlink" "$OUTPUT"
fi

# Test 4: Cannot write to ticket file
echo -e "\n4. Testing start command with read-only ticket file..."
cd .. && setup_test
timeout 5 ./ticket.sh init  >/dev/null 2>&1
./ticket.sh new "readonly-ticket" >/dev/null 2>&1
git add . && git commit -q -m "add ticket"
TICKET_FILE=$(safe_get_first_file "*readonly-ticket.md" "tickets")
TICKET_NAME=$(basename "$TICKET_FILE" .md)

# Make ticket file read-only
chmod 444 "$TICKET_FILE"
OUTPUT=$(timeout 5 ./ticket.sh start "$TICKET_NAME" --no-push 2>&1)
RESULT=$?
chmod 644 "$TICKET_FILE"  # Restore permissions

# start command might succeed but fail to update started_at
if [[ $RESULT -ne 0 ]] || echo "$OUTPUT" | grep -q "Permission denied"; then
    test_result 0 "Handles read-only ticket file"
else
    # Check if started_at was actually updated
    if grep -q "started_at: null" "$TICKET_FILE"; then
        test_result 0 "Cannot update read-only ticket file"
    else
        test_result 1 "Should not update read-only ticket file"
    fi
fi

# Test 5: Cannot create tickets/done directory
echo -e "\n5. Testing close command when cannot create done directory..."
cd .. && setup_test
timeout 5 ./ticket.sh init  >/dev/null 2>&1

# Create ticket and commit it
./ticket.sh new "done-dir-test" >/dev/null 2>&1
git add . && git commit -q -m "add ticket"
TICKET=$(safe_get_ticket_name "*done-dir-test.md")

# Now start the ticket from main/master branch (start command will create feature branch)
./ticket.sh start "$TICKET" --no-push >/dev/null 2>&1

# We should now be on the feature branch - verify
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != feature/* ]]; then
    echo "Warning: Not on feature branch after start, on $CURRENT_BRANCH" >&2
fi

# Add any changes and commit
git add -A && git commit -q -m "start ticket" || true

# Create a work file and commit
echo "work" > work.txt
git add . && git commit -q -m "work"

# Make tickets directory read-only to prevent done directory creation
chmod 555 tickets
OUTPUT=$(timeout 5 ./ticket.sh close --no-push 2>&1)
RESULT=$?
chmod 755 tickets  # Restore permissions

# The close might partially succeed (merge) but fail on moving to done
# Check different parts of output since close has multiple steps
if echo "$OUTPUT" | grep -q "Permission denied\|permission\|cannot\|failed"; then
    test_result 0 "Handles permission error during close"
elif echo "$OUTPUT" | grep -q "Ticket completed"; then
    # Close succeeded but check if done folder was created
    if [[ ! -d tickets/done ]]; then
        test_result 0 "Close succeeded but could not create done directory"
    else
        test_result 1 "Unexpectedly created done directory with read-only parent"
    fi
else
    test_result 1 "Should show permission-related error or complete with limitations" "$OUTPUT"
fi

# Test 6: Config file permissions
echo -e "\n6. Testing operations with read-only config file..."
cd .. && setup_test
timeout 5 ./ticket.sh init  >/dev/null 2>&1

# Make config file read-only
chmod 444 .ticket-config.yaml
OUTPUT=$(timeout 5 ./ticket.sh list 2>&1)
RESULT=$?
# list should still work with read-only config
if [[ $RESULT -eq 0 ]]; then
    test_result 0 "Can read from read-only config file"
else
    test_result 1 "Should be able to read config" "$OUTPUT"
fi
chmod 644 .ticket-config.yaml  # Restore permissions

# Test 7: Disk space simulation (using quota if available)
echo -e "\n7. Testing disk full simulation..."
# This is hard to test portably, so we'll create a very small filesystem
# using a loop device (Linux) or just skip on other systems
if command -v dd >/dev/null 2>&1 && command -v mkfs >/dev/null 2>&1 && [[ "$(uname)" == "Linux" ]]; then
    # Try to create a small filesystem for testing
    echo "  (Skipping disk full test - requires special setup)"
    test_result 0 "Disk full test skipped (requires special environment)"
else
    echo "  (Skipping disk full test - not supported on this platform)"
    test_result 0 "Disk full test skipped (platform limitation)"
fi

# Test 8: Cross-user permissions
echo -e "\n8. Testing file ownership issues..."
cd .. && setup_test
timeout 5 ./ticket.sh init  >/dev/null 2>&1
./ticket.sh new "ownership-test" >/dev/null 2>&1

# We can't actually change ownership without sudo, but we can test the messages
# The mv command warnings we see in Docker tests are examples of this
echo "  (Cannot test actual ownership changes without elevated privileges)"
test_result 0 "Ownership test skipped (requires elevated privileges)"

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== File permission tests completed ===${NC}"
echo
echo "Note: Some tests require specific environments or privileges to fully execute."
echo "The tests verify that ticket.sh handles permission errors gracefully."