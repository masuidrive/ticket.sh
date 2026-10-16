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
    # A detached HEAD is exactly what the message below is for, so the read must
    # not be what ends the run. Bare, it only survives because every caller
    # invokes us inside an `|| return 1`, which suppresses errexit through the
    # whole function body; called plainly, `set -e` would stop here instead -
    # with git's message already discarded, so nothing would be printed at all.
    # Make that independent of the caller.
    main_branch=$(git -C "$main_repo" symbolic-ref --short HEAD 2>/dev/null || true)
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

# Derive a ticket's name from the path to its file, for either layout:
#   tickets/<name>/ticket.md -> <name>
#   tickets/<name>.md        -> <name>
#
# Usage: ticket_name_from_path <path>
ticket_name_from_path() {
    local path="$1"
    local base="${path##*/}"

    if [[ "$base" == "ticket.md" ]]; then
        local parent="${path%/*}"
        echo "${parent##*/}"
    else
        echo "${base%.md}"
    fi
}

# Read a ticket's `branch:` frontmatter override off a stream.
#
# awk over the frontmatter rather than yaml-sh, for the same reason
# started_at_on_branch does it: yaml_parse writes to globals that the caller is
# usually in the middle of using for the config, and a helper that quietly
# replaced the config under its caller would be a trap.
#
# Prints nothing when the field is absent, empty, or null.
_ticket_branch_from_stream() {
    awk '
        /^---[[:space:]]*$/ { fence++; if (fence > 1) exit; next }
        fence == 1 && /^branch:/ {
            sub(/^branch:[[:space:]]*/, "")
            sub(/[[:space:]]+#.*$/, "")
            sub(/[[:space:]]+$/, "")
            gsub(/^["'"'"']|["'"'"']$/, "")
            if ($0 == "null" || $0 == "~") exit
            print
            exit
        }'
}

# The branch a ticket names for itself, or nothing when it names none.
#
# Usage: ticket_branch_override <ticket_file>
ticket_branch_override() {
    local ticket_file="$1"
    [[ -f "$ticket_file" ]] || return 0
    _ticket_branch_from_stream < "$ticket_file"
}

# The feature branch a ticket belongs on: its `branch:` override when it has
# one, otherwise the historical {branch_prefix}<ticket-name>.
#
# Every command that needs to name a ticket's branch goes through here, so a
# ticket whose branch was created by something else - a CI bot that checked out
# agent/issue-12 before ticket.sh ever saw it - is not a ticket ticket.sh has
# to be talked out of managing.
#
# Usage: ticket_branch_name <ticket_file> <branch_prefix> <ticket_name>
ticket_branch_name() {
    local ticket_file="$1"
    local branch_prefix="$2"
    local ticket_name="$3"

    local override
    override=$(ticket_branch_override "$ticket_file")
    if [[ -n "$override" ]]; then
        echo "$override"
    else
        echo "${branch_prefix}${ticket_name}"
    fi
}

# The name of the ticket whose frontmatter claims <branch>, if any.
#
# This is the reverse of ticket_branch_name, and it has to be a scan: the
# branch name carries no trace of which ticket chose it. Only tickets with an
# explicit `branch:` can match, so the common prefix-named ticket never pays
# for this - callers try the prefix first and come here only when that failed.
#
# Usage: ticket_claiming_branch <branch> <tickets_dir>
ticket_claiming_branch() {
    local branch="$1"
    local tickets_dir="$2"

    [[ -n "$branch" ]] || return 1

    local f
    for f in "${tickets_dir}"/*/ticket.md \
             "${tickets_dir}"/*.md \
             "${tickets_dir}"/done/*/ticket.md \
             "${tickets_dir}"/done/*.md; do
        [[ -f "$f" ]] || continue
        if [[ "$(ticket_branch_override "$f")" == "$branch" ]]; then
            ticket_name_from_path "$f"
            return 0
        fi
    done
    return 1
}

# The ticket that belongs to <branch>: the prefix stripped off when that names
# a ticket that exists, otherwise whichever ticket claims the branch by name.
#
# Falls back to the bare prefix strip when neither finds a file, because the
# callers that fail here ("no ticket found for branch X") need to name the file
# they looked for. Returns 1 only when the branch is neither prefixed nor
# claimed - which is a caller's cue that this is not a ticket branch at all.
#
# Usage: ticket_name_for_branch <branch> <tickets_dir> <branch_prefix>
ticket_name_for_branch() {
    local branch="$1"
    local tickets_dir="$2"
    local branch_prefix="$3"

    local stripped=""
    if [[ -n "$branch_prefix" ]] && [[ "$branch" == "${branch_prefix}"* ]]; then
        stripped="${branch#"$branch_prefix"}"
        if [[ -f "${tickets_dir}/${stripped}/ticket.md" ]] || \
           [[ -f "${tickets_dir}/done/${stripped}/ticket.md" ]] || \
           [[ -f "${tickets_dir}/${stripped}.md" ]] || \
           [[ -f "${tickets_dir}/done/${stripped}.md" ]]; then
            echo "$stripped"
            return 0
        fi
    fi

    local claimed
    if claimed=$(ticket_claiming_branch "$branch" "$tickets_dir"); then
        echo "$claimed"
        return 0
    fi

    if [[ -n "$stripped" ]]; then
        echo "$stripped"
        return 0
    fi
    return 1
}

# Read started_at out of a ticket file as it stands on <branch>, without
# checking anything out. Prints nothing when the branch has no such file, or
# when the value is null.
#
# Usage: started_at_on_branch <branch> <ticket_path>
started_at_on_branch() {
    local branch="$1"
    local ticket_path="$2"

    git show "${branch}:${ticket_path}" 2>/dev/null | awk '
        /^---[[:space:]]*$/ { fence++; if (fence > 1) exit; next }
        fence == 1 && /^started_at:/ {
            sub(/^started_at:[[:space:]]*/, "")
            sub(/[[:space:]]*#.*$/, "")
            print
            exit
        }'
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

# Does <branch> carry anything beyond <base> other than the named files?
#
# Returns 0 when every path touched by any commit in <base>..<branch> is one of
# the given <rel> paths, non-zero otherwise - including when the question cannot
# be answered, since a caller that uses this to decide whether to move a branch
# should hear "no" rather than a guess.
#
# This is what tells a ticket's own bookkeeping apart from somebody's work. The
# commits are listed rather than diffed, because a file added on the branch and
# deleted again leaves no net diff while its commits still land wherever the
# branch is merged.
#
# Usage: branch_carries_only <repo> <base> <branch> [<rel>...]
branch_carries_only() {
    local repo="$1"
    local base="$2"
    local branch="$3"
    shift 3

    local touched
    touched=$(git -C "$repo" log --format= --name-only "${base}..${branch}" 2>/dev/null) || return 1

    local line rel found
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        found=false
        for rel in "$@"; do
            [[ -z "$rel" ]] && continue
            if [[ "$line" == "$rel" ]]; then
                found=true
                break
            fi
        done
        [[ "$found" == "true" ]] || return 1
    done <<< "$touched"

    return 0
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

# Run the project's own check before a close is allowed to proceed.
#
# Usage: pre_close_run <command> <ticket_name> <ticket_dir> <ticket_file> \
#                      <feature_branch> <base_branch>
#
# <command> is the single shell line the project put in `pre_close_command`.
# Empty (or the `null` yaml_get hands back for a key written with no value) means
# the project declared no check, which is the default and passes without running
# anything.
#
# The command's stdout and stderr are left alone, so its own messages reach the
# person closing the ticket as written. A wrapper that captured and reformatted
# them could only add a layer to read through: the project knows what its check
# found, and this does not.
#
# Everything about the ticket the check would otherwise have to guess at is
# exported for it. TICKET_DIR is empty for a legacy flat-layout ticket, which has
# no directory - TICKET_FILE is the one that answers "where is the ticket" in
# both layouts.
pre_close_run() {
    local command="$1"
    local ticket_name="$2"
    local ticket_dir="$3"
    local ticket_file="$4"
    local feature_branch="$5"
    local base_branch="$6"

    [[ -z "$command" || "$command" == "null" ]] && return 0

    echo "Running pre_close_command: $command"

    # A subshell, so a check that cd's somewhere or sets a variable cannot
    # change the close that continues after it. errexit and friends are turned
    # off inside it because the value is one line of shell written by the
    # project, and `set -e` would give `grep -q x f && echo ok` a meaning its
    # author did not write; what is judged is the line's own exit status.
    local status=0
    (
        set +e +u +o pipefail
        export TICKET_NAME="$ticket_name"
        export TICKET_DIR="$ticket_dir"
        export TICKET_FILE="$ticket_file"
        export TICKET_BRANCH="$feature_branch"
        export TICKET_BASE_BRANCH="$base_branch"
        eval "$command"
    ) || status=$?

    if [[ "$status" -ne 0 ]]; then
        echo "" >&2
        echo "Error: pre_close_command failed (exit $status)" >&2
        echo "  $command" >&2
        echo "This is the project's own check, and what it reports above is the reason." >&2
        echo "Fix that and run close again. --force does not bypass it: --force speaks" >&2
        echo "to the state of the Git tree, and the project put this check in the way of" >&2
        echo "close on purpose." >&2
        return 1
    fi

    return 0
}


# Run the project's own preparation inside a worktree `start` has just created.
#
# Usage: post_start_run <command> <worktree_path> <ticket_name> <ticket_dir> \
#                       <ticket_file> <feature_branch> <base_branch>
#
# <command> is the single shell line the project put in `post_start_command`.
# Empty (or `null`, which is what yaml_get hands back for a key written with no
# value) means the project declared nothing, which is the default.
#
# This is the counterpart of pre_close_run, and the one way it differs is the
# important part: a failure here does not stop anything. `pre_close_command` is
# a check - its whole job is to refuse. This is preparation, and the worktree is
# already built by the time it runs, so stopping would mean a transient npm
# registry error could leave a ticket that cannot be opened at all. A warning
# that says what to re-run leaves the worktree usable and the problem visible.
# So this always returns 0, and the caller does not test it.
post_start_run() {
    local command="$1"
    local wt_path="$2"
    local ticket_name="$3"
    local ticket_dir="$4"
    local ticket_file="$5"
    local feature_branch="$6"
    local base_branch="$7"

    [[ -z "$command" || "$command" == "null" ]] && return 0

    echo "Running post_start_command: $command"

    # A subshell, for the same reasons as in pre_close_run: the line is shell
    # written elsewhere, errexit would give `test -d x && npm ci` a meaning its
    # author did not write, and a command that cd's somewhere has no business
    # changing the rest of start. The cd is the point here, though - the files
    # this installs belong in the new worktree, not in the main checkout the
    # caller is standing in.
    local status=0
    (
        set +e +u +o pipefail
        cd "$wt_path" || exit 1
        export TICKET_NAME="$ticket_name"
        export TICKET_DIR="$ticket_dir"
        export TICKET_FILE="$ticket_file"
        export TICKET_BRANCH="$feature_branch"
        export TICKET_BASE_BRANCH="$base_branch"
        eval "$command"
    ) || status=$?

    if [[ "$status" -ne 0 ]]; then
        echo "Warning: post_start_command failed (exit $status)" >&2
        echo "  $command" >&2
        echo "The worktree is ready and the ticket is started - only this preparation" >&2
        echo "step did not finish. Fix what it reports above and run it yourself:" >&2
        echo "  cd $wt_path && $command" >&2
    fi

    return 0
}

# The base branch a ticket names, resolved.
#
# Reads `base_branch`, falls back to the historical `merge_to`, and treats both
# an empty/null value and the literal `default` (any case) as "whatever the
# config calls the default branch". Three commands asked this question with
# three copies of the same cascade; `close --no-merge` now asks it twice, once
# for a ticket that is still open and once for one already in done/, which is
# one copy too many to keep writing out.
#
# Usage: ticket_base_from_frontmatter <frontmatter-text> <default_branch>
ticket_base_from_frontmatter() {
    local fm="$1"
    local default_branch="$2"

    local base
    base=$(get_yaml_field "$fm" "base_branch")
    if is_null_or_empty "$base" || \
       [[ "$(echo "$base" | tr '[:upper:]' '[:lower:]')" == "default" ]]; then
        base=$(get_yaml_field "$fm" "merge_to")
    fi
    local lower
    lower=$(echo "$base" | tr '[:upper:]' '[:lower:]')
    if is_null_or_empty "$base" || [[ "$lower" == "default" ]]; then
        base="$default_branch"
    fi
    echo "$base"
}
