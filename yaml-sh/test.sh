#!/usr/bin/env bash

# yaml-sh test suite
# Tests basic YAML parsing functionality

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
PASSED=0
FAILED=0

# Source yaml-sh
source ./yaml-sh.sh

# Test function
test_case() {
    local name="$1"
    local result="$2"
    local expected="$3"
    
    if [[ "$result" == "$expected" ]]; then
        echo -e "${GREEN}✓${NC} $name"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $name"
        echo "  Expected: '$expected'"
        echo "  Got:      '$result'"
        ((FAILED++))
    fi
}

# Create test YAML file
cat > test_temp.yml << 'EOF'
# Test YAML file
name: yaml-sh
version: 2.0.0
debug: true
empty: ""
number: 42

# List with dashes
tags:
  - parser
  - bash
  - yaml

# Inline list
colors: [red, green, blue]

# Quoted strings
single: 'Single quoted string'
double: "Double quoted string"

# Multiline literal
description: |
  This is a multiline
  description that preserves
  line breaks.

# Multiline folded
summary: >
  This is a folded
  multiline string that
  becomes a single line.

# Multiline with strip
stripped: |-
  No final newline

# Comment test
with_comment: value  # This is a comment
EOF

echo -e "${YELLOW}=== yaml-sh Test Suite ===${NC}"
echo

# Test 1: Parse file
yaml_parse "test_temp.yml"
test_case "Parse YAML file" "$?" "0"

# Test 2: Get simple values
test_case "Get string value" "$(yaml_get 'name')" "yaml-sh"
test_case "Get version" "$(yaml_get 'version')" "2.0.0"
test_case "Get boolean" "$(yaml_get 'debug')" "true"
test_case "Get number" "$(yaml_get 'number')" "42"
test_case "Get empty string" "$(yaml_get 'empty')" ""

# Test 3: Get quoted strings
test_case "Get single quoted" "$(yaml_get 'single')" "Single quoted string"
test_case "Get double quoted" "$(yaml_get 'double')" "Double quoted string"

# Test 4: Check key existence
yaml_has_key "name" && has_name="yes" || has_name="no"
test_case "Check existing key" "$has_name" "yes"

yaml_has_key "nonexistent" && has_none="yes" || has_none="no"
test_case "Check non-existing key" "$has_none" "no"

# Test 5: List handling
test_case "Get list size" "$(yaml_list_size 'tags')" "3"
test_case "Get list item 0" "$(yaml_get 'tags.0')" "parser"
test_case "Get list item 1" "$(yaml_get 'tags.1')" "bash"
test_case "Get list item 2" "$(yaml_get 'tags.2')" "yaml"

# Test 6: Inline list
test_case "Get inline list size" "$(yaml_list_size 'colors')" "3"
test_case "Get inline list item 0" "$(yaml_get 'colors.0')" "red"
test_case "Get inline list item 1" "$(yaml_get 'colors.1')" "green"
test_case "Get inline list item 2" "$(yaml_get 'colors.2')" "blue"

# Test 7: Multiline strings
desc=$(yaml_get 'description')
expected_desc="This is a multiline
description that preserves
line breaks."
test_case "Multiline literal preserves newlines" "$desc" "$expected_desc"

summary=$(yaml_get 'summary')
# Note: Folded strings may have trailing space
if [[ "$summary" == "This is a folded multiline string that becomes a single line." ]] || \
   [[ "$summary" == "This is a folded multiline string that becomes a single line. " ]]; then
    test_case "Multiline folded converts to single line" "pass" "pass"
else
    test_case "Multiline folded converts to single line" "$summary" "This is a folded multiline string that becomes a single line."
fi

stripped=$(yaml_get 'stripped')
test_case "Stripped multiline has no final newline" "$stripped" "No final newline"

# Test 8: Comments preserved in values
test_case "Value with comment" "$(yaml_get 'with_comment')" "value"

# Test 9: List all keys
key_count=$(yaml_keys | wc -l | tr -d ' ')
test_case "Number of keys parsed" "$((key_count >= 15))" "1"

# Test 10: Update function
cp test_temp.yml test_update.yml
yaml_update "test_update.yml" "version" "3.0.0"
yaml_parse "test_update.yml"
test_case "Update simple value" "$(yaml_get 'version')" "3.0.0"

# Test 11: Update preserves comments
yaml_update "test_update.yml" "with_comment" "new_value"
if grep -q "new_value.*# This is a comment" test_update.yml; then
    test_case "Update preserves comments" "pass" "pass"
else
    test_case "Update preserves comments" "fail" "pass"
fi

# Test 12: Load into environment
yaml_load "test_temp.yml" "TEST"
test_case "Load into environment" "$TEST_name" "yaml-sh"
test_case "Load list item" "$TEST_tags_0" "parser"

# Cleanup
rm -f test_temp.yml test_update.yml

# Summary
echo
echo -e "${YELLOW}=== Test Summary ===${NC}"
echo -e "Total tests: $((PASSED + FAILED))"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [[ $FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi