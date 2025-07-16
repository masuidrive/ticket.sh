#!/usr/bin/env bash

# Check if running with bash (POSIX compatible check)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script requires bash. Please run with 'bash ticket.sh' or make sure bash is your default shell."
    echo "Current shell: $0"
    exit 1
fi

# ticket.sh - Git-based Ticket Management System for Development
# Version: 1.0.0
#
# A lightweight ticket management system that uses Git branches and Markdown files.
# Perfect for small teams, solo developers, and AI coding assistants.
#
# Features:
#   - Each ticket is a Markdown file with YAML frontmatter
#   - Automatic Git branch creation/management per ticket
#   - Simple CLI interface for common workflows
#   - No external dependencies (pure Bash + Git)
#
# For detailed documentation, installation instructions, and examples:
# https://github.com/masuidrive/ticket.sh
#
# Quick Start:
#   $SCRIPT_COMMAND init          # Initialize in your project
#   $SCRIPT_COMMAND new my-task   # Create a new ticket
#   $SCRIPT_COMMAND start <name>  # Start working on a ticket
#   $SCRIPT_COMMAND close         # Complete and merge ticket

set -euo pipefail

# Ensure UTF-8 support and locale-independent behavior
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# Unset environment variables that could affect behavior
unset GREP_OPTIONS  # Prevent user's grep options from affecting behavior
unset CDPATH       # Prevent unexpected directory changes
unset IFS          # Reset Internal Field Separator to default

# Git-related - ensure we use the current directory's git repo
unset GIT_DIR
unset GIT_WORK_TREE

# Shell behavior - prevent unexpected script execution
unset BASH_ENV
unset ENV

# Ensure consistent behavior
unset POSIXLY_CORRECT  # We rely on bash-specific features

# Set secure defaults
# Note: noclobber is disabled because it causes issues with mktemp in some environments
# set -o noclobber   # Prevent accidental file overwrites with >
umask 0022         # Ensure created files have proper permissions

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to detect how the script was invoked
get_script_command() {
    local script_path="$0"
    
    # Get current process command line
    local current_args=""
    if [[ -r /proc/self/cmdline ]]; then
        # Linux: use /proc/self/cmdline
        current_args=$(tr '\0' ' ' < /proc/self/cmdline 2>/dev/null || echo "")
    elif command -v ps >/dev/null 2>&1; then
        # macOS/BSD: use ps command
        current_args=$(ps -p $$ -o args= 2>/dev/null || echo "")
    fi
    
    # Check if invoked via shell (bash, sh, zsh, etc.)
    local shell_pattern='^(bash|sh|dash|zsh|fish|ksh|/.*/(bash|sh|dash|zsh|fish|ksh))[[:space:]]+'
    
    if [[ "$current_args" =~ $shell_pattern ]]; then
        # Extract shell command
        local shell_cmd=$(echo "$current_args" | sed -E 's/^([^[:space:]]+).*/\1/')
        
        # Check if script path is in the command line
        local script_basename=$(basename "$script_path")
        if [[ "$current_args" == *"$script_path"* ]] || [[ "$current_args" == *"$script_basename"* ]]; then
            echo "$shell_cmd $script_path"
        else
            echo "bash $script_path"
        fi
    else
        # Direct execution: check if script is executable and use as-is
        if [[ -x "$script_path" ]]; then
            echo "$script_path"
        else
            echo "bash $script_path"
        fi
    fi
}

# Detect and store the command used to invoke this script
SCRIPT_COMMAND=$(get_script_command)

# Source required libraries
# First try local paths (for testing), then production paths
if [[ -f "${SCRIPT_DIR}/yaml-sh/yaml-sh.sh" ]]; then
    source "${SCRIPT_DIR}/yaml-sh/yaml-sh.sh"
    source "${SCRIPT_DIR}/lib/yaml-frontmatter.sh"
    source "${SCRIPT_DIR}/lib/utils.sh"
elif [[ -f "${SCRIPT_DIR}/../yaml-sh/yaml-sh.sh" ]]; then
    source "${SCRIPT_DIR}/../yaml-sh/yaml-sh.sh"
    source "${SCRIPT_DIR}/../lib/yaml-frontmatter.sh"
    source "${SCRIPT_DIR}/../lib/utils.sh"
else
    echo "Error: Cannot find required yaml-sh.sh library" >&2
    echo "Make sure yaml-sh and lib directories are in the correct location" >&2
    exit 1
fi

# Global variables
VERSION="1.0.0"  # This will be replaced during build
CONFIG_FILE=""  # Will be set dynamically by get_config_file()
CURRENT_TICKET_LINK="current-ticket.md"

# Default configuration values
DEFAULT_TICKETS_DIR="tickets"
DEFAULT_BRANCH="main"
DEFAULT_BRANCH_PREFIX="feature/"
DEFAULT_REPOSITORY="origin"
DEFAULT_AUTO_PUSH="true"
DEFAULT_DELETE_REMOTE_ON_CLOSE="true"
DEFAULT_NEW_SUCCESS_MESSAGE=""
DEFAULT_START_SUCCESS_MESSAGE=""
DEFAULT_RESTORE_SUCCESS_MESSAGE=""
DEFAULT_CLOSE_SUCCESS_MESSAGE=""
DEFAULT_CONTENT='# Ticket Overview

Write the overview and tasks for this ticket here.


## Tasks

- [ ] Task 1
- [ ] Task 2
...
- [ ] Get developer approval before closing


## Notes

Additional notes or requirements.'

# Get dynamic script command name based on how script was invoked
get_script_command() {
    local script_path="$0"
    local current_args=""
    
    # Try to get command line from /proc (Linux) or ps (macOS/other)
    if [[ -r /proc/self/cmdline ]]; then
        current_args=$(tr '\0' ' ' < /proc/self/cmdline 2>/dev/null || echo "")
    elif command -v ps >/dev/null 2>&1; then
        current_args=$(ps -p $$ -o args= 2>/dev/null || echo "")
    fi
    
    # Extract actual invocation method from command line
    if [[ "$current_args" =~ bash[[:space:]]+([^[:space:]]+) ]]; then
        echo "bash ${BASH_REMATCH[1]}"
    elif [[ "$current_args" =~ sh[[:space:]]+([^[:space:]]+) ]]; then
        echo "sh ${BASH_REMATCH[1]}"
    else
        echo "$script_path"
    fi
}

# Set dynamic script command at startup
SCRIPT_COMMAND=$(get_script_command)

