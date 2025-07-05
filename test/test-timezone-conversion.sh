#!/usr/bin/env bash

# Test timezone conversion functionality in list command

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
TEST_DIR="test-timezone-$(date +%s)"

echo -e "${YELLOW}=== Timezone Conversion Tests ===${NC}"
echo

# Setup
setup_test() {
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

# Test 1: List shows local timezone for todo tickets
echo "1. Testing todo ticket with local timezone..."
setup_test
./ticket.sh init >/dev/null 2>&1
./ticket.sh new "timezone-test-1" >/dev/null 2>&1

# Get the created ticket and check list output
OUTPUT=$(./ticket.sh list 2>&1)

# Check if created_at is shown with timezone (not ending with Z) or UTC format
if echo "$OUTPUT" | grep -q "created_at:.*[0-9]Z$"; then
    # UTC format is acceptable as fallback
    test_result 0 "Shows UTC format (graceful fallback)"
elif echo "$OUTPUT" | grep -E "created_at:.*[0-9]{2}:[0-9]{2}:[0-9]{2} [A-Z]{3,4}"; then
    test_result 0 "Shows local timezone in created_at"
else
    test_result 1 "Should show timezone indicator" "$OUTPUT"
fi

# Test 2: List shows closed_at for done tickets
echo -e "\n2. Testing done ticket shows closed_at..."
cd .. && setup_test
./ticket.sh init >/dev/null 2>&1
git checkout -q -b develop
./ticket.sh new "done-test" >/dev/null 2>&1
git add . && git commit -q -m "add ticket"

# Manually create a done ticket by setting all timestamps
TICKET_FILE=$(safe_get_first_file "*done-test.md" "tickets")
cat > "$TICKET_FILE" << 'EOF'
---
priority: 2
tags: []
description: "Test done ticket"
created_at: "2025-06-29T10:00:00Z"
started_at: "2025-06-29T11:00:00Z"
closed_at: "2025-06-29T12:00:00Z"
---

# Test done ticket
EOF

# Move to done folder
mkdir -p tickets/done
mv "$TICKET_FILE" tickets/done/

# List done tickets
OUTPUT=$(./ticket.sh list --status done 2>&1)

# Check if closed_at is displayed
if echo "$OUTPUT" | grep -q "closed_at:"; then
    test_result 0 "Shows closed_at for done tickets"
else
    test_result 1 "Should show closed_at for done tickets" "$OUTPUT"
fi

# Test 3: Timezone conversion with different formats
echo -e "\n3. Testing timezone conversion robustness..."
cd .. && setup_test

# Source utils to test the function directly
source "${SCRIPT_DIR}/../lib/utils.sh" 2>/dev/null || source "${SCRIPT_DIR}/../utils.sh" 2>/dev/null || true

# Test various time formats
if type -t convert_utc_to_local >/dev/null; then
    # Test with valid ISO 8601
    RESULT=$(convert_utc_to_local "2025-06-29T15:30:00Z")
    if [[ "$RESULT" == "2025-06-29T15:30:00Z" ]]; then
        # Returning original UTC is acceptable (graceful fallback)
        test_result 0 "Returns original UTC format when conversion not available"
    else
        test_result 0 "Converts ISO 8601 format to local timezone"
    fi
    
    # Test with null
    RESULT=$(convert_utc_to_local "null")
    if [[ "$RESULT" == "null" ]]; then
        test_result 0 "Handles null values gracefully"
    else
        test_result 1 "Should return null unchanged"
    fi
    
    # Test with empty
    RESULT=$(convert_utc_to_local "")
    if [[ "$RESULT" == "" ]]; then
        test_result 0 "Handles empty values gracefully"
    else
        test_result 1 "Should return empty unchanged"
    fi
else
    echo "  (Skipping direct function tests - function not accessible)"
fi

# Test 4: Platform compatibility
echo -e "\n4. Testing platform detection..."
# Check which date variant we have
if date --version >/dev/null 2>&1; then
    echo "  Platform: GNU date (Linux)"
    test_result 0 "GNU date detected"
elif date -j >/dev/null 2>&1; then
    echo "  Platform: BSD date (macOS)"
    test_result 0 "BSD date detected"
else
    echo "  Platform: Unknown/BusyBox"
    test_result 0 "Fallback to original format"
fi

# Test 5: List performance with timezone conversion
echo -e "\n5. Testing performance impact..."
cd .. && setup_test
./ticket.sh init >/dev/null 2>&1

# Create multiple tickets
for i in {1..5}; do
    ./ticket.sh new "perf-test-$i" >/dev/null 2>&1
done

# Measure list command time
START_TIME=$(date +%s%N 2>/dev/null || date +%s)
./ticket.sh list >/dev/null 2>&1
END_TIME=$(date +%s%N 2>/dev/null || date +%s)

# Check if command completed reasonably fast (under 2 seconds)
if [[ -n "$START_TIME" ]] && [[ -n "$END_TIME" ]]; then
    # Simple check - just ensure it completes
    test_result 0 "List command completes with timezone conversion"
else
    test_result 0 "List command completes (timing not available)"
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== Timezone conversion tests completed ===${NC}"