#!/usr/bin/env bash

# ticket.sh - Ticket Management System for Coding Agents
# Version: 1.0.0

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required libraries
source "${SCRIPT_DIR}/../lib/yaml-sh.sh"
source "${SCRIPT_DIR}/../lib/yaml-frontmatter.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"

# Global variables
CONFIG_FILE=".ticket-config.yml"
CURRENT_TICKET_LINK="current-ticket.md"

# Default configuration values
DEFAULT_TICKETS_DIR="tickets"
DEFAULT_BRANCH="develop"
DEFAULT_BRANCH_PREFIX="feature/"
DEFAULT_REPOSITORY="origin"
DEFAULT_AUTO_PUSH="true"
DEFAULT_CONTENT='# Ticket Overview

Write the overview and tasks for this ticket here.

## Tasks
- [ ] Task 1
- [ ] Task 2

## Notes
Additional notes or requirements.'

# Show usage information
show_usage() {
    cat << 'EOF'
Ticket Management System for Coding Agents

OVERVIEW:
This is a self-contained ticket management system using shell script + files + Git.
Each ticket is a single Markdown file with YAML frontmatter metadata.

USAGE:
  ./ticket.sh init                     Initialize system (create config, directories, .gitignore)
  ./ticket.sh new <slug>               Create new ticket file (slug: lowercase, numbers, hyphens only)
  ./ticket.sh list [--status STATUS] [--count N]  List tickets (default: todo + doing, count: 20)
  ./ticket.sh start <ticket-name> [--no-push]     Start working on ticket (creates feature branch)
  ./ticket.sh restore                  Restore current-ticket.md symlink from branch name
  ./ticket.sh close [--no-push]       Complete current ticket (squash merge to default branch)

TICKET STRUCTURE:
- File: tickets/YYMMDD-hhmmss-<slug>.md
- Metadata in YAML frontmatter (priority, description, timestamps)
- Status determined by started_at/closed_at fields
- Work done on feature/<ticket-name> branches

PUSH CONTROL:
- Set auto_push: false in config to disable automatic pushing
- Use --no-push flag to override auto_push: true for single command
- Git commands and outputs are displayed for transparency

WORKFLOW:
1. Create ticket: ./ticket.sh new feature-name (use lowercase, numbers, hyphens only)
2. Edit ticket content and description
3. Start work: ./ticket.sh start YYMMDD-hhmmss-feature-name
4. Develop on feature branch (current-ticket.md shows active ticket)
5. Complete: ./ticket.sh close

Note: current-ticket.md is git-ignored. Use 'restore' after clone/pull.
EOF
}

