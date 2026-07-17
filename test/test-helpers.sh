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
source "$SCRIPT_DIR/test-compat.sh"

# Timeout wrapper for better portability
# Track if we've shown the warning
TIMEOUT_WARNING_SHOWN=${TIMEOUT_WARNING_SHOWN:-false}

timeout() {
    local duration="$1"
    shift
    
    # If real timeout exists, use it
    if command -v /usr/bin/timeout >/dev/null 2>&1; then
        /usr/bin/timeout "$duration" "$@"
        return $?
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$duration" "$@"
        return $?
    else
        # Show warning once per test run
        if [[ "$TIMEOUT_WARNING_SHOWN" != "true" ]]; then
            echo "⚠️  WARNING: timeout command not found. Tests may hang if commands enter interactive mode." >&2
            echo "   Consider installing GNU coreutils (e.g., 'brew install coreutils' on macOS)" >&2
            TIMEOUT_WARNING_SHOWN=true
        fi
        
        # Simple fallback - just run the command without timeout
        # This maintains test functionality even without timeout support
        "$@"
        return $?
    fi
}

# Safe way to get first matching file.
# For tickets/ we probe both the legacy flat layout (tickets/<name>.md) and
# the new per-ticket-directory layout (tickets/<name>/ticket.md), and skip
# the tickets/README.md file that `ticket.sh init` creates.
safe_get_first_file() {
    local pattern="$1"
    local dir="${2:-.}"

    # Try to find files matching the pattern (legacy flat layout).
    for file in $dir/$pattern; do
        if [[ -f "$file" ]]; then
            # Skip the README.md created by init.
            if [[ "$(basename "$file")" == "README.md" ]]; then
                continue
            fi
            echo "$file"
            return 0
        fi
    done

    # Fallback: new per-ticket-directory layout — strip trailing .md from
    # the pattern and probe as a directory containing ticket.md.
    local dir_pattern="${pattern%.md}"
    local d
    for d in $dir/$dir_pattern; do
        if [[ -d "$d" ]] && [[ -f "$d/ticket.md" ]]; then
            echo "$d/ticket.md"
            return 0
        fi
    done

    # Return empty string on failure
    echo ""
    return 1
}

# Safe way to extract ticket name from pattern.
# Supports both layouts:
#   legacy flat:  tickets/<name>.md              → returns <name>
#   new per-dir:  tickets/<name>/ticket.md       → returns <name>
# The pattern is matched loosely: if the pattern is like "*slug.md" it will
# also try "*slug" (directory) so callers don't need to know which layout was
# produced.
safe_get_ticket_name() {
    local pattern="$1"
    local file dir

    # New-format first: strip trailing .md from the pattern and probe as a
    # directory containing ticket.md.
    local dir_pattern="${pattern%.md}"
    for dir in tickets/$dir_pattern; do
        if [[ -d "$dir" ]] && [[ -f "$dir/ticket.md" ]]; then
            basename "$dir"
            return 0
        fi
    done

    # Legacy flat layout: match tickets/<pattern> as a file, skipping README.md
    for file in tickets/$pattern; do
        if [[ -f "$file" ]]; then
            [[ "$(basename "$file")" == "README.md" ]] && continue
            local base=$(basename "$file" .md)
            echo "$base"
            return 0
        fi
    done

    echo ""
    return 1
}

# Resolve the current on-disk path of a ticket's body file, checking both
# layouts. Usage: ticket_body_path <name> [--done]
#   default: prefers tickets/<name>/ticket.md (new), else tickets/<name>.md (legacy)
#   --done : prefers tickets/done/<name>/ticket.md, else tickets/done/<name>.md
# Prints the path, or empty string if none found.
ticket_body_path() {
    local name="$1"
    local mode="${2:-}"
    local base="tickets"
    if [[ "$mode" == "--done" ]]; then
        base="tickets/done"
    fi
    if [[ -f "${base}/${name}/ticket.md" ]]; then
        echo "${base}/${name}/ticket.md"
    elif [[ -f "${base}/${name}.md" ]]; then
        echo "${base}/${name}.md"
    else
        echo ""
    fi
}

# Resolve the current on-disk path of a ticket's note file. Same signature as
# ticket_body_path.
ticket_note_path() {
    local name="$1"
    local mode="${2:-}"
    local base="tickets"
    if [[ "$mode" == "--done" ]]; then
        base="tickets/done"
    fi
    if [[ -f "${base}/${name}/note.md" ]]; then
        echo "${base}/${name}/note.md"
    elif [[ -f "${base}/${name}-note.md" ]]; then
        echo "${base}/${name}-note.md"
    else
        echo ""
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
    # Initialize ticket system with timeout protection
    timeout 5 ./ticket.sh init
    
    echo "      Finalizing setup..."
    # Commit .gitignore changes from init
    if git status --porcelain | grep -q .gitignore; then
        git add .gitignore
        git commit -q -m "Update .gitignore from ticket init"
    fi
    
    # Remove any existing current-ticket.md to ensure clean test environment
    if [[ -L "current-ticket.md" ]]; then
        rm current-ticket.md
        echo "      Removed existing current-ticket.md symlink"
    fi
    
    echo "      Repository setup complete."
}


# Cleanup test repository
cleanup_test_repo() {
    local test_dir="${1:-test-tmp}"
    cd ..
    rm -rf "$test_dir"
}