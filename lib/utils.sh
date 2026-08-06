#!/usr/bin/env bash

# Utility functions for ticket.sh

# Check if we're in a git repository (supports worktrees where .git is a file)
check_git_repo() {
    if [[ ! -d .git ]] && [[ ! -f .git ]]; then
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

# Check if current directory is a git worktree (not the main working tree)
is_git_worktree() {
    [[ -f .git ]] && grep -q "^gitdir:" .git 2>/dev/null
}

# Get the main repository path from a worktree
get_main_repo_from_worktree() {
    if is_git_worktree; then
        git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/\.git$||'
    else
        git rev-parse --show-toplevel 2>/dev/null
    fi
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
# Usage: check_clean_working_dir [tickets_dir]
check_clean_working_dir() {
    local tickets_dir="${1:-tickets}"
    local porcelain_output
    porcelain_output="$(git status --porcelain 2>/dev/null)"

    if [[ -n "$porcelain_output" ]]; then
        # Check if all uncommitted files are under tickets_dir/
        local has_non_ticket_files=false
        while IFS= read -r line; do
            # git status --porcelain format: XY filename (or XY orig -> renamed)
            local file_path="${line:3}"
            # Handle renames: "R  old -> new"
            if [[ "$file_path" == *" -> "* ]]; then
                file_path="${file_path##* -> }"
            fi
            if [[ "$file_path" != "${tickets_dir}/"* ]]; then
                has_non_ticket_files=true
                break
            fi
        done <<< "$porcelain_output"

        if [[ "$has_non_ticket_files" == "false" ]]; then
            cat >&2 << EOF
Error: Uncommitted changes (ticket files only)
Only ticket files under '${tickets_dir}/' are uncommitted.
Please commit them and retry:
  git add ${tickets_dir}/ && git commit -m "Add ticket files"
Then re-run the ticket command.
EOF
        else
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
        fi
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

# Extract ticket name from various input formats.
# Accepts: bare name, .md file, tickets/<name>/ticket.md, tickets/<name>/,
# tickets/done/<name>/ticket.md.
extract_ticket_name() {
    local input="$1"

    # Strip trailing slashes
    input="${input%/}"

    local basename="${input##*/}"

    if [[ "$basename" == "ticket.md" ]]; then
        # Path is <...>/<name>/ticket.md — take parent dir name
        local parent="${input%/*}"
        basename="${parent##*/}"
    else
        basename="${basename%.md}"
    fi

    echo "$basename"
}

# Detect layout for a given ticket name.
# Echoes one of: "new" (dir with ticket.md), "legacy" (flat .md), "unknown".
# Usage: ticket_layout <ticket_name> <tickets_dir>
ticket_layout() {
    local ticket_name="$1"
    local tickets_dir="$2"
    ticket_name=$(extract_ticket_name "$ticket_name")

    if [[ -f "${tickets_dir}/${ticket_name}/ticket.md" ]]; then
        echo "new"
    elif [[ -f "${tickets_dir}/done/${ticket_name}/ticket.md" ]]; then
        echo "new"
    elif [[ -f "${tickets_dir}/${ticket_name}.md" ]]; then
        echo "legacy"
    elif [[ -f "${tickets_dir}/done/${ticket_name}.md" ]]; then
        echo "legacy"
    else
        echo "unknown"
    fi
}

# Get ticket file path from ticket name.
# Prefers the new-format path when the per-ticket directory exists (open or done);
# falls back to the legacy flat path otherwise.
get_ticket_file() {
    local ticket_name="$1"
    local tickets_dir="$2"

    ticket_name=$(extract_ticket_name "$ticket_name")

    if [[ -f "${tickets_dir}/${ticket_name}/ticket.md" ]]; then
        echo "${tickets_dir}/${ticket_name}/ticket.md"
    elif [[ -f "${tickets_dir}/done/${ticket_name}/ticket.md" ]]; then
        echo "${tickets_dir}/done/${ticket_name}/ticket.md"
    else
        echo "${tickets_dir}/${ticket_name}.md"
    fi
}

# Get note file path from ticket name.
# For new-format tickets, returns the note.md inside the ticket dir; for
# legacy, returns the flat -note.md sibling. Prefers the open location over done/.
get_note_file() {
    local ticket_name="$1"
    local tickets_dir="$2"

    ticket_name=$(extract_ticket_name "$ticket_name")

    if [[ -d "${tickets_dir}/${ticket_name}" ]]; then
        echo "${tickets_dir}/${ticket_name}/note.md"
    elif [[ -d "${tickets_dir}/done/${ticket_name}" ]]; then
        echo "${tickets_dir}/done/${ticket_name}/note.md"
    else
        echo "${tickets_dir}/${ticket_name}-note.md"
    fi
}

# Check if main repo is in a safe state to perform merge operations.
# In parallel multi-worktree workflows, another worker may have checked out
# a different branch or left uncommitted changes in the main repo. Blindly
# merging into the current branch would disrupt them, so this guard halts
# with a clear error.
#
# Usage: check_main_repo_ready <main_repo> <default_branch>
check_main_repo_ready() {
    local main_repo="$1"
    local default_branch="$2"

    local main_branch
    main_branch=$(git -C "$main_repo" symbolic-ref --short HEAD 2>/dev/null)
    if [[ -z "$main_branch" ]]; then
        echo "Error: Cannot determine main repo HEAD at '$main_repo' (detached or invalid)" >&2
        return 1
    fi

    if [[ "$main_branch" != "$default_branch" ]]; then
        cat >&2 << EOF
Error: Main repo HEAD is not on '$default_branch'
Main repository at '$main_repo' is currently on branch '$main_branch',
but ticket.sh needs '$default_branch' to perform the merge.

This commonly happens in parallel multi-worktree workflows where another
worker has checked out a different branch in the main repo. Merging into
'$main_branch' silently would disrupt that worker.

Please switch main repo back to '$default_branch':
  git -C $main_repo checkout $default_branch
Then retry the close.
EOF
        return 1
    fi

    if [[ -n "$(git -C "$main_repo" status --porcelain 2>/dev/null)" ]]; then
        cat >&2 << EOF
Error: Main repo has uncommitted changes
Main repository at '$main_repo' has uncommitted changes that could conflict
with the merge. Another worker may be editing files there.

Please commit or stash the changes in the main repo manually, then retry.
EOF
        return 1
    fi

    return 0
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

# Find the working tree that has <branch> checked out, if any.
# Prints its path, or nothing when the branch is checked out nowhere.
#
# Usage: worktree_holding_branch <repo> <branch>
worktree_holding_branch() {
    local repo="$1"
    local branch="$2"

    git -C "$repo" worktree list --porcelain 2>/dev/null \
        | awk -v target="branch refs/heads/${branch}" '/^worktree /{wt=$0} $0==target{print wt}' \
        | sed 's/^worktree //'
}

# Remove <rel_path> from <wt> when it is untracked there and still hashes to
# <expected_hash>.
#
# Untracked files block a fast-forward that would create them. Removing one is
# only safe when nothing would be lost: it must still match the snapshot taken
# before the commit was built, which rules out both an edit that exists only in
# this tree and a change made by someone else while we worked.
#
# Usage: drop_untracked_if_unchanged <worktree> <rel_path> <expected_hash>
drop_untracked_if_unchanged() {
    local wt="$1"
    local rel_path="$2"
    local expected_hash="$3"

    [[ -f "${wt}/${rel_path}" ]] || return 0
    [[ -n "$expected_hash" ]] || return 1

    # Tracked files are git's business: it knows how to update them, and
    # refuses on its own when they carry local changes.
    if git -C "$wt" ls-files --error-unmatch -- "$rel_path" >/dev/null 2>&1; then
        return 0
    fi

    local current_hash
    current_hash=$(git -C "$wt" hash-object -- "${wt}/${rel_path}" 2>/dev/null) || return 1
    [[ "$current_hash" == "$expected_hash" ]] || return 1

    rm -f "${wt}/${rel_path}"
}

# Fast-forward <branch> to <commit-ish>.
#
# The mechanism depends on whether the branch is checked out somewhere, not on
# worktree mode. The two cases are mutually exclusive: git refuses to fetch into
# a checked-out branch, and a branch nobody has checked out has no working tree
# to merge in.
#
# Optional <path> <hash> pairs name files that may be removed from the target
# working tree first if they are still untracked and unchanged - see
# drop_untracked_if_unchanged. A ticket created by 'new' (which makes no commit)
# sits there untracked and would otherwise block the fast-forward.
#
# Returns non-zero when the fast-forward isn't possible - the branch moved on,
# or the target tree has conflicting local changes. Callers are expected to warn
# and carry on: this is bookkeeping, not the user's work.
#
# Usage: advance_branch_ff <repo> <branch> <commit-ish> [<path> <hash>]...
advance_branch_ff() {
    local repo="$1"
    local branch="$2"
    local commit="$3"
    shift 3

    local wt
    wt=$(worktree_holding_branch "$repo" "$branch")

    if [[ -z "$wt" ]]; then
        # Nobody has it checked out, so move the ref directly. git rejects a
        # non-fast-forward update here by itself.
        git -C "$repo" fetch . "${commit}:${branch}" >/dev/null 2>&1
        return $?
    fi

    while [[ $# -ge 2 ]]; do
        drop_untracked_if_unchanged "$wt" "$1" "$2"
        shift 2
    done

    git -C "$wt" merge --ff-only "$commit" >/dev/null 2>&1
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
    local canceled_at="${3:-null}"

    if ! is_null_or_empty "$canceled_at"; then
        echo "canceled"
    elif is_null_or_empty "$closed_at"; then
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