# Initialize ticket system
cmd_init() {
    echo "Initializing ticket system..."
    
    # Check git repository
    check_git_repo || return 1
    
    # Create config file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
# Ticket system configuration

# Directory settings
tickets_dir: "$DEFAULT_TICKETS_DIR"

# Git settings
default_branch: "$DEFAULT_BRANCH"
branch_prefix: "$DEFAULT_BRANCH_PREFIX"
repository: "$DEFAULT_REPOSITORY"
auto_push: $DEFAULT_AUTO_PUSH

# Ticket template
default_content: |
$DEFAULT_CONTENT
EOF
        echo "Created configuration file: $CONFIG_FILE"
    else
        echo "Configuration file already exists: $CONFIG_FILE"
    fi
    
    # Parse config to get tickets_dir
    yaml_parse "$CONFIG_FILE"
    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    
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
    
    echo "Ticket system initialized successfully!"
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
1. Run 'ticket.sh init' to create required directories, or
2. Check if you're in the correct project directory, or
3. Verify tickets_dir setting in .ticket-config.yml
EOF
        return 1
    fi
    
    echo "📋 Ticket List"
    echo "---------------------------"
    
    local displayed=0
    local temp_file=$(mktemp)
    
    # Collect all tickets with their metadata
    for ticket_file in "$tickets_dir"/*.md; do
        [[ -f "$ticket_file" ]] || continue
        
        # Extract YAML frontmatter
        local yaml_content=$(extract_yaml_frontmatter "$ticket_file" 2>/dev/null)
        [[ -z "$yaml_content" ]] && continue
        
        # Parse YAML in a temporary file
        echo "$yaml_content" > "${temp_file}.yml"
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
        
        # Get ticket name
        local ticket_name=$(basename "$ticket_file" .md)
        
        # Store in temp file for sorting
        # Format: status|priority|ticket_name|description|created_at|started_at
        echo "${status}|${priority}|${ticket_name}|${description}|${created_at}|${started_at}" >> "$temp_file"
    done
    
    # Sort and display
    # Sort by: status (doing first, then todo, then done), then by priority
    while IFS='|' read -r status priority ticket_name description created_at started_at; do
        [[ $displayed -ge $count ]] && break
        
        echo "- status: $status"
        echo "  ticket_name: $ticket_name"
        [[ -n "$description" ]] && echo "  description: $description"
        echo "  priority: $priority"
        echo "  created_at: $created_at"
        [[ "$status" != "todo" ]] && echo "  started_at: $started_at"
        echo
        
        ((displayed++))
    done < <(sort -t'|' -k1,1 -k2,2n "$temp_file" | sed 's/^doing|/0|/; s/^todo|/1|/; s/^done|/2|/' | sort -t'|' -k1,1n -k2,2n | sed 's/^0|/doing|/; s/^1|/todo|/; s/^2|/done|/')
    
    # Cleanup
    rm -f "$temp_file" "${temp_file}.yml"
    
    if [[ $displayed -eq 0 ]]; then
        echo "(No tickets found)"
    fi
}

# Start working on a ticket
cmd_start() {
    local ticket_input="$1"
    local no_push=false
    
    # Check for --no-push flag
    if [[ "${2:-}" == "--no-push" ]]; then
        no_push=true
    fi
    
    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1
    check_clean_working_dir || return 1
    
    # Load configuration
    yaml_parse "$CONFIG_FILE"
    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    local default_branch=$(yaml_get "default_branch" || echo "$DEFAULT_BRANCH")
    local branch_prefix=$(yaml_get "branch_prefix" || echo "$DEFAULT_BRANCH_PREFIX")
    local repository=$(yaml_get "repository" || echo "$DEFAULT_REPOSITORY")
    local auto_push=$(yaml_get "auto_push" || echo "$DEFAULT_AUTO_PUSH")
    
    # Check current branch
    local current_branch=$(get_current_branch)
    if [[ "$current_branch" != "$default_branch" ]]; then
        cat >&2 << EOF
Error: Wrong branch
Must be on '$default_branch' branch to start new ticket. Please:
1. Switch to $default_branch: git checkout $default_branch
2. Or complete current ticket with 'ticket.sh close'
3. Then retry starting the new ticket
EOF
        return 1
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
2. Run 'ticket.sh list' to see available tickets
3. Use 'ticket.sh new <slug>' to create a new ticket
EOF
        return 1
    fi
    
    # Check if ticket is already started
    local yaml_content=$(extract_yaml_frontmatter "$ticket_file")
    echo "$yaml_content" > /tmp/ticket_yaml.yml
    yaml_parse /tmp/ticket_yaml.yml
    local started_at=$(yaml_get "started_at" || echo "null")
    rm -f /tmp/ticket_yaml.yml
    
    if ! is_null_or_empty "$started_at"; then
        cat >&2 << EOF
Error: Ticket already started
Ticket has already been started (started_at is set). Please:
1. Continue working on the existing branch
2. Use 'ticket.sh restore' to restore current-ticket.md link
3. Or close the current ticket first if starting over
EOF
        return 1
    fi
    
    # Create branch
    local branch_name="${branch_prefix}${ticket_name}"
    
    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        cat >&2 << EOF
Error: Branch already exists
Branch '$branch_name' already exists. Please:
1. Switch to existing branch: git checkout $branch_name
2. Or delete existing branch if no longer needed
3. Use 'ticket.sh restore' to restore ticket link
EOF
        return 1
    fi
    
    # Update ticket started_at
    local timestamp=$(get_utc_timestamp)
    update_yaml_frontmatter_field "$ticket_file" "started_at" "$timestamp"
    
    # Create and checkout branch
    run_git_command "git checkout -b $branch_name" || return 1
    
    # Push to remote if auto_push is true and --no-push not specified
    if [[ "$auto_push" == "true" ]] && [[ "$no_push" == "false" ]]; then
        run_git_command "git push -u $repository $branch_name" || {
            echo "Warning: Failed to push branch to remote" >&2
        }
    fi
    
    # Create symlink
    rm -f "$CURRENT_TICKET_LINK"
    ln -s "$ticket_file" "$CURRENT_TICKET_LINK"
    
    echo "Started ticket: $ticket_name"
    echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
    
    if [[ "$auto_push" == "false" ]] || [[ "$no_push" == "true" ]]; then
        echo "Note: Branch not pushed to remote. Use 'git push -u $repository $branch_name' when ready."
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
    
    # Get current branch
    local current_branch=$(get_current_branch)
    
    # Check if on feature branch
    if [[ ! "$current_branch" =~ ^${branch_prefix} ]]; then
        cat >&2 << EOF
Error: Not on a feature branch
Current branch '$current_branch' is not a feature branch. Please:
1. Switch to a feature branch (${branch_prefix}*)
2. Or start a new ticket: ticket.sh start <ticket-name>
3. Feature branches should start with '$branch_prefix'
EOF
        return 1
    fi
    
    # Extract ticket name from branch
    local ticket_name="${current_branch#$branch_prefix}"
    local ticket_file="${tickets_dir}/${ticket_name}.md"
    
    # Check if ticket file exists
    if [[ ! -f "$ticket_file" ]]; then
        cat >&2 << EOF
Error: No matching ticket found
No ticket file found for branch '$current_branch'. Please:
1. Check if ticket file exists in $tickets_dir/
2. Ensure branch name matches ticket name format
3. Or start a new ticket if this is a new feature
EOF
        return 1
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
}

# Close current ticket
cmd_close() {
    local no_push=false
    
    # Check for --no-push flag
    if [[ "${1:-}" == "--no-push" ]]; then
        no_push=true
    fi
    
    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1
    check_clean_working_dir || return 1
    
    # Check current ticket link
    if [[ ! -L "$CURRENT_TICKET_LINK" ]]; then
        cat >&2 << EOF
Error: No current ticket
No current ticket found ($CURRENT_TICKET_LINK missing). Please:
1. Start a ticket: ticket.sh start <ticket-name>
2. Or restore link: ticket.sh restore (if on feature branch)
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
1. Use 'ticket.sh restore' to fix the link
2. Or start a new ticket: ticket.sh start <ticket-name>
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
    echo "$yaml_content" > /tmp/ticket_yaml.yml
    yaml_parse /tmp/ticket_yaml.yml
    local started_at=$(yaml_get "started_at" || echo "null")
    local closed_at=$(yaml_get "closed_at" || echo "null")
    local description=$(yaml_get "description" || echo "")
    rm -f /tmp/ticket_yaml.yml
    
    if is_null_or_empty "$started_at"; then
        cat >&2 << EOF
Error: Ticket not started
Ticket has no start time (started_at is null). Please:
1. Start the ticket first: ticket.sh start <ticket-name>
2. Or check if you're on the correct ticket
EOF
        return 1
    fi
    
    if ! is_null_or_empty "$closed_at"; then
        cat >&2 << EOF
Error: Ticket already completed
Ticket is already closed (closed_at is set). Please:
1. Check ticket status: ticket.sh list
2. Start a new ticket if needed
3. Or reopen by manually editing the ticket file
EOF
        return 1
    fi
    
    # Update closed_at
    local timestamp=$(get_utc_timestamp)
    update_yaml_frontmatter_field "$ticket_file" "closed_at" "$timestamp"
    
    # Commit the change
    run_git_command "git add $ticket_file" || return 1
    run_git_command "git commit -m \"Close ticket\"" || return 1
    
    # Push feature branch if auto_push
    if [[ "$auto_push" == "true" ]] && [[ "$no_push" == "false" ]]; then
        run_git_command "git push $repository $current_branch" || {
            echo "Warning: Failed to push feature branch" >&2
        }
    fi
    
    # Switch to default branch
    run_git_command "git checkout $default_branch" || return 1
    
    # Get ticket name and full content
    local ticket_name=$(basename "$ticket_file" .md)
    local ticket_content=$(cat "$ticket_file")
    
    # Create commit message
    local commit_msg="[${ticket_name}] ${description}"
    if [[ -z "$description" ]]; then
        commit_msg="[${ticket_name}] Ticket completed"
    fi
    commit_msg="${commit_msg}\n\n${ticket_content}"
    
    # Squash merge
    run_git_command "git merge --squash $current_branch" || return 1
    
    # Commit with ticket content
    echo -e "$commit_msg" | run_git_command "git commit -F -" || return 1
    
    # Push to remote if auto_push
    if [[ "$auto_push" == "true" ]] && [[ "$no_push" == "false" ]]; then
        run_git_command "git push $repository $default_branch" || {
            cat >&2 << EOF
Error: Push failed
Failed to push to '$repository'. Please:
1. Check network connection
2. Verify repository permissions
3. Try manual push: git push $repository $default_branch
4. Check if remote repository exists
EOF
            return 1
        }
    fi
    
    # Remove current ticket link
    rm -f "$CURRENT_TICKET_LINK"
    
    echo "Ticket completed: $ticket_name"
    echo "Merged to $default_branch branch"
    
    if [[ "$auto_push" == "false" ]] || [[ "$no_push" == "true" ]]; then
        echo "Note: Changes not pushed to remote. Use 'git push $repository $default_branch' and 'git push $repository $current_branch' when ready."
    fi
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
                echo "Usage: ticket.sh new <slug>" >&2
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
                echo "Usage: ticket.sh start <ticket-name> [--no-push]" >&2
                exit 1
            fi
            cmd_start "$2" "${3:-}"
            ;;
        restore)
            cmd_restore
            ;;
        close)
            cmd_close "${2:-}"
            ;;
        help|--help|-h)
            show_usage
            ;;
        "")
            show_usage
            ;;
        *)
            echo "Error: Unknown command: $1" >&2
            echo "Run 'ticket.sh help' for usage information" >&2
            exit 1
            ;;
    esac
}

# Run main function
main "$@"