# Show usage information
show_usage() {
    echo "# Ticket Management System for Coding Agents"
    echo "Version: $VERSION"
    echo "https://github.com/masuidrive/ticket.sh"
    echo ""
    cat << EOF
## Overview

This is a self-contained ticket management system using shell script + files + Git.
Each ticket is a single Markdown file with YAML frontmatter metadata.

## Usage

- \`$SCRIPT_COMMAND init\` - Initialize system (create config, directories, .gitignore)
- \`$SCRIPT_COMMAND new <slug>\` - Create new ticket file (slug: lowercase, numbers, hyphens only)
- \`$SCRIPT_COMMAND list [--status STATUS] [--count N]\` - List tickets (default: todo + doing, count: 20)
- \`$SCRIPT_COMMAND start <ticket-name>\` - Start working on ticket (creates or switches to feature branch)
- \`$SCRIPT_COMMAND restore\` - Restore current-ticket.md symlink from branch name
- \`$SCRIPT_COMMAND check\` - Check current directory and ticket/branch synchronization status
- \`$SCRIPT_COMMAND close [--no-push] [--force|-f] [--no-delete-remote]\` - Complete current ticket (squash merge to default branch)
- \`$SCRIPT_COMMAND selfupdate\` - Update ticket.sh to the latest version from GitHub
- \`$SCRIPT_COMMAND version\` - Display version information
- \`$SCRIPT_COMMAND prompt\` - Display prompt instructions for AI coding assistants

## Ticket Naming

- Format: \`YYMMDD-hhmmss-<slug>\`
- Example: \`241225-143502-implement-user-auth\`
- Generated automatically when creating tickets

## Ticket Status

- \`todo\`: not started (started_at: null)
- \`doing\`: in progress (started_at set, closed_at: null)
- \`done\`: completed (closed_at set)

## Configuration

- Config file: \`.ticket-config.yaml\` or \`.ticket-config.yml\` (in project root)
- Initialize with: \`$SCRIPT_COMMAND init\`
- Edit to customize directories, branches, templates, and success messages

### Success Messages

- \`new_success_message\`: Displayed after creating a new ticket
- \`start_success_message\`: Displayed after starting work on a ticket
- \`restore_success_message\`: Displayed after restoring current ticket link
- \`close_success_message\`: Displayed after closing a ticket
- All messages default to empty (disabled) and support multiline YAML format

## Push Control

- Set \`auto_push: false\` in config to disable automatic pushing for close command
- Use \`--no-push\` flag with close command to skip pushing
- Feature branches are always created locally (no auto-push on start)
- Git commands and outputs are displayed for transparency

## Workflow

### Create New Ticket

1. Create ticket: \`$SCRIPT_COMMAND new feature-name\`
2. Edit ticket content and description in the generated file

### Start Work

1. Check available tickets: \`$SCRIPT_COMMAND list\` or browse tickets directory
2. Start work: \`$SCRIPT_COMMAND start 241225-143502-feature-name\`
3. Develop on feature branch (\`current-ticket.md\` shows active ticket)

### Closing

1. Before closing:
   - Review ticket content and description
   - Check all tasks in checklist are completed (mark with \`[x]\`)
   - Get user approve before proceeding
2. Complete: \`$SCRIPT_COMMAND close\`

**Note**: If specific workflow instructions are provided elsewhere (e.g., in project documentation or CLAUDE.md), those take precedence over this general workflow.

## Troubleshooting

- Run from project root (where \`.git\` and config file exist)
- Use \`restore\` if \`current-ticket.md\` is missing after clone/pull
- Check \`list\` to see available tickets and their status
- Ensure Git working directory is clean before start/close

**Note**: \`current-ticket.md\` is git-ignored and needs \`restore\` after clone/pull.
EOF
}

# Initialize ticket system
cmd_init() {
    # Check git repository
    check_git_repo || return 1
    
    # Get current branch for default_branch setting
    local current_branch=$(get_current_branch)
    local default_branch_value="$DEFAULT_BRANCH"
    if [[ "$current_branch" =~ ^(main|master|develop)$ ]]; then
        default_branch_value="$current_branch"
    fi
    
    # Determine config file (prefer .yaml for new installations)
    CONFIG_FILE=$(get_config_file)
    
    # Check if critical components are missing to determine if this is a new initialization
    local is_new_init=false
    [[ ! -f "$CONFIG_FILE" ]] && is_new_init=true
    [[ ! -d "${DEFAULT_TICKETS_DIR}" ]] && is_new_init=true
    
    if [[ "$is_new_init" == "false" ]]; then
        echo "Ticket system is already initialized. Checking for missing components..."
    else
        echo "Initializing ticket system..."
    fi
    
    # Create config file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
# Ticket system configuration
# https://github.com/masuidrive/ticket.sh

# Directory settings
tickets_dir: "$DEFAULT_TICKETS_DIR"

# Git settings
default_branch: "$default_branch_value"
branch_prefix: "$DEFAULT_BRANCH_PREFIX"
repository: "$DEFAULT_REPOSITORY"

# Automatically push changes to remote repository during close command
# Set to false if you want to manually control when to push
auto_push: $DEFAULT_AUTO_PUSH

# Automatically delete remote feature branch after closing ticket
# Set to false if you want to keep remote branches for history
delete_remote_on_close: $DEFAULT_DELETE_REMOTE_ON_CLOSE

# Success messages (leave empty to disable)
# Message displayed after creating a new ticket
new_success_message: |
  
# Message displayed after starting work on a ticket
start_success_message: |
  
# Message displayed after restoring current ticket link
restore_success_message: |
  
# Message displayed after closing a ticket
close_success_message: |
  

# Ticket template
default_content: |
  # Ticket Overview
  
  {{Write the overview and tasks for this ticket here.}}
  
  
  ## Tasks
  
  - [ ] {{Task 1}}
  - [ ] {{Task 2}}
  ...
  - [ ] Run tests before closing and pass all tests (No exceptions)
  - [ ] Get developer approval before closing
  
  
  ## Notes
  
  {{Additional notes or requirements.}}
EOF
        echo "Created configuration file: $CONFIG_FILE"
    else
        echo "Configuration file already exists: $CONFIG_FILE"
    fi
    
    # Parse config to get tickets_dir
    if ! yaml_parse "$CONFIG_FILE"; then
        echo "Warning: Could not parse config file, using defaults" >&2
        local tickets_dir="$DEFAULT_TICKETS_DIR"
    else
        local tickets_dir
        tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    fi
    
    # Create tickets directory
    if [[ ! -d "$tickets_dir" ]]; then
        if ! mkdir -p "$tickets_dir"; then
            cat >&2 << EOF
Error: Permission denied
Cannot create directory '$tickets_dir'. Please:
1. Check file permissions in current directory, or
2. Run with appropriate permissions (sudo if needed), or
3. Choose a different location for tickets_dir in config
EOF
            return 1
        fi
        echo "Created tickets directory: $tickets_dir/"
    else
        echo "Tickets directory already exists: $tickets_dir/"
    fi
    
    # Create tickets/README.md file
    local readme_file="${tickets_dir}/README.md"
    if [[ ! -f "$readme_file" ]]; then
        cat > "$readme_file" << EOF
# Tickets Directory

This directory contains all the ticket files for the project.

## Important Guidelines

**⚠️ Always use ticket.sh commands to manage tickets:**

- **Create new tickets:** \`$SCRIPT_COMMAND new <slug>\`
- **Start working on a ticket:** \`$SCRIPT_COMMAND start <ticket-name>\`
- **Complete a ticket:** \`$SCRIPT_COMMAND close\`

**❌ DO NOT manually merge feature branches to the default branch!**
The \`$SCRIPT_COMMAND close\` command handles merging and cleanup automatically.

## Directory Structure

- Active tickets: \`*.md\` files in this directory
- Completed tickets: \`done/\` subdirectory (created automatically)

## Getting Help

For detailed usage instructions, run:
```bash
$SCRIPT_COMMAND help
```

For a list of all available commands:
```bash
$SCRIPT_COMMAND --help
```
EOF
        echo "Created README file: $readme_file"
    else
        echo "README file already exists: $readme_file"
    fi
    
    # Update .gitignore
    if [[ ! -f .gitignore ]]; then
        echo "$CURRENT_TICKET_LINK" > .gitignore
        echo "Created .gitignore with: $CURRENT_TICKET_LINK"
    else
        if ! grep -q "^${CURRENT_TICKET_LINK}$" .gitignore; then
            echo "$CURRENT_TICKET_LINK" >> .gitignore
            echo "Added to .gitignore: $CURRENT_TICKET_LINK"
        else
            echo ".gitignore already contains: $CURRENT_TICKET_LINK"
        fi
    fi
    
    echo ""
    if [[ "$is_new_init" == "true" ]]; then
        echo "Ticket system initialized successfully!"
        echo ""
        echo "The setup is not yet complete. Please ensure that you and your users follow the steps below. It is your mission."
        echo ""
        echo "## Next Steps:"
    else
        echo "Component check completed!"
        echo ""
        echo "For help and usage information, run:"
        echo "  $SCRIPT_COMMAND help"
        echo ""
        echo "Quick reference:"
        echo "  - Create a ticket: '$SCRIPT_COMMAND new <slug>'"
        echo "  - List tickets: '$SCRIPT_COMMAND list'"
        echo "  - Start work: '$SCRIPT_COMMAND start <ticket-name>'"
        echo "  - Complete: '$SCRIPT_COMMAND close'"
        return 0
    fi
    
    echo "1. **Configure your ticket system** (optional):"
    echo "   Edit your config file to customize:"
    echo "   - tickets_dir: Where tickets are stored (default: \"tickets\")"
    echo "   - default_branch: Main development branch (default: \"develop\")"
    echo "   - branch_prefix: Feature branch naming (default: \"feature/\")"
    echo "   - auto_push: Push on close (default: true)"
    echo "   - default_content: Template for new tickets"
    echo ""
    echo "2. **Get AI assistant instructions for your coding agent:**"
    echo ""
    echo "   Run the following command to get instructions for your AI coding assistant:"
    echo "   \`$SCRIPT_COMMAND prompt\`"
    echo ""
    echo "   To save to CLAUDE.md (or your custom prompt file):"
    echo "   \`$SCRIPT_COMMAND prompt >> CLAUDE.md\`"
    echo ""
    echo "Use \`$SCRIPT_COMMAND\` for ticket management."
    echo ""
    echo "## Working with current-ticket.md"
    echo ""
    echo "### If current-ticket.md exists in project root"
    echo "- This file is your work instruction - follow its contents"
    echo "- When receiving additional instructions from users, document them in this file before proceeding"
    echo "- Continue working on the active ticket"
    echo ""
    echo "### If current-ticket.md does not exist in project root"
    echo "- When receiving user requests, first ask whether to create a new ticket"
    echo "- Do not start work without confirming ticket creation"
    echo "- Even small requests should be tracked through the ticket system"
    echo ""
    echo "## Create New Ticket"
    echo ""
    echo "1. Create ticket: \`$SCRIPT_COMMAND new feature-name\`"
    echo "2. Edit ticket content and description in the generated file"
    echo ""
    echo "## Start Working on Ticket"
    echo ""
    echo "1. Check available tickets: \`$SCRIPT_COMMAND list\` or browse tickets directory"
    echo "2. Start work: \`$SCRIPT_COMMAND start 241225-143502-feature-name\`"
    echo "3. Develop on feature branch (\`current-ticket.md\` shows active ticket)"
    echo ""
    echo "## Closing Tickets"
    echo ""
    echo "1. Before closing:"
    echo "   - Review \`current-ticket.md\` content and description"
    echo "   - Check all tasks in checklist are completed (mark with \`[x]\`)"
    echo "   - Get user approval before proceeding"
    echo "2. Complete: \`$SCRIPT_COMMAND close\`"
    echo "\`\`\`"
    echo ""
    echo "   **Note**: These instructions are critical for proper ticket workflow!"
    echo ""
    echo "3. **Quick start**:"
    echo "   - Create a ticket: \`$SCRIPT_COMMAND new <slug>\`"
    echo "   - List tickets: \`$SCRIPT_COMMAND list\`"
    echo "   - Start work: \`$SCRIPT_COMMAND start <ticket-name>\`"
    echo "   - Complete: \`$SCRIPT_COMMAND close\`"
    echo ""
    echo "For detailed help: \`$SCRIPT_COMMAND help\`"
}

# Create new ticket
cmd_new() {
    local slug="$1"
    
    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1
    
    # Validate slug
    validate_slug "$slug" || return 1
    
    # Load configuration
    yaml_parse "$CONFIG_FILE"
    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    local default_content=$(yaml_get "default_content" || echo "$DEFAULT_CONTENT")
    local new_success_message=$(yaml_get "new_success_message" || echo "$DEFAULT_NEW_SUCCESS_MESSAGE")
    
    # Generate filename
    local ticket_name=$(generate_ticket_filename "$slug")
    local ticket_file="${tickets_dir}/${ticket_name}.md"
    
    # Check if file already exists
    if [[ -f "$ticket_file" ]]; then
        cat >&2 << EOF
Error: Ticket already exists
File '$ticket_file' already exists. Please:
1. Use a different slug name, or
2. Edit the existing ticket, or
3. Remove the existing file if it's no longer needed
EOF
        return 1
    fi
    
    # Create ticket file
    local timestamp=$(get_utc_timestamp)
    if ! cat > "$ticket_file" << EOF
---
priority: 2
tags: []
description: ""
created_at: "$timestamp"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

$default_content
EOF
    then
        cat >&2 << EOF
Error: Permission denied
Cannot create file '$ticket_file'. Please:
1. Check write permissions in tickets directory, or
2. Run with appropriate permissions, or
3. Verify tickets directory exists and is writable
EOF
        return 1
    fi
    
    echo "Created ticket file: $ticket_file"
    echo "Please edit the file to add title, description and details."
    echo "To start working on this ticket, you **must** run: $SCRIPT_COMMAND start $ticket_name"
    
    # Display success message if configured
    if [[ -n "$new_success_message" ]]; then
        echo ""
        echo "$new_success_message"
    fi
}

# List tickets
cmd_list() {
    local filter_status=""
    local count=20
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --status)
                shift
                filter_status="$1"
                if [[ ! "$filter_status" =~ ^(todo|doing|done)$ ]]; then
                    cat >&2 << EOF
Error: Invalid status
Status '$filter_status' is not valid. Please use one of:
- todo (for unstarted tickets)
- doing (for in-progress tickets)
- done (for completed tickets)
EOF
                    return 1
                fi
                shift
                ;;
            --count)
                shift
                count="$1"
                if ! [[ "$count" =~ ^[0-9]+$ ]] || [[ "$count" -eq 0 ]]; then
                    cat >&2 << EOF
Error: Invalid count value
Count '$count' is not a valid number. Please:
1. Use a positive integer (e.g., --count 10)
2. Or omit --count to use default (20)
EOF
                    return 1
                fi
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1
    
    # Load configuration
    yaml_parse "$CONFIG_FILE"
    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    
    # Check if tickets directory exists
    if [[ ! -d "$tickets_dir" ]]; then
        cat >&2 << EOF
Error: Tickets directory not found
Directory '$tickets_dir' does not exist. Please:
1. Run '$SCRIPT_COMMAND init' to create required directories, or
2. Check if you're in the correct project directory, or
3. Verify tickets_dir setting in your config file
EOF
        return 1
    fi
    
    echo "📋 Ticket List"
    echo "---------------------------"
    if [[ "$filter_status" == "done" ]]; then
        echo "(sorted by closed date, newest first)"
    elif [[ -z "$filter_status" ]]; then
        echo "(sorted by status: doing, todo, done, then by priority asc)"
    fi
    
    local displayed=0
    local temp_file=$(mktemp)
    
    # Collect all tickets with their metadata
    for ticket_file in "$tickets_dir"/*.md "$tickets_dir"/done/*.md; do
        [[ -f "$ticket_file" ]] || continue
        
        # Extract YAML frontmatter
        local yaml_content=$(extract_yaml_frontmatter "$ticket_file" 2>/dev/null)
        [[ -z "$yaml_content" ]] && continue
        
        # Parse YAML in a temporary file
        echo "$yaml_content" >| "${temp_file}.yml"
        yaml_parse "${temp_file}.yml" 2>/dev/null || continue
        
        # Get fields
        local priority=$(yaml_get "priority" 2>/dev/null || echo "2")
        local description=$(yaml_get "description" 2>/dev/null || echo "")
        local created_at=$(yaml_get "created_at" 2>/dev/null || echo "")
        local started_at=$(yaml_get "started_at" 2>/dev/null || echo "null")
        local closed_at=$(yaml_get "closed_at" 2>/dev/null || echo "null")
        
        # Determine status
        local status=$(get_ticket_status "$started_at" "$closed_at")
        
        # Apply filter
        if [[ -n "$filter_status" ]] && [[ "$status" != "$filter_status" ]]; then
            continue
        fi
        
        # Default filter: show only todo and doing
        if [[ -z "$filter_status" ]] && [[ "$status" == "done" ]]; then
            continue
        fi
        
        # Get relative path from project root
        local ticket_path="${ticket_file#./}"
        
        # Store in temp file for sorting
        # Format: status|priority|ticket_path|description|created_at|started_at|closed_at
        echo "${status}|${priority}|${ticket_path}|${description}|${created_at}|${started_at}|${closed_at}" >> "$temp_file"
    done
    
    # Sort and display
    # Sort by: status (doing first, then todo, then done), then by priority
    # For done tickets, sort by closed_at in descending order (most recent first)
    local sorted_file=$(mktemp)
    if [[ "$filter_status" == "done" ]]; then
        # For done tickets only: sort by closed_at in descending order
        sort -t'|' -k7,7r "$temp_file" > "$sorted_file"
    else
        # For all tickets or other statuses: use original sorting logic
        sort -t'|' -k1,1 -k2,2n "$temp_file" | sed 's/^doing|/0|/; s/^todo|/1|/; s/^done|/2|/' | sort -t'|' -k1,1n -k2,2n | sed 's/^0|/doing|/; s/^1|/todo|/; s/^2|/done|/' > "$sorted_file"
    fi
    
    while IFS='|' read -r status priority ticket_path description created_at started_at closed_at; do
        [[ $displayed -ge $count ]] && break
        
        # Convert timestamps to local timezone
        local created_at_local=$(convert_utc_to_local "$created_at")
        local started_at_local=$(convert_utc_to_local "$started_at")
        local closed_at_local=$(convert_utc_to_local "$closed_at")
        
        echo "- status: $status"
        echo "  ticket_path: $ticket_path"
        [[ -n "$description" ]] && echo "  description: $description"
        echo "  priority: $priority"
        echo "  created_at: $created_at_local"
        [[ "$status" != "todo" ]] && echo "  started_at: $started_at_local"
        [[ "$status" == "done" ]] && [[ "$closed_at" != "null" ]] && echo "  closed_at: $closed_at_local"
        echo
        
        ((displayed++))
    done < "$sorted_file" || true
    
    rm -f "$sorted_file"
    
    # Cleanup
    rm -f "$temp_file" "${temp_file}.yml"
    
    if [[ $displayed -eq 0 ]]; then
        echo "(No tickets found)"
    fi
    
    # Always return success
    return 0
}

# Start working on a ticket
cmd_start() {
    local ticket_input="$1"
    
    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1
    
    # Load configuration
    yaml_parse "$CONFIG_FILE"
    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    local default_branch=$(yaml_get "default_branch" || echo "$DEFAULT_BRANCH")
    local branch_prefix=$(yaml_get "branch_prefix" || echo "$DEFAULT_BRANCH_PREFIX")
    local repository=$(yaml_get "repository" || echo "$DEFAULT_REPOSITORY")
    local auto_push=$(yaml_get "auto_push" || echo "$DEFAULT_AUTO_PUSH")
    local start_success_message=$(yaml_get "start_success_message" || echo "$DEFAULT_START_SUCCESS_MESSAGE")
    
    # Check current branch
    local current_branch=$(get_current_branch)
    if [[ "$current_branch" != "$default_branch" ]]; then
        # We're on a feature branch - handle different scenarios
        if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
            # Feature branch with uncommitted changes - prompt for commit and exit
            cat >&2 << EOF
Error: Uncommitted changes on feature branch
You are on feature branch '$current_branch' with uncommitted changes. Please:
1. Commit your changes: git add . && git commit -m "message"
2. Or stash changes: git stash
3. Then retry starting the new ticket
EOF
            return 1
        else
            # Feature branch with no changes - offer to create new branch from default
            echo "Warning: Currently on feature branch '$current_branch' with no uncommitted changes."
            echo "Creating new feature branch from '$default_branch' branch instead."
            
            # Switch to default branch first
            echo "Switching to '$default_branch' branch..."
            run_git_command "git checkout $default_branch" || return 1
            
            # Check if default branch has differences with the feature branch we were on
            local diff_count=$(git rev-list --count "$current_branch..$default_branch" 2>/dev/null || echo "0")
            if [[ "$diff_count" -gt 0 ]]; then
                cat << EOF

Note: The default branch '$default_branch' has $diff_count new commit(s) compared to feature branch '$current_branch'.
Consider merging or rebasing '$current_branch' to incorporate these changes:
  git checkout $current_branch
  git merge $default_branch
  # or
  git rebase $default_branch

EOF
            fi
        fi
    else
        # We're on the default branch - check for clean working directory
        check_clean_working_dir || return 1
    fi
    
    # Get ticket file
    local ticket_name=$(extract_ticket_name "$ticket_input")
    local ticket_file=$(get_ticket_file "$ticket_name" "$tickets_dir")
    
    # Check if ticket exists
    if [[ ! -f "$ticket_file" ]]; then
        cat >&2 << EOF
Error: Ticket not found
Ticket '$ticket_file' does not exist. Please:
1. Check the ticket name spelling
2. Run '$SCRIPT_COMMAND list' to see available tickets
3. Use '$SCRIPT_COMMAND new <slug>' to create a new ticket
EOF
        return 1
    fi
    
    # Create branch name
    local branch_name="${branch_prefix}${ticket_name}"
    
    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        # Branch exists - checkout and restore
        echo "Branch '$branch_name' already exists. Resuming work on existing ticket..."
        
        # Checkout existing branch
        run_git_command "git checkout $branch_name" || return 1
        
        # Check if there are differences between this feature branch and the default branch
        local ahead_count=$(git rev-list --count "$default_branch..$branch_name" 2>/dev/null || echo "0")
        local behind_count=$(git rev-list --count "$branch_name..$default_branch" 2>/dev/null || echo "0")
        
        if [[ "$behind_count" -gt 0 ]]; then
            cat << EOF

Warning: Feature branch '$branch_name' is $behind_count commit(s) behind '$default_branch'.
Consider updating your feature branch to incorporate recent changes:
  git merge $default_branch
  # or
  git rebase $default_branch

EOF
        fi
        
        if [[ "$ahead_count" -gt 0 ]]; then
            echo "Feature branch '$branch_name' is $ahead_count commit(s) ahead of '$default_branch'."
        fi
        
        # Create symlink (restore functionality)
        rm -f "$CURRENT_TICKET_LINK"
        ln -s "$ticket_file" "$CURRENT_TICKET_LINK"
        
        echo "Resumed ticket: $ticket_name"
        echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
        echo "Continuing work on existing feature branch."
        
        # Display success message if configured
        if [[ -n "$start_success_message" ]]; then
            echo ""
            echo "$start_success_message"
        fi
        return 0
    fi
    
    # Branch doesn't exist - check if ticket is already started
    local yaml_content=$(extract_yaml_frontmatter "$ticket_file")
    echo "$yaml_content" >| /tmp/ticket_yaml.yml
    yaml_parse /tmp/ticket_yaml.yml
    local started_at=$(yaml_get "started_at" || echo "null")
    rm -f /tmp/ticket_yaml.yml
    
    if ! is_null_or_empty "$started_at"; then
        cat >&2 << EOF
Error: Ticket already started but branch is missing
Ticket has been started (started_at is set) but the branch doesn't exist. Please:
1. Reset the ticket by manually editing started_at to null
2. Or create the branch manually: git checkout -b $branch_name
3. Then use '$SCRIPT_COMMAND restore' to restore the link
EOF
        return 1
    fi
    
    # Update ticket started_at
    local timestamp=$(get_utc_timestamp)
    update_yaml_frontmatter_field "$ticket_file" "started_at" "$timestamp"
    
    # Create and checkout new branch
    run_git_command "git checkout -b $branch_name" || return 1
    
    # Create symlink
    rm -f "$CURRENT_TICKET_LINK"
    ln -s "$ticket_file" "$CURRENT_TICKET_LINK"
    
    echo "Started ticket: $ticket_name"
    echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
    echo "Note: Branch created locally. Use 'git push -u $repository $branch_name' when ready to share."
    
    # Display success message if configured
    if [[ -n "$start_success_message" ]]; then
        echo ""
        echo "$start_success_message"
    fi
}

# Restore current ticket link
cmd_restore() {
    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1
    
    # Load configuration
    yaml_parse "$CONFIG_FILE"
    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    local branch_prefix=$(yaml_get "branch_prefix" || echo "$DEFAULT_BRANCH_PREFIX")
    local restore_success_message=$(yaml_get "restore_success_message" || echo "$DEFAULT_RESTORE_SUCCESS_MESSAGE")
    
    # Get current branch
    local current_branch=$(get_current_branch)
    
    # Check if on feature branch
    if [[ ! "$current_branch" =~ ^${branch_prefix} ]]; then
        cat >&2 << EOF
Error: Not on a feature branch
Current branch '$current_branch' is not a feature branch. Please:
1. Switch to a feature branch (${branch_prefix}*)
2. Or start a new ticket: $SCRIPT_COMMAND start <ticket-name>
3. Feature branches should start with '$branch_prefix'
EOF
        return 1
    fi
    
    # Extract ticket name from branch
    local ticket_name="${current_branch#"$branch_prefix"}"
    local ticket_file="${tickets_dir}/${ticket_name}.md"
    
    # Check if ticket file exists in regular location or done folder
    if [[ ! -f "$ticket_file" ]]; then
        # Check in done folder
        ticket_file="${tickets_dir}/done/${ticket_name}.md"
        if [[ ! -f "$ticket_file" ]]; then
            cat >&2 << EOF
Error: No matching ticket found
No ticket file found for branch '$current_branch'. Please:
1. Check if ticket file exists in $tickets_dir/ or $tickets_dir/done/
2. Ensure branch name matches ticket name format
3. Or start a new ticket if this is a new feature
EOF
            return 1
        fi
    fi
    
    # Create symlink
    rm -f "$CURRENT_TICKET_LINK"
    if ! ln -s "$ticket_file" "$CURRENT_TICKET_LINK"; then
        cat >&2 << EOF
Error: Cannot create symlink
Permission denied creating symlink. Please:
1. Check write permissions in current directory
2. Ensure no file named '$CURRENT_TICKET_LINK' exists
3. Run with appropriate permissions if needed
EOF
        return 1
    fi
    
    echo "Restored current ticket link: $CURRENT_TICKET_LINK -> $ticket_file"
    
    # Display success message if configured
    if [[ -n "$restore_success_message" ]]; then
        echo ""
        echo "$restore_success_message"
    fi
}

# Check current directory and ticket/branch synchronization status
cmd_check() {
    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1
    
    # Load configuration
    yaml_parse "$CONFIG_FILE"
    local default_branch=$(yaml_get "default_branch" || echo "$DEFAULT_BRANCH")
    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    local branch_prefix=$(yaml_get "branch_prefix" || echo "$DEFAULT_BRANCH_PREFIX")
    
    # Get current branch
    local current_branch=$(get_current_branch)
    
    # Check if current-ticket.md exists
    if [[ -L "$CURRENT_TICKET_LINK" && -f "$CURRENT_TICKET_LINK" ]]; then
        # Case 1 & 2: current-ticket.md exists
        local ticket_file=$(readlink "$CURRENT_TICKET_LINK")
        local ticket_name=$(basename "$ticket_file" .md)
        local expected_branch="${branch_prefix}${ticket_name}"
        
        if [[ "$current_branch" == "$expected_branch" ]]; then
            # Case 1: current-ticket.md exists and matches branch
            echo "✓ Current ticket is active and synchronized"
            echo "Working on: $ticket_name"
            echo "Branch: $current_branch"
            echo "Continue working on this ticket."
        else
            # Case 2: current-ticket.md exists but doesn't match branch
            echo "✗ Ticket file and branch mismatch detected"
            echo "Current ticket file: $ticket_file"
            echo "Current branch: $current_branch"
            echo "Please run '$SCRIPT_COMMAND restore' to fix synchronization or switch to the correct branch."
            return 1
        fi
    else
        # Cases 3-6: current-ticket.md doesn't exist
        if [[ "$current_branch" == "$default_branch" ]]; then
            # Case 3: On default branch, no current ticket
            echo "✓ No active ticket (on default branch)"
            echo "You can view available tickets with: $SCRIPT_COMMAND list"
            echo "Create a new ticket with: $SCRIPT_COMMAND new <name>"
            echo "Start working on a ticket with: $SCRIPT_COMMAND start <ticket-name>"
        elif [[ "$current_branch" =~ ^${branch_prefix} ]]; then
            # Cases 4-5: On feature branch
            local ticket_name="${current_branch#"$branch_prefix"}"
            local ticket_file="${tickets_dir}/${ticket_name}.md"
            
            # Check if ticket file exists in regular location or done folder
            if [[ -f "$ticket_file" ]]; then
                # Extract YAML frontmatter and check started_at
                local yaml_content=$(extract_yaml_frontmatter "$ticket_file" 2>/dev/null)
                local temp_yaml_file=$(mktemp)
                echo "$yaml_content" > "$temp_yaml_file"
                
                # Parse the YAML and check started_at
                yaml_parse "$temp_yaml_file"
                local started_at=$(yaml_get "started_at")
                rm -f "$temp_yaml_file"
                
                if [[ "$started_at" == "null" || -z "$started_at" ]]; then
                    # started_at is null, ticket not started
                    echo "✗ No ticket found for current feature branch"
                    echo "Current branch: $current_branch"
                    echo "Expected ticket file: $ticket_file"
                    echo ""
                    echo "Possible solutions:"
                    echo "1. Create new ticket: $SCRIPT_COMMAND new <name>"
                    echo "2. Check if ticket file exists in another branch (git branch -a)"
                    echo "3. Switch to default branch: git checkout $default_branch"
                    return 1
                else
                    # Case 4: Ticket exists and started_at is not null, restore it
                    rm -f "$CURRENT_TICKET_LINK"
                    if ln -s "$ticket_file" "$CURRENT_TICKET_LINK"; then
                        echo "✓ Found matching ticket for current branch"
                        echo "Restored ticket link: $ticket_name"
                        echo "Continue working on this ticket."
                    else
                        echo "✗ Failed to restore ticket link"
                        echo "Permission denied creating symlink."
                        return 1
                    fi
                fi
            else
                # Check in done folder
                ticket_file="${tickets_dir}/done/${ticket_name}.md"
                if [[ -f "$ticket_file" ]]; then
                    # Extract YAML frontmatter and check started_at
                    local yaml_content=$(extract_yaml_frontmatter "$ticket_file" 2>/dev/null)
                    local temp_yaml_file=$(mktemp)
                    echo "$yaml_content" > "$temp_yaml_file"
                    
                    # Parse the YAML and check started_at
                    yaml_parse "$temp_yaml_file"
                    local started_at=$(yaml_get "started_at")
                    rm -f "$temp_yaml_file"
                    
                    if [[ "$started_at" == "null" || -z "$started_at" ]]; then
                        # started_at is null, ticket not started
                        echo "✗ No ticket found for current feature branch"
                        echo "Current branch: $current_branch"
                        echo "Expected ticket file: $ticket_file"
                        echo ""
                        echo "Possible solutions:"
                        echo "1. Create new ticket: $SCRIPT_COMMAND new <name>"
                        echo "2. Check if ticket file exists in another branch (git branch -a)"
                        echo "3. Switch to default branch: git checkout $default_branch"
                        return 1
                    else
                        # Ticket exists in done folder and started_at is not null, restore it
                        rm -f "$CURRENT_TICKET_LINK"
                        if ln -s "$ticket_file" "$CURRENT_TICKET_LINK"; then
                            echo "✓ Found matching ticket for current branch"
                            echo "Restored ticket link: $ticket_name"
                            echo "Continue working on this ticket."
                        else
                            echo "✗ Failed to restore ticket link"
                            echo "Permission denied creating symlink."
                            return 1
                        fi
                    fi
                else
                    # Case 5: No ticket file found for feature branch
                    echo "✗ No ticket found for current feature branch"
                    echo "Current branch: $current_branch"
                    echo "Expected ticket file: ${tickets_dir}/${ticket_name}.md"
                    echo ""
                    echo "Possible solutions:"
                    echo "1. Create new ticket: $SCRIPT_COMMAND new <name>"
                    echo "2. Check if ticket file exists in another branch (git branch -a)"
                    echo "3. Switch to default branch: git checkout $default_branch"
                    return 1
                fi
            fi
        else
            # Case 6: On unknown branch
            echo "⚠ You are on an unknown branch"
            echo "Current branch: $current_branch"
            echo "Recommended: Switch to default branch with 'git checkout $default_branch'"
            echo "Then use '$SCRIPT_COMMAND list' to see available tickets."
        fi
    fi
}

# Close current ticket
cmd_close() {
    local no_push=false
    local force=false
    local no_delete_remote=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-push)
                no_push=true
                shift
                ;;
            --force|-f)
                force=true
                shift
                ;;
            --no-delete-remote)
                no_delete_remote=true
                shift
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                echo "Usage: $SCRIPT_COMMAND close [--no-push] [--force|-f] [--no-delete-remote]" >&2
                return 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1
    
    # Check clean working directory unless --force is used
    if [[ "$force" == "false" ]]; then
        if ! check_clean_working_dir; then
            cat >&2 << EOF

To ignore uncommitted changes and force close, use:
  $SCRIPT_COMMAND close --force (or -f)

Or handle the changes:
  1. Commit your changes: git add . && git commit -m "message"
  2. Stash changes: git stash

Remember to update current-ticket.md with your progress before committing.

IMPORTANT: Never discard changes without explicit user permission.
EOF
            return 1
        fi
    fi
    
    # Check current ticket link
    if [[ ! -L "$CURRENT_TICKET_LINK" ]]; then
        cat >&2 << EOF
Error: No current ticket
No current ticket found ($CURRENT_TICKET_LINK missing). Please:
1. Start a ticket: $SCRIPT_COMMAND start <ticket-name>
2. Or restore link: $SCRIPT_COMMAND restore (if on feature branch)
3. Or switch to a feature branch first
EOF
        return 1
    fi
    
    # Get ticket file
    local ticket_file=$(readlink "$CURRENT_TICKET_LINK")
    if [[ ! -f "$ticket_file" ]]; then
        cat >&2 << EOF
Error: Invalid current ticket
Current ticket file not found or corrupted. Please:
1. Use '$SCRIPT_COMMAND restore' to fix the link
2. Or start a new ticket: $SCRIPT_COMMAND start <ticket-name>
3. Check if ticket file was moved or deleted
EOF
        return 1
    fi
    
    # Load configuration
    yaml_parse "$CONFIG_FILE"
    local default_branch=$(yaml_get "default_branch" || echo "$DEFAULT_BRANCH")
    local branch_prefix=$(yaml_get "branch_prefix" || echo "$DEFAULT_BRANCH_PREFIX")
    local repository=$(yaml_get "repository" || echo "$DEFAULT_REPOSITORY")
    local auto_push=$(yaml_get "auto_push" || echo "$DEFAULT_AUTO_PUSH")
    local delete_remote_on_close=$(yaml_get "delete_remote_on_close" || echo "$DEFAULT_DELETE_REMOTE_ON_CLOSE")
    local close_success_message=$(yaml_get "close_success_message" || echo "$DEFAULT_CLOSE_SUCCESS_MESSAGE")
    
    # Check current branch
    local current_branch=$(get_current_branch)
    if [[ ! "$current_branch" =~ ^${branch_prefix} ]]; then
        cat >&2 << EOF
Error: Not on a feature branch
Must be on a feature branch to close ticket. Please:
1. Switch to feature branch: git checkout ${branch_prefix}<ticket-name>
2. Or check current branch: git branch
3. Feature branches start with '$branch_prefix'
EOF
        return 1
    fi
    
    # Check ticket status
    local yaml_content=$(extract_yaml_frontmatter "$ticket_file")
    echo "$yaml_content" >| /tmp/ticket_yaml.yml
    yaml_parse /tmp/ticket_yaml.yml
    local started_at=$(yaml_get "started_at" || echo "null")
    local closed_at=$(yaml_get "closed_at" || echo "null")
    local description=$(yaml_get "description" || echo "")
    rm -f /tmp/ticket_yaml.yml
    
    if is_null_or_empty "$started_at"; then
        cat >&2 << EOF
Error: Ticket not started
Ticket has no start time (started_at is null). Please:
1. Start the ticket first: $SCRIPT_COMMAND start <ticket-name>
2. Or check if you're on the correct ticket
EOF
        return 1
    fi
    
    if ! is_null_or_empty "$closed_at"; then
        cat >&2 << EOF
Error: Ticket already completed
Ticket is already closed (closed_at is set). Please:
1. Check ticket status: $SCRIPT_COMMAND list
2. Start a new ticket if needed
3. Or reopen by manually editing the ticket file
EOF
        return 1
    fi
    
    # Store original ticket state for rollback
    local original_ticket_content=$(cat "$ticket_file")
    local original_branch=$(get_current_branch)
    
    # Update closed_at
    local timestamp=$(get_utc_timestamp)
    update_yaml_frontmatter_field "$ticket_file" "closed_at" "$timestamp" || {
        echo "Error: Failed to update ticket closed_at field" >&2
        return 1
    }
    
    # Remove current-ticket.md from git history if it exists
    # This prevents accidental commits of current-ticket.md when force-added
    if git ls-files | grep -q "^current-ticket.md$"; then
        run_git_command "git rm --cached current-ticket.md" || {
            echo "Error: Failed to remove current-ticket.md from git history" >&2
            # Rollback ticket file changes
            echo "$original_ticket_content" > "$ticket_file"
            return 1
        }
    fi
    
    # Commit the change
    run_git_command "git add $ticket_file" || {
        echo "Error: Failed to stage ticket file" >&2
        # Rollback ticket file changes
        echo "$original_ticket_content" > "$ticket_file"
        return 1
    }
    
    run_git_command "git commit -m \"Close ticket\"" || {
        echo "Error: Failed to commit ticket closure" >&2
        # Rollback ticket file changes
        echo "$original_ticket_content" > "$ticket_file"
        # Unstage if needed
        git restore --staged "$ticket_file" 2>/dev/null || true
        return 1
    }
    
    # Get ticket name and full content BEFORE switching branches
    # This ensures we capture the updated content from the feature branch
    local ticket_name=$(basename "$ticket_file" .md)
    local ticket_content=$(cat "$ticket_file")
    
    # Push feature branch if auto_push
    if [[ "$auto_push" == "true" ]] && [[ "$no_push" == "false" ]]; then
        run_git_command "git push $repository $current_branch" || {
            echo "Warning: Failed to push feature branch" >&2
        }
    fi
    
    # Switch to default branch
    run_git_command "git checkout $default_branch" || {
        echo "Error: Failed to switch to default branch '$default_branch'" >&2
        echo "Your changes have been committed on feature branch '$current_branch'" >&2
        echo "Please manually switch to '$default_branch' and run close again" >&2
        return 1
    }
    
    # Create commit message
    local commit_msg="[${ticket_name}] ${description}"
    if [[ -z "$description" ]]; then
        commit_msg="[${ticket_name}] Ticket completed"
    fi
    commit_msg="${commit_msg}\n\n${ticket_content}"
    
    # Squash merge
    run_git_command "git merge --squash $current_branch" || {
        echo "Error: Failed to squash merge feature branch" >&2
        echo "You are now on '$default_branch' branch" >&2
        echo "Feature branch '$current_branch' still exists with your changes" >&2
        echo "Please resolve merge conflicts manually or run 'git merge --abort'" >&2
        return 1
    }
    
    # Move ticket to done folder before committing
    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    local done_dir="${tickets_dir}/done"
    
    # Create done directory if it doesn't exist
    if [[ ! -d "$done_dir" ]]; then
        mkdir -p "$done_dir" || {
            echo "Warning: Failed to create done directory: $done_dir" >&2
        }
    fi
    
    # Move the ticket file to done folder
    if [[ -d "$done_dir" ]]; then
        local new_ticket_path="${done_dir}/$(basename "$ticket_file")"
        run_git_command "git mv \"$ticket_file\" \"$new_ticket_path\"" || {
            echo "Warning: Failed to move ticket to done folder" >&2
        }
    fi
    
    # Commit with ticket content and done folder move together
    echo -e "$commit_msg" | run_git_command "git commit -F -" || {
        echo "Error: Failed to commit final merge" >&2
        echo "Squash merge is staged but not committed" >&2
        echo "You can commit manually with: git commit" >&2
        echo "Or abort with: git reset --hard HEAD" >&2
        return 1
    }
    
    # Push to remote if auto_push
    if [[ "$auto_push" == "true" ]] && [[ "$no_push" == "false" ]]; then
        run_git_command "git push $repository $default_branch" || {
            echo "Warning: Failed to push to remote repository" >&2
            echo "Local ticket closing completed. Please push manually later:" >&2
            echo "  git push $repository $default_branch" >&2
            echo "" >&2
        }
    fi
    
    # Delete remote branch if configured
    if [[ "$delete_remote_on_close" == "true" ]] && [[ "$no_delete_remote" == "false" ]]; then
        if [[ "$auto_push" == "true" ]] || [[ "$no_push" == "false" ]]; then
            # Check if remote branch exists
            if git ls-remote --heads "$repository" "$current_branch" | grep -q "$current_branch"; then
                run_git_command "git push $repository --delete $current_branch" || {
                    echo "Warning: Failed to delete remote branch '$current_branch'" >&2
                }
            else
                echo "Note: Remote branch '$current_branch' not found (may have been already deleted)"
            fi
        fi
    fi
    
    # At this point, all critical operations have succeeded
    # Now proceed with cleanup operations
    
    # Remove current ticket link - core workflow is complete, safe to remove
    rm -f "$CURRENT_TICKET_LINK"
    
    echo "Ticket completed: $ticket_name"
    echo "Merged to $default_branch branch"
    
    if [[ "$auto_push" == "false" ]] || [[ "$no_push" == "true" ]]; then
        echo "Note: Changes not pushed to remote. Use 'git push $repository $default_branch' and 'git push $repository $current_branch' when ready."
    fi
    
    # Display success message if configured
    if [[ -n "$close_success_message" ]]; then
        echo ""
        echo "$close_success_message"
    fi
}

# Command: version
# Display version information
cmd_version() {
    echo "ticket.sh - Git-based Ticket Management System"
    echo "Version: $VERSION"
    echo "https://github.com/masuidrive/ticket.sh"
}

# Command: prompt
# Display the prompt instructions for AI coding assistants
cmd_prompt() {
    cat << 'EOF'
# Ticket Management Instructions

Use `./ticket.sh` for ticket management.

## Working with current-ticket.md

### If current-ticket.md exists in project root
- This file is your work instruction - follow its contents
- When receiving additional instructions from users, document them in this file before proceeding
- Continue working on the active ticket

### If current-ticket.md does not exist in project root
- When receiving user requests, first ask whether to create a new ticket
- Do not start work without confirming ticket creation
- Even small requests should be tracked through the ticket system

## Create New Ticket

1. Create ticket: `./ticket.sh new feature-name`
2. Edit ticket content and description in the generated file

## Start Working on Ticket

1. Check available tickets: `./ticket.sh` list or browse tickets directory
2. Start work: `./ticket.sh start 241225-143502-feature-name`
3. Develop on feature branch (`current-ticket.md` shows active ticket)

## Closing Tickets

1. Before closing:
   - Review `current-ticket.md` content and description
   - Check all tasks in checklist are completed (mark with `[x]`)
   - Get user approval before proceeding
2. Complete: `./ticket.sh close`
EOF
}

# Command: selfupdate
# Update ticket.sh from the latest version on GitHub
cmd_selfupdate() {
    echo "Starting self-update..."
    
    local script_path="$(realpath "$0")"
    local temp_file=$(mktemp)
    local update_script=$(mktemp)
    
    # Download latest version
    echo "Downloading latest version from GitHub..."
    if ! curl -fsSL https://raw.githubusercontent.com/masuidrive/ticket.sh/main/ticket.sh -o "$temp_file"; then
        echo "Error: Failed to download update" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    # Verify download
    if [[ ! -s "$temp_file" ]]; then
        echo "Error: Downloaded file is empty" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    # Create update script
    cat > "$update_script" << EOF
#!/bin/bash
# Wait for parent process to exit
sleep 1

# Replace with new version
mv "$temp_file" "$script_path" 2>/dev/null || cp "$temp_file" "$script_path"
chmod +x "$script_path"

# Show completion message
echo ""
echo "✅ Update completed successfully!"
echo "Run '$script_path help' to see available commands."

# Clean up
rm -f "\$0"
EOF
    
    chmod +x "$update_script"
    
    # Launch update process
    echo "Installing update..."
    nohup bash "$update_script" 2>&1 | tail -n +2 &
    
    # Exit to allow update
    exit 0
}

# Main command dispatcher
main() {
    case "${1:-}" in
        init)
            cmd_init
            ;;
        new)
            if [[ -z "${2:-}" ]]; then
                echo "Error: slug required" >&2
                echo "Usage: $SCRIPT_COMMAND new <slug>" >&2
                exit 1
            fi
            cmd_new "$2"
            ;;
        list)
            shift
            cmd_list "$@"
            ;;
        start)
            if [[ -z "${2:-}" ]]; then
                echo "Error: ticket name required" >&2
                echo "Usage: $SCRIPT_COMMAND start <ticket-name>" >&2
                exit 1
            fi
            cmd_start "$2"
            ;;
        restore)
            cmd_restore
            ;;
        check)
            cmd_check
            ;;
        close)
            shift
            cmd_close "$@"
            ;;
        selfupdate)
            cmd_selfupdate
            ;;
        version|--version|-v)
            cmd_version
            ;;
        prompt)
            cmd_prompt
            ;;
        help|--help|-h)
            show_usage
            ;;
        "")
            show_usage
            ;;
        *)
            echo "Error: Unknown command: $1" >&2
            echo "Run '$SCRIPT_COMMAND help' for usage information" >&2
            exit 1
            ;;
    esac
}

# Run main function
main "$@"