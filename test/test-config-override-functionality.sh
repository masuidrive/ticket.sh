#!/usr/bin/env bash

# Functional test to verify override actually works by checking the behavior

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$0")/test-helpers.sh"

echo "=== Functional Config Override Tests ==="

cleanup() {
    cd "$SCRIPT_DIR"
    [[ -d test-override-functional ]] && rm -rf test-override-functional*
}

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

# Test actual override functionality by creating tickets in different directories
test_override_actually_works() {
    echo "1. Testing that override actually changes behavior..."
    
    local test_dir="test-override-functional"
    create_test_repo "$test_dir"
    
    # Create main config with main-tickets directory
    cat > .ticket-config.yaml << 'EOF'
tickets_dir: "main-tickets"
default_branch: "main"
branch_prefix: "main-prefix/"
default_content: |
  # Main Config Content
  This is from main config
EOF
    
    # Create override config with override-tickets directory
    cat > .ticket-config.override.yaml << 'EOF'
tickets_dir: "override-tickets"
branch_prefix: "override-prefix/"
default_content: |
  # Override Config Content
  This is from override config
EOF
    
    # Create both directories
    mkdir -p main-tickets override-tickets
    
    # Initialize the system
    timeout 10 "$SCRIPT_DIR/../ticket.sh" init >/dev/null 2>&1
    
    # Create a ticket - should go to override-tickets directory
    echo "  Creating ticket with: $SCRIPT_DIR/../ticket.sh new test-override"
    if timeout 10 "$SCRIPT_DIR/../ticket.sh" new test-override >/dev/null 2>&1; then
        echo "  Ticket creation command succeeded"
        # Check where the ticket was created
        echo "  Checking override-tickets directory..."
        ls -la override-tickets/ || echo "    No override-tickets directory found"
        echo "  Checking main-tickets directory..."
        ls -la main-tickets/ || echo "    No main-tickets directory found"
        
        if ls override-tickets/*test-override.md >/dev/null 2>&1; then
            echo "  ✓ Ticket created in override directory (override works!)"
            
            # Check if content is from override
            local ticket_file=$(ls override-tickets/*test-override.md)
            if grep -q "Override Config Content" "$ticket_file"; then
                echo "  ✓ Ticket content comes from override config"
            else
                echo "  ✗ Ticket content not from override config"
                return 1
            fi
        elif ls main-tickets/*test-override.md >/dev/null 2>&1; then
            echo "  ✗ Ticket created in main directory (override not working)"
            return 1
        else
            echo "  ✗ Ticket not found in either directory"
            return 1
        fi
    else
        echo "  ✗ Failed to create ticket"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    rm -rf "$test_dir"
}

# Test that missing override file doesn't break anything
test_missing_override_works() {
    echo "2. Testing that missing override file doesn't break functionality..."
    
    local test_dir="test-override-functional-missing"
    create_test_repo "$test_dir"
    
    # Create only main config
    cat > .ticket-config.yaml << 'EOF'
tickets_dir: "main-tickets"
default_branch: "main"
default_content: |
  # Main Only Content
  This is from main config only
EOF
    
    mkdir -p main-tickets
    
    # Initialize and create ticket
    timeout 10 "$SCRIPT_DIR/../ticket.sh" init >/dev/null 2>&1
    
    if timeout 10 "$SCRIPT_DIR/../ticket.sh" new test-main-only >/dev/null 2>&1; then
        if ls main-tickets/*test-main-only.md >/dev/null 2>&1; then
            echo "  ✓ Ticket created in main directory when no override exists"
            
            # Check content
            local ticket_file=$(ls main-tickets/*test-main-only.md)
            if grep -q "Main Only Content" "$ticket_file"; then
                echo "  ✓ Ticket content comes from main config"
            else
                echo "  ✗ Ticket content not as expected"
                return 1
            fi
        else
            echo "  ✗ Ticket not created in main directory"
            return 1
        fi
    else
        echo "  ✗ Failed to create ticket without override"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    rm -rf "$test_dir"
}

# Run tests
main() {
    local failed=0
    
    cleanup
    
    echo "Testing actual override functionality:"
    echo ""
    
    test_override_actually_works || ((failed++))
    test_missing_override_works || ((failed++))
    
    cleanup
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "=== All functional override tests passed! ==="
        return 0
    else
        echo "=== $failed functional override tests failed ==="
        return 1
    fi
}

main "$@"