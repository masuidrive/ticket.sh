#!/usr/bin/env bash

# Comprehensive test suite for ticket.sh
set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test configuration
TEST_DIR="test-comprehensive-$(date +%s)"
ORIGINAL_DIR=$(pwd)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0

# Test functions
pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    [[ -n "${2:-}" ]] && echo "    Reason: $2"
    ((FAILED++))
}

section() {
    echo
    echo -e "${YELLOW}$1${NC}"
}

# Setup
setup() {
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    cp "${SCRIPT_DIR}/../src/ticket.sh" .
    chmod +x ticket.sh
    chmod +x ticket.sh
}

# Cleanup
cleanup() {
    cd "$ORIGINAL_DIR"
    rm -rf "$TEST_DIR"
}

# Run tests
run_tests() {
    section "=== ticket.sh Comprehensive Test Suite ==="
    
    # Test 1: Prerequisites
    section "1. Prerequisites and Error Handling"
    
    # No git repo
    local init_output=$(./ticket.sh init 2>&1 || true)
    if echo "$init_output" | grep -q "Not in a git repository"; then
        pass "Detects missing git repository"
    else
        fail "Should detect missing git repository"
    fi
    
    # Initialize git
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "# Test" > README.md
    git add README.md
    git commit -q -m "Initial commit"
    git checkout -q -b develop
    
    # No config
    local list_output=$(./ticket.sh list 2>&1 || true)
    if echo "$list_output" | grep -q "not initialized"; then
        pass "Detects missing config"
    else
        fail "Should detect missing config"
    fi
    
    # Test 2: Initialization
    section "2. Initialization"
    
    ./ticket.sh init >/dev/null 2>&1
    
    [[ -f .ticket-config.yml ]] && pass "Creates config file" || fail "Config file not created"
    [[ -d tickets ]] && pass "Creates tickets directory" || fail "Tickets directory not created"
    [[ -f .gitignore ]] && pass "Creates .gitignore" || fail ".gitignore not created"
    
    if grep -q "current-ticket.md" .gitignore; then
        pass "Adds current-ticket.md to .gitignore"
    else
        fail ".gitignore missing current-ticket.md"
    fi
    
    # Idempotency
    ./ticket.sh init >/dev/null 2>&1
    pass "Init is idempotent"
    
    # Test 3: Ticket Creation
    section "3. Ticket Creation"
    
    # Valid slugs
    ./ticket.sh new feature-abc >/dev/null 2>&1
    TICKET1=$(ls tickets/*feature-abc.md 2>/dev/null)
    [[ -n "$TICKET1" ]] && pass "Creates ticket with valid slug" || fail "Failed to create ticket"
    
    ./ticket.sh new bug-123 >/dev/null 2>&1
    pass "Creates ticket with numbers"
    
    ./ticket.sh new fix-something-important >/dev/null 2>&1
    pass "Creates ticket with hyphens"
    
    # Invalid slugs
    if ! ./ticket.sh new "Feature ABC" >/dev/null 2>&1; then
        pass "Rejects slug with spaces"
    else
        fail "Should reject slug with spaces"
    fi
    
    if ! ./ticket.sh new "UPPERCASE" >/dev/null 2>&1; then
        pass "Rejects uppercase slug"
    else
        fail "Should reject uppercase slug"
    fi
    
    if ! ./ticket.sh new "special@chars" >/dev/null 2>&1; then
        pass "Rejects special characters"
    else
        fail "Should reject special characters"
    fi
    
    # Check ticket content
    if grep -q "priority:" "$TICKET1"; then
        pass "Ticket has priority field"
    else
        fail "Ticket missing priority field"
    fi
    
    if grep -q "started_at: null" "$TICKET1"; then
        pass "Ticket has null started_at"
    else
        fail "Ticket started_at not null"
    fi
    
    # Test 4: Listing
    section "4. Ticket Listing"
    
    OUTPUT=$(./ticket.sh list 2>&1)
    if echo "$OUTPUT" | grep -q "feature-abc"; then
        pass "List shows created tickets"
    else
        fail "List doesn't show tickets"
    fi
    
    # Count limiting
    OUTPUT=$(./ticket.sh list --count 1 2>&1)
    COUNT=$(echo "$OUTPUT" | grep -c "ticket_name:" || true)
    [[ $COUNT -eq 1 ]] && pass "Count limit works" || fail "Count limit not working"
    
    # Invalid options
    if ! ./ticket.sh list --status invalid >/dev/null 2>&1; then
        pass "Rejects invalid status"
    else
        fail "Should reject invalid status"
    fi
    
    # Test 5: Starting Work
    section "5. Starting Work"
    
    # Commit changes first
    git add .
    git commit -q -m "Add tickets"
    
    # Start ticket
    TICKET_NAME=$(basename "$TICKET1" .md)
    ./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1
    
    # Commit the started_at change
    git add . >/dev/null 2>&1
    git commit -q -m "Update started_at" >/dev/null 2>&1
    
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$BRANCH" == "feature/$TICKET_NAME" ]]; then
        pass "Creates feature branch"
    else
        fail "Wrong branch: $BRANCH"
    fi
    
    [[ -L current-ticket.md ]] && pass "Creates current-ticket.md symlink" || fail "No symlink created"
    
    # Check ticket updated
    if ! grep -q "started_at: null" "$TICKET1"; then
        pass "Updates started_at timestamp"
    else
        fail "started_at not updated"
    fi
    
    # Try to start again
    git add . && git commit -q -m "Update"
    git checkout -q develop
    if ! ./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1; then
        pass "Cannot start already started ticket"
    else
        fail "Should not allow starting started ticket"
    fi
    
    # Wrong branch
    git checkout -q -b main
    if ! ./ticket.sh start bug-123 --no-push >/dev/null 2>&1; then
        pass "Cannot start from wrong branch"
    else
        fail "Should require develop branch"
    fi
    git checkout -q develop
    
    # Dirty working directory
    echo "dirty" > dirty.txt
    if ! ./ticket.sh start bug-123 --no-push >/dev/null 2>&1; then
        pass "Cannot start with uncommitted changes"
    else
        fail "Should require clean working directory"
    fi
    rm dirty.txt
    
    # Test 6: Restore
    section "6. Restore Function"
    
    git checkout -q "feature/$TICKET_NAME"
    rm -f current-ticket.md
    
    ./ticket.sh restore >/dev/null 2>&1
    [[ -L current-ticket.md ]] && pass "Restores symlink" || fail "Symlink not restored"
    
    # Wrong branch
    git checkout -q develop
    if ! ./ticket.sh restore >/dev/null 2>&1; then
        pass "Cannot restore on non-feature branch"
    else
        fail "Should only restore on feature branch"
    fi
    
    # Test 7: Closing Tickets
    section "7. Closing Tickets"
    
    git checkout -q "feature/$TICKET_NAME"
    
    # Make some work
    echo "work" > work.txt
    git add work.txt
    git commit -q -m "Do work"
    
    ./ticket.sh close --no-push >/dev/null 2>&1
    
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$BRANCH" == "develop" ]]; then
        pass "Returns to develop branch"
    else
        fail "Not on develop branch: $BRANCH"
    fi
    
    if ! grep -q "closed_at: null" "$TICKET1"; then
        pass "Updates closed_at timestamp"
    else
        fail "closed_at not updated"
    fi
    
    COMMIT_MSG=$(git log -1 --pretty=%s)
    if echo "$COMMIT_MSG" | grep -q "$TICKET_NAME"; then
        pass "Commit message includes ticket name"
    else
        fail "Commit message missing ticket name"
    fi
    
    [[ ! -L current-ticket.md ]] && pass "Removes current-ticket.md" || fail "current-ticket.md not removed"
    
    # Test 8: Status Filtering
    section "8. Status Filtering"
    
    # Create tickets in different states
    ./ticket.sh new todo-ticket >/dev/null 2>&1
    git add . && git commit -q -m "Add todo"
    
    ./ticket.sh new doing-ticket >/dev/null 2>&1
    git add . && git commit -q -m "Add doing"
    ./ticket.sh start doing-ticket --no-push >/dev/null 2>&1
    git add . && git commit -q -m "Start doing"
    git checkout -q develop
    
    # Test filters
    TODO_COUNT=$(./ticket.sh list --status todo 2>&1 | grep -c "status: todo" || true)
    DOING_COUNT=$(./ticket.sh list --status doing 2>&1 | grep -c "status: doing" || true)
    DONE_COUNT=$(./ticket.sh list --status done 2>&1 | grep -c "status: done" || true)
    
    [[ $TODO_COUNT -gt 0 ]] && pass "Filters todo tickets" || fail "Todo filter not working"
    [[ $DOING_COUNT -gt 0 ]] && pass "Filters doing tickets" || fail "Doing filter not working"
    [[ $DONE_COUNT -gt 0 ]] && pass "Filters done tickets" || fail "Done filter not working"
    
    # Default shows todo + doing only
    DEFAULT_OUTPUT=$(./ticket.sh list 2>&1)
    if ! echo "$DEFAULT_OUTPUT" | grep -q "status: done"; then
        pass "Default list excludes done tickets"
    else
        fail "Default list should exclude done tickets"
    fi
    
    # Test 9: Edge Cases
    section "9. Edge Cases"
    
    # No current ticket for close
    rm -f current-ticket.md
    if ! ./ticket.sh close --no-push >/dev/null 2>&1; then
        pass "Cannot close without current ticket"
    else
        fail "Should require current ticket"
    fi
    
    # Test with auto_push disabled
    yaml_update .ticket-config.yml "auto_push" "false"
    ./ticket.sh new no-push-test >/dev/null 2>&1
    git add . && git commit -q -m "Add no-push"
    
    OUTPUT=$(./ticket.sh start no-push-test 2>&1)
    if echo "$OUTPUT" | grep -q "not pushed"; then
        pass "Respects auto_push: false"
    else
        fail "Should show not pushed message"
    fi
}

# Main execution
main() {
    trap cleanup EXIT
    
    setup
    run_tests
    
    section "=== Test Summary ==="
    echo -e "Passed: ${GREEN}$PASSED${NC}"
    echo -e "Failed: ${RED}$FAILED${NC}"
    
    if [[ $FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Source yaml-sh functions if available
if [[ -f "../lib/yaml-sh.sh" ]]; then
    source "../lib/yaml-sh.sh"
elif [[ -f "./lib/yaml-sh.sh" ]]; then
    source "./lib/yaml-sh.sh"
fi

# Run tests
main "$@"