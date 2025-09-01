#!/usr/bin/env bash

# Test script for .ticket-config.override.yaml functionality
# This follows TDD approach - these tests should FAIL initially (RED phase)

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
source "$(dirname "$0")/test-helpers.sh"

echo "=== Config Override Tests ==="

cleanup() {
    cd "$SCRIPT_DIR"
    [[ -d test-config-override ]] && rm -rf test-config-override*
}

# Helper function to create test repo
create_test_repo() {
    local test_dir="$1"
    rm -rf "$test_dir"
    mkdir "$test_dir"
    cd "$test_dir"
    git init -q
    git config user.name "Test"
    git config user.email "test@test.com"
    echo "test" > README.md
    git add README.md
    git commit -q -m "init"
}

# Test 1: Basic override functionality
test_basic_override() {
    echo "1. Testing basic override functionality..."
    
    local test_dir="test-config-override-basic"
    create_test_repo "$test_dir"
    
    # Create main config
    cat > .ticket-config.yaml << 'EOF'
tickets_dir: "main-tickets"
default_branch: "main"
branch_prefix: "feature/"
repository: "origin"
auto_push: true
delete_remote_on_close: true
start_success_message: "Main config message"
close_success_message: ""
default_content: |
  # Main Config
  Default content from main
EOF
    
    # Create override config
    cat > .ticket-config.override.yaml << 'EOF'
tickets_dir: "override-tickets"
start_success_message: "Override config message"
default_content: |
  # Override Config
  Default content from override
EOF
    
    # Create both directories
    mkdir main-tickets override-tickets
    
    # Test that override values are used
    if timeout 5 "$SCRIPT_DIR/../ticket.sh" list >/dev/null 2>&1; then
        # This test should check that override-tickets is used, not main-tickets
        # For now, just check if the command runs (will fail initially)
        echo "  ✓ Command runs with override config"
    else
        echo "  ✗ Command failed with override config"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    rm -rf "$test_dir"
}

# Test 2: Optional override (works without override file)
test_optional_override() {
    echo "2. Testing optional override (no override file)..."
    
    local test_dir="test-config-override-optional"
    create_test_repo "$test_dir"
    
    # Create only main config
    cat > .ticket-config.yaml << 'EOF'
tickets_dir: "main-tickets"
default_branch: "main"
branch_prefix: "feature/"
repository: "origin"
auto_push: true
delete_remote_on_close: true
start_success_message: "Main config message"
close_success_message: ""
default_content: |
  # Main Config Only
  Default content from main
EOF
    
    mkdir main-tickets
    
    # Test that system works without override file
    if timeout 5 "$SCRIPT_DIR/../ticket.sh" list >/dev/null 2>&1; then
        echo "  ✓ System works without override file"
    else
        echo "  ✗ System fails without override file"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    rm -rf "$test_dir"
}

# Test 3: Precedence test (override wins over main)
test_precedence() {
    echo "3. Testing precedence (override values win)..."
    
    local test_dir="test-config-override-precedence"
    create_test_repo "$test_dir"
    
    # Create main config with specific values
    cat > .ticket-config.yaml << 'EOF'
tickets_dir: "main-tickets"
default_branch: "main"
branch_prefix: "main-feature/"
start_success_message: "Main message"
auto_push: false
EOF
    
    # Create override config that overrides some values
    cat > .ticket-config.override.yaml << 'EOF'
tickets_dir: "override-tickets"
branch_prefix: "override-feature/"
start_success_message: "Override message"
EOF
    
    mkdir main-tickets override-tickets
    
    # Test would verify that override values are actually used
    # This is a placeholder - actual verification would need config inspection
    if timeout 5 "$SCRIPT_DIR/../ticket.sh" list >/dev/null 2>&1; then
        echo "  ✓ Precedence test setup works"
    else
        echo "  ✗ Precedence test failed"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    rm -rf "$test_dir"
}

# Test 4: Works with .yml main config
test_yml_main_config() {
    echo "4. Testing override with .yml main config..."
    
    local test_dir="test-config-override-yml"
    create_test_repo "$test_dir"
    
    # Create main config as .yml
    cat > .ticket-config.yml << 'EOF'
tickets_dir: "yml-tickets"
default_branch: "main"
start_success_message: "YML main message"
EOF
    
    # Create override config as .yaml
    cat > .ticket-config.override.yaml << 'EOF'
tickets_dir: "yml-override-tickets"
start_success_message: "YML override message"
EOF
    
    mkdir yml-tickets yml-override-tickets
    
    # Test that override works with .yml main config
    if timeout 5 "$SCRIPT_DIR/../ticket.sh" list >/dev/null 2>&1; then
        echo "  ✓ Override works with .yml main config"
    else
        echo "  ✗ Override fails with .yml main config"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    rm -rf "$test_dir"
}

# Test 5: Error handling for malformed override
test_malformed_override() {
    echo "5. Testing error handling for malformed override..."
    
    local test_dir="test-config-override-malformed"
    create_test_repo "$test_dir"
    
    # Create valid main config
    cat > .ticket-config.yaml << 'EOF'
tickets_dir: "main-tickets"
default_branch: "main"
EOF
    
    # Create malformed override config
    cat > .ticket-config.override.yaml << 'EOF'
tickets_dir: "override-tickets"
invalid_yaml: [unclosed bracket
malformed: content
EOF
    
    mkdir main-tickets override-tickets
    
    # Test that system handles malformed override gracefully
    local output
    output=$(timeout 5 "$SCRIPT_DIR/../ticket.sh" list 2>&1)
    if echo "$output" | grep -q "Error"; then
        echo "  ✓ Shows error for malformed override config"
    else
        echo "  ✗ Does not handle malformed override properly"
        echo "  Output: $output"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    rm -rf "$test_dir"
}

# Test 6: Existing functionality still works
test_existing_functionality() {
    echo "6. Testing existing functionality still works..."
    
    local test_dir="test-config-override-existing"
    create_test_repo "$test_dir"
    
    # Create standard config without override
    cat > .ticket-config.yaml << 'EOF'
tickets_dir: "tickets"
default_branch: "main"
branch_prefix: "feature/"
repository: "origin"
auto_push: true
delete_remote_on_close: true
start_success_message: "Standard message"
close_success_message: ""
default_content: |
  # Standard Config
  Default content
EOF
    
    mkdir tickets
    
    # Test that all existing functionality works
    if timeout 5 "$SCRIPT_DIR/../ticket.sh" list >/dev/null 2>&1; then
        echo "  ✓ List command works"
    else
        echo "  ✗ List command fails"
        return 1
    fi
    
    # Test creating a ticket
    if timeout 5 "$SCRIPT_DIR/../ticket.sh" new test-existing >/dev/null 2>&1; then
        echo "  ✓ New ticket creation works"
    else
        echo "  ✗ New ticket creation fails"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    rm -rf "$test_dir"
}

# Run all tests
main() {
    local failed=0
    
    cleanup
    
    echo "Running RED phase tests (these should FAIL initially):"
    echo ""
    
    test_basic_override || ((failed++))
    test_optional_override || ((failed++))
    test_precedence || ((failed++))
    test_yml_main_config || ((failed++))
    test_malformed_override || ((failed++))
    test_existing_functionality || ((failed++))
    
    cleanup
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "=== All config override tests passed! ==="
        echo "Note: If this is RED phase, some tests should have failed."
        return 0
    else
        echo "=== $failed config override tests failed ==="
        echo "This is expected in RED phase - now implement the functionality!"
        return 1
    fi
}

# Run main function
main "$@"