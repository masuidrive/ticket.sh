#!/usr/bin/env bash

# Check if running with bash (POSIX compatible check)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This test helper requires bash. Please run tests with 'bash test/test-*.sh'"
    echo "Current shell: $0"
    exit 1
fi

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
    
    echo "      Cleaning up old test directory..."
    rm -rf "$test_dir"
    mkdir "$test_dir"
    cd "$test_dir"
    
    echo "      Copying ticket.sh..."
    # Use existing ticket.sh without rebuild for performance
    if [[ -f "${SCRIPT_DIR}/../ticket.sh" ]]; then
        cp "${SCRIPT_DIR}/../ticket.sh" .
    else
        echo "      ERROR: ticket.sh not found. Please run 'bash build.sh' first."
        return 1
    fi
    chmod +x ticket.sh
    
    echo "      Initializing git repository..."
    # Initialize git with proper gitignore
    git init -q
    git config user.name "Test"
    git config user.email "test@test.com"
    
    # Create gitignore to exclude ticket.sh and dependencies
    cat > .gitignore << 'EOF'
ticket.sh
yaml-sh/
lib/
EOF
    echo "test" > README.md
    
    echo "      Making initial commit..."
    # Only add specific files
    git add .gitignore README.md
    git commit -q -m "init"
    
    # Ensure we're on main branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch" != "main" ]]; then
        if git show-ref --verify --quiet refs/heads/main; then
            git checkout -q main
        else
            git checkout -q -b main
        fi
    fi
    
    echo "      Initializing ticket system..."
    # Initialize ticket system
    ./ticket.sh init >/dev/null
    
    echo "      Finalizing setup..."
    # Commit .gitignore changes from init
    if git status --porcelain | grep -q .gitignore; then
        git add .gitignore
        git commit -q -m "Update .gitignore from ticket init"
    fi
    echo "      Repository setup complete."
}

# Cleanup test repository
cleanup_test_repo() {
    local test_dir="${1:-test-tmp}"
    cd ..
    rm -rf "$test_dir"
}