#!/usr/bin/env bash

# Helper functions for tests to handle cross-platform issues

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source compatibility layer
source "$(dirname "$0")/test-compat.sh"

# Safe way to get first matching file
safe_get_first_file() {
    local pattern="$1"
    local dir="${2:-.}"
    
    # Try to find files matching the pattern
    for file in $dir/$pattern; do
        if [[ -f "$file" ]]; then
            echo "$file"
            return 0
        fi
    done
    
    # Return empty string on failure
    echo ""
    return 1
}

# Safe way to extract ticket name from pattern
safe_get_ticket_name() {
    local pattern="$1"
    local file
    
    file=$(safe_get_first_file "$pattern" "tickets")
    if [[ -n "$file" ]]; then
        basename "$file" .md
    else
        echo ""
        return 1
    fi
}

# Setup test repository with proper gitignore
setup_test_repo() {
    local test_dir="${1:-test-tmp}"
    
    rm -rf "$test_dir"
    mkdir "$test_dir"
    cd "$test_dir"
    
    # Copy ticket.sh and required libraries
    cp "${SCRIPT_DIR}/../src/ticket.sh" .
    chmod +x ticket.sh
    
    # Create required directory structure for dependencies
    mkdir -p yaml-sh lib
    cp "${SCRIPT_DIR}/../yaml-sh/yaml-sh.sh" yaml-sh/
    cp "${SCRIPT_DIR}/../lib/yaml-frontmatter.sh" lib/
    cp "${SCRIPT_DIR}/../lib/utils.sh" lib/
    
    # Initialize git with proper gitignore
    git init -q
    git config user.name "Test"
    git config user.email "test@test.com"
    
    # Create gitignore to exclude ticket.sh
    echo "ticket.sh" > .gitignore
    echo "test" > README.md
    
    # Only add specific files
    git add .gitignore README.md
    git commit -q -m "init"
    git checkout -q -b develop
    
    # Initialize ticket system
    ./ticket.sh init >/dev/null
    
    # Commit .gitignore changes from init
    if git status --porcelain | grep -q .gitignore; then
        git add .gitignore
        git commit -q -m "Update .gitignore from ticket init"
    fi
}

# Cleanup test repository
cleanup_test_repo() {
    local test_dir="${1:-test-tmp}"
    cd ..
    rm -rf "$test_dir"
}