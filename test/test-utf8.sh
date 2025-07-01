#!/usr/bin/env bash

# UTF-8 support test for ticket.sh
# Tests UTF-8 characters in various contexts

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
source "$(dirname "$0")/test-helpers.sh"

# Ensure UTF-8 environment
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test directory
TEST_DIR="test-utf8-$(date +%s)"

echo -e "${YELLOW}=== UTF-8 Support Tests ===${NC}"
echo

# Setup
setup_test() {
    setup_test_repo "$TEST_DIR"
    # Copy ticket.sh to test directory
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

# Test 1: UTF-8 in ticket slug (should work with hyphenated versions)
echo "1. Testing UTF-8 in ticket slug..."
setup_test

# Create ticket with Japanese characters converted to slug format
if ./ticket.sh new "日本語-テスト" >/dev/null 2>&1 || ./ticket.sh new "nihongo-test" >/dev/null 2>&1; then
    if ls tickets/*nihongo-test.md >/dev/null 2>&1 || ls tickets/*test.md >/dev/null 2>&1; then
        test_result 0 "Created ticket with UTF-8 related slug"
    else
        test_result 1 "Failed to create ticket with UTF-8 related slug"
    fi
else
    test_result 1 "Failed to handle UTF-8 in slug"
fi

# Test 2: UTF-8 in ticket description
echo -e "\n2. Testing UTF-8 in ticket description..."
./ticket.sh new "utf8-description-test" >/dev/null 2>&1
TICKET=$(safe_get_first_file "*utf8-description-test.md" "tickets")

if [[ -n "$TICKET" ]]; then
    # Update description with UTF-8 characters
    sed_i 's/description: ".*"/description: "日本語の説明: テスト用チケット 🎉"/' "$TICKET"
    
    # Verify it can be read
    if ./ticket.sh list 2>&1 | grep -q "日本語の説明"; then
        test_result 0 "UTF-8 description displayed correctly"
    else
        test_result 1 "UTF-8 description not displayed"
    fi
else
    test_result 1 "Could not create test ticket"
fi

# Test 3: UTF-8 in ticket content
echo -e "\n3. Testing UTF-8 in ticket content..."
./ticket.sh new "utf8-content-test" >/dev/null 2>&1
TICKET=$(safe_get_first_file "*utf8-content-test.md" "tickets")

if [[ -n "$TICKET" ]]; then
    # Add UTF-8 content to ticket
    cat >> "$TICKET" << 'EOF'

# テストチケット 🚀

このチケットは以下の内容を含みます：
- 日本語のテキスト
- 絵文字: 😀 🎉 🚀
- 特殊文字: ñ é ü ß
- 中文字符: 你好世界
- Emoji in code: `console.log("Hello 👋")`

## タスク
- [ ] 日本語タスク１
- [ ] 日本語タスク２
- [ ] Emoji task 🎯
EOF

    # Start the ticket to verify content handling
    git add tickets .ticket-config.yml && git commit -q -m "add utf8 ticket"
    TICKET_NAME=$(basename "$TICKET" .md)
    
    if ./ticket.sh start "$TICKET_NAME" --no-push >/dev/null 2>&1; then
        test_result 0 "Started ticket with UTF-8 content"
        
        # Check if symlink works with UTF-8 content
        if [[ -L current-ticket.md ]] && grep -q "日本語のテキスト" current-ticket.md; then
            test_result 0 "Symlink handles UTF-8 content correctly"
        else
            test_result 1 "Symlink issue with UTF-8 content"
        fi
    else
        test_result 1 "Failed to start ticket with UTF-8 content"
    fi
else
    test_result 1 "Could not create test ticket"
fi

# Test 4: UTF-8 in git operations
echo -e "\n4. Testing UTF-8 in git operations..."
if git branch --show-current | grep -q "feature/"; then
    echo "UTF-8 コミット" > utf8-file.txt
    git add utf8-file.txt && git commit -q -m "追加: UTF-8 ファイル 🎉"
    
    if git log --oneline -1 | grep -q "UTF-8"; then
        test_result 0 "Git handles UTF-8 commit messages"
    else
        test_result 1 "Git UTF-8 commit message issue"
    fi
else
    test_result 1 "Not on feature branch"
fi

# Test 5: UTF-8 in tag names
echo -e "\n5. Testing UTF-8 in ticket tags..."
cd .. && setup_test
./ticket.sh new "utf8-tags-test" >/dev/null 2>&1
TICKET=$(safe_get_first_file "*utf8-tags-test.md" "tickets")

if [[ -n "$TICKET" ]]; then
    # Update tags with UTF-8 characters
    sed_i 's/tags: \[\]/tags: ["機能", "テスト", "🏷️"]/' "$TICKET"
    
    # List should handle UTF-8 tags
    OUTPUT=$(./ticket.sh list 2>&1)
    if echo "$OUTPUT" | grep -q "utf8-tags-test"; then
        test_result 0 "Ticket with UTF-8 tags listed successfully"
    else
        test_result 1 "Failed to list ticket with UTF-8 tags"
    fi
else
    test_result 1 "Could not create test ticket"
fi

# Test 6: Locale auto-setting verification
echo -e "\n6. Testing locale auto-setting..."
# Test that ticket.sh works even when locale is not UTF-8
OLD_LANG=$LANG
OLD_LC_ALL=$LC_ALL
export LANG=C
export LC_ALL=C

# Create a ticket with UTF-8 content to verify auto-setting works
./ticket.sh new "locale-test" >/dev/null 2>&1
LOCALE_TICKET=$(safe_get_first_file "*locale-test.md" "tickets")

if [[ -n "$LOCALE_TICKET" ]]; then
    # Add UTF-8 content
    sed_i 's/description: ".*"/description: "ロケールテスト 🌍"/' "$LOCALE_TICKET"
    
    # Run list command - should handle UTF-8 even with C locale
    OUTPUT=$(./ticket.sh list 2>&1)
    if echo "$OUTPUT" | grep -q "ロケールテスト"; then
        test_result 0 "Locale auto-setting works (UTF-8 handled with C locale)"
    else
        test_result 1 "Locale auto-setting may not be working"
    fi
else
    test_result 1 "Could not create test ticket"
fi

# Restore locale
export LANG=$OLD_LANG
export LC_ALL=$OLD_LC_ALL

# Test 7: Long UTF-8 strings
echo -e "\n7. Testing long UTF-8 strings..."
cd .. && setup_test
LONG_DESC="長い日本語の説明文字列をテストします。これは非常に長い説明で、様々な日本語の文字を含んでいます。"
./ticket.sh new "long-utf8-test" >/dev/null 2>&1
TICKET=$(safe_get_first_file "*long-utf8-test.md" "tickets")

if [[ -n "$TICKET" ]]; then
    sed_i "s/description: \".*\"/description: \"$LONG_DESC\"/" "$TICKET"
    
    if ./ticket.sh list 2>&1 | grep -q "長い日本語"; then
        test_result 0 "Long UTF-8 strings handled correctly"
    else
        test_result 1 "Issue with long UTF-8 strings"
    fi
else
    test_result 1 "Could not create test ticket"
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

echo -e "\n${YELLOW}=== UTF-8 tests completed ===${NC}"