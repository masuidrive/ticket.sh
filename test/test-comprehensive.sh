#!/usr/bin/env bash

# Fixed comprehensive test suite for ticket.sh
# Removed set -e to prevent early exit on test failures

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
source "$(dirname "$0")/test-helpers.sh"

# Test configuration
TEST_DIR="tmp/test-comprehensive-$(date +%s)"
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
    mkdir -p tmp
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Always rebuild to ensure latest version
    (cd "${SCRIPT_DIR}/.." && bash ./build.sh >/dev/null 2>&1)
    cp "${SCRIPT_DIR}/../ticket.sh" .
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
    if timeout 5 ./ticket.sh init  2>&1 | grep -q "Not in a git repository"; then
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
    git checkout -q -b main
    
    # No config
    if timeout 5 ./ticket.sh list 2>&1 | grep -q "not initialized"; then
        pass "Detects missing config"
    else
        fail "Should detect missing config"
    fi
    
    # Test 2: Initialization
    section "2. Initialization"
    
    timeout 5 ./ticket.sh init  >/dev/null 2>&1
    
    [[ -f .ticket-config.yaml ]] && pass "Creates config file" || fail "Config file not created"
    [[ -d tickets ]] && pass "Creates tickets directory" || fail "Tickets directory not created"
    [[ -f .gitignore ]] && pass "Creates .gitignore" || fail ".gitignore not created"
    
    if grep -q "current-ticket.md" .gitignore; then
        pass "Adds current-ticket.md to .gitignore"
    else
        fail ".gitignore missing current-ticket.md"
    fi
    
    # Test 3: Ticket Creation
    section "3. Ticket Creation"
    
    # Valid slugs
    timeout 5 ./ticket.sh new feature-abc >/dev/null 2>&1
    TICKET1=$(safe_get_first_file "*feature-abc.md" "tickets")
    [[ -n "$TICKET1" ]] && pass "Creates ticket with valid slug" || fail "Failed to create ticket"
    
    # Invalid slugs
    if ! timeout 5 ./ticket.sh new "Feature ABC" >/dev/null 2>&1; then
        pass "Rejects slug with spaces"
    else
        fail "Should reject slug with spaces"
    fi
    
    # Test 4: Listing
    section "4. Ticket Listing"
    
    OUTPUT=$(timeout 5 ./ticket.sh list 2>&1)
    if echo "$OUTPUT" | grep -q "feature-abc"; then
        pass "List shows created tickets"
    else
        fail "List doesn't show tickets"
    fi
    
    # Test 5: Starting Work
    section "5. Starting Work"
    
    # Commit changes first
    git add .
    git commit -q -m "Add tickets"
    
    # Start ticket
    TICKET_NAME=""
    if [[ -n "$TICKET1" ]]; then
        TICKET_NAME=$(basename "$TICKET1" .md)
    fi
    timeout 5 ./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1
    
    # Commit the started_at change
    git add . >/dev/null 2>&1
    git commit -q -m "Update started_at" >/dev/null 2>&1
    
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$BRANCH" == "feature/$TICKET_NAME" ]]; then
        pass "Creates feature branch"
    else
        fail "Wrong branch: $BRANCH"
    fi
    
    # Test 6: Closing
    section "6. Closing Tickets"
    
    # Make some work
    echo "work" > work.txt
    git add work.txt
    git commit -q -m "Do work"
    
    timeout 5 ./ticket.sh close --no-push >/dev/null 2>&1
    
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$BRANCH" == "main" ]]; then
        pass "Returns to main branch"
    else
        fail "Not on main branch: $BRANCH"
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

# Run tests
main "$@"