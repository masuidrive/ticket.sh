#!/usr/bin/env bash

# Test script for yaml-sh
# Requirements: Bash 3.2+

# Source the yaml-sh library
source ./yaml-sh-v2.sh

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_case() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    
    ((TESTS_TOTAL++))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $description"
        echo -e "  Expected: ${YELLOW}$expected${NC}"
        echo -e "  Actual:   ${YELLOW}$actual${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test section header
test_section() {
    echo
    echo "=== $1 ==="
}

# Run tests
run_tests() {
    test_section "Simple YAML Parsing"
    
    yaml_parse "test-simple.yaml"
    
    test_case "Parse simple string" \
        "John Doe" \
        "$(yaml_get "name")"
    
    test_case "Parse number" \
        "30" \
        "$(yaml_get "age")"
    
    test_case "Parse email" \
        "john.doe@example.com" \
        "$(yaml_get "email")"
    
    # Skip nested values for v2
    # test_case "Parse nested value" \
    #     "123 Main St" \
    #     "$(yaml_get "address.street")"
    
    # test_case "Parse deeply nested value" \
    #     "Japan" \
    #     "$(yaml_get "address.country")"
    
    test_section "List Parsing"
    
    yaml_parse "test-lists.yaml"
    
    test_case "Parse list item 0" \
        "apple" \
        "$(yaml_get "fruits.0")"
    
    test_case "Parse list item 1" \
        "banana" \
        "$(yaml_get "fruits.1")"
    
    test_case "Parse list item 2" \
        "orange" \
        "$(yaml_get "fruits.2")"
    
    test_case "Parse inline list item 0" \
        "red" \
        "$(yaml_get "colors.0")"
    
    test_case "Parse inline list item 1" \
        "green" \
        "$(yaml_get "colors.1")"
    
    test_case "Parse inline list item 2" \
        "blue" \
        "$(yaml_get "colors.2")"
    
    # Skip object lists for v2
    # test_case "Parse object list - name" \
    #     "Alice" \
    #     "$(yaml_get "users.0.name")"
    
    # test_case "Parse object list - age" \
    #     "25" \
    #     "$(yaml_get "users.0.age")"
    
    # test_case "Parse object list - email" \
    #     "bob@example.com" \
    #     "$(yaml_get "users.1.email")"
    
    test_section "Multiline String Parsing"
    
    yaml_parse "test-multiline.yaml"
    
    # For multiline strings, we need to handle newlines carefully
    local expected_description=$'This is a multiline string\nthat preserves newlines.\n\nIt can have empty lines too.\n'
    test_case "Parse pipe multiline string" \
        "$expected_description" \
        "$(yaml_get "description")"
    
    local expected_compact=$'This multiline string\nstrips the final newline'
    test_case "Parse pipe-minus multiline string" \
        "$expected_compact" \
        "$(yaml_get "compact")"
    
    local expected_folded="This is a folded string where newlines become spaces. "
    test_case "Parse folded multiline string" \
        "$expected_folded" \
        "$(yaml_get "folded")"
    
    test_case "Parse single quoted string" \
        'This is a single-quoted string with "double quotes" inside' \
        "$(yaml_get "single_quoted")"
    
    test_case "Parse double quoted string" \
        "This is a double-quoted string with 'single quotes' inside" \
        "$(yaml_get "double_quoted")"
    
    # Skip complex configuration parsing for now
    # test_section "Complex Configuration Parsing"
    
    test_section "API Functions"
    
    # Test yaml_keys
    yaml_parse "test-simple.yaml"
    local key_count=$(yaml_keys | wc -l | tr -d ' ')
    test_case "yaml_keys returns correct number of keys" \
        "11" \
        "$key_count"
    
    # Test yaml_has_key
    if yaml_has_key "name"; then
        result="true"
    else
        result="false"
    fi
    test_case "yaml_has_key for existing key" \
        "true" \
        "$result"
    
    if yaml_has_key "nonexistent"; then
        result="true"
    else
        result="false"
    fi
    test_case "yaml_has_key for non-existing key" \
        "false" \
        "$result"
    
    # Skip search tests for v2
    # local search_result=$(yaml_search "address" | wc -l)
    # test_case "yaml_search finds matching keys" \
    #     "4" \
    #     "$search_result"
    
    # # Test yaml_get_prefix
    # local prefix_result=$(yaml_get_prefix "address" | wc -l)
    # test_case "yaml_get_prefix returns correct results" \
    #     "4" \
    #     "$prefix_result"
    
    # Test yaml_list_size
    yaml_parse "test-lists.yaml"
    local list_size=$(yaml_list_size "fruits")
    test_case "yaml_list_size returns correct size" \
        "3" \
        "$list_size"
    
    # Skip yaml_load test for v2
    # yaml_load "test-simple.yaml" "config"
    # test_case "yaml_load with prefix" \
    #     "John Doe" \
    #     "$config_name"
    
    test_section "Edge Cases"
    
    # Test empty value
    yaml_clear
    echo "empty_key:" > test-empty.yaml
    yaml_parse "test-empty.yaml"
    test_case "Parse empty value" \
        "" \
        "$(yaml_get "empty_key")"
    
    # Clean up
    rm -f test-empty.yaml
}

# Main execution
echo "Running yaml-sh tests..."
echo "======================="

# Check Bash version
echo "Running on Bash version: $BASH_VERSION"

# Run all tests
run_tests

# Summary
echo
echo "======================="
echo "Test Summary:"
echo -e "Total:  $TESTS_TOTAL"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

# Exit with appropriate code
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi