#!/usr/bin/env bash

# Utility functions for ticket.sh

# Check if we're in a git repository
check_git_repo() {
    if [[ ! -d .git ]]; then
        cat >&2 << EOF
Error: Not in a git repository
This directory is not a git repository. Please:
1. Navigate to your project root directory, or
2. Initialize a new git repository with 'git init'
EOF
        return 1
    fi
    return 0
}

# Check if config file exists
check_config() {
    CONFIG_FILE=$(get_config_file)
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat >&2 << EOF
Error: Ticket system not initialized
Configuration file not found. Please:
1. Run 'ticket.sh init' to initialize the ticket system, or
2. Navigate to the project root directory where the config exists
3. Expected files: .ticket-config.yaml or .ticket-config.yml
EOF
        return 1
    fi
    return 0
}

# Validate slug format (lowercase, numbers, hyphens only)
validate_slug() {
    local slug="$1"
    
    if [[ ! "$slug" =~ ^[a-z0-9-]+$ ]]; then
        cat >&2 << EOF
Error: Invalid slug format
Slug '$slug' contains invalid characters. Please:
1. Use only lowercase letters (a-z)
2. Use only numbers (0-9)
3. Use only hyphens (-) for separation
Example: 'implement-user-auth' or 'fix-bug-123'
EOF
        return 1
    fi
    return 0
}

# Get current git branch
get_current_branch() {
    # Try to get current branch name
    local branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    
    # If HEAD doesn't exist (no commits yet), try to get default branch
    if [[ -z "$branch_name" ]] || [[ "$branch_name" == "HEAD" ]]; then
        # Try to get the default branch from git config
        branch_name=$(git config --get init.defaultBranch 2>/dev/null)
        
        # If still empty, try to detect from git symbolic-ref
        if [[ -z "$branch_name" ]]; then
            branch_name=$(git symbolic-ref --short HEAD 2>/dev/null)
        fi
        
        # If still empty, default to "main"
        if [[ -z "$branch_name" ]]; then
            branch_name="main"
        fi
    fi
    
    echo "$branch_name"
}

# Check if git working directory is clean
check_clean_working_dir() {
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        cat >&2 << EOF
Error: Uncommitted changes
Working directory has uncommitted changes. Please:
1. Commit your changes: git add . && git commit -m "message"
2. Or stash changes: git stash
3. Then retry the ticket operation

Remember to update current-ticket.md with your progress before committing.

IMPORTANT: Never use 'git restore' or 'rm' to discard file changes without
explicit user permission. User's work must be preserved.
EOF
        return 1
    fi
    return 0
}

# Generate ticket filename from slug
generate_ticket_filename() {
    local slug="$1"
    local timestamp=$(date -u '+%y%m%d-%H%M%S')
    echo "${timestamp}-${slug}"
}

# Extract ticket name from various input formats
extract_ticket_name() {
    local input="$1"
    
    # Remove directory path if present
    local basename="${input##*/}"
    
    # Remove .md extension if present
    basename="${basename%.md}"
    
    echo "$basename"
}

# Get ticket file path from ticket name
get_ticket_file() {
    local ticket_name="$1"
    local tickets_dir="$2"
    
    # Extract just the ticket name
    ticket_name=$(extract_ticket_name "$ticket_name")
    
    echo "${tickets_dir}/${ticket_name}.md"
}

# Run git command and show output
run_git_command() {
    local cmd="$1"
    
    echo "# run command" >&2
    echo "$cmd" >&2
    
    # Execute the command and capture both stdout and stderr
    local output
    output=$(eval "$cmd" 2>&1)
    local exit_code=$?
    
    # Show output if any
    if [[ -n "$output" ]]; then
        echo "$output" >&2
    fi
    
    echo >&2  # Add blank line after command output
    
    return $exit_code
}

# Format ISO 8601 UTC timestamp
get_utc_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# Check if value is null or empty
is_null_or_empty() {
    local value="$1"
    [[ -z "$value" ]] || [[ "$value" == "null" ]]
}

# Parse ticket status from YAML data
get_ticket_status() {
    local started_at="$1"
    local closed_at="$2"
    
    if is_null_or_empty "$closed_at"; then
        if is_null_or_empty "$started_at"; then
            echo "todo"
        else
            echo "doing"
        fi
    else
        echo "done"
    fi
}

# Convert UTC time to local timezone
# Usage: convert_utc_to_local <utc_time>
# Returns the original time on error (graceful degradation)
convert_utc_to_local() {
    local utc_time="$1"
    
    # Return original if empty or null
    if is_null_or_empty "$utc_time"; then
        echo "$utc_time"
        return 0
    fi
    
    # Try GNU date first (Linux)
    if date --version >/dev/null 2>&1; then
        local result=$(date -d "${utc_time}" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi
    
    # Try BSD date (macOS)
    if date -j >/dev/null 2>&1; then
        # Try with ISO 8601 format first
        local result=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${utc_time}" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
        
        # Try without Z suffix
        local time_no_z="${utc_time%Z}"
        result=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${time_no_z}" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi
    
    # Fallback to original
    echo "$utc_time"
}

# Get configuration file path with priority: .yaml > .yml
get_config_file() {
    if [[ -f ".ticket-config.yaml" ]]; then
        echo ".ticket-config.yaml"
    elif [[ -f ".ticket-config.yml" ]]; then
        echo ".ticket-config.yml"
    else
        # Return default for new installations
        echo ".ticket-config.yaml"
    fi
}