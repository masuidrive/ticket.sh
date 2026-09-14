#!/usr/bin/env bash

# append-only.sh - refuse a close that took lines back out of a ticket file the
# project declared append-only.
#
# Some per-ticket files are a record of how the work went, not a description of
# where it stands: a progress log is worth keeping precisely because nobody went
# back and tidied the wrong turns out of it. Nothing enforced that. A project
# can run such a check in its own test suite, but the runs that most need it are
# the ones that stop at a human gate before the tests ever run. `close` is the
# command that always happens, and it already knows which branch belongs to
# which ticket, so the count belongs here.
#
# What is judged is not "did some commit remove a line" but "is a line that was
# removed still missing". Those come apart the moment you try to fix a
# violation: history is not to be rewritten, so the only repair available is to
# append the lines again - and a rule that looked at commits alone would go on
# failing after the repair, leaving amend-and-force-push as the sole way out.
# That is the opposite of what a file kept for its history wants. So each
# removed line is forgiven once it is back in the file, whatever route it took
# to get there.
#
# A modified line therefore counts as a removal: its old text is gone from the
# file. That is the intended reading. Append-only means a line already written
# is not edited afterwards; a typo fix in yesterday's entry is exactly the small
# rewrite this is meant to catch, and the way to record the correction is a new
# line saying so.
#
# Only committed history is read, and forgiveness is measured against the file
# as it stands in the working tree - the copy the author is looking at and can
# still add to.

# Resolve the ref to measure "since this branch started" against.
#
# The remote-tracking ref is tried first: on CI the base branch commonly exists
# only as <repository>/<base>, with nothing ever checked out locally, and a gate
# that silently does nothing when its ref is missing is worse than no gate at
# all. Falls back to the local branch, and returns 1 when neither exists so the
# caller can say so out loud rather than pass by default.
#
# Usage: append_only_base_ref <base_branch> <repository>
append_only_base_ref() {
    local base="$1"
    local repository="$2"

    [[ -n "$base" ]] || return 1

    if [[ -n "$repository" ]] && \
       git rev-parse --verify --quiet "refs/remotes/${repository}/${base}" >/dev/null 2>&1; then
        echo "${repository}/${base}"
        return 0
    fi
    if git rev-parse --verify --quiet "refs/heads/${base}" >/dev/null 2>&1; then
        echo "$base"
        return 0
    fi
    return 1
}

# Print the lines one commit removed from one file, without their leading '-'.
#
# The hunk-body state machine is what makes a removed line that itself begins
# with '--' distinguishable from the patch's own '--- a/path' header: inside a
# hunk, every '-' is a deletion, and the headers only ever appear outside one.
# -U0 keeps context lines out of the way entirely.
#
# Usage: _append_only_removed_lines <sha> <file>
_append_only_removed_lines() {
    local sha="$1"
    local file="$2"

    git show --format= -U0 "$sha" -- "$file" 2>/dev/null | awk '
        /^diff --git / { in_hunk = 0; next }
        /^@@/          { in_hunk = 1; next }
        in_hunk && /^-/ { print substr($0, 2) }
    '
}

# List the commits since <base_ref> that removed lines from <file> which are
# still not in it.
#
# Prints one record per offending commit, oldest first:
#   <short-sha><TAB><subject><TAB><n><TAB><first missing line>
# and nothing at all when every removal has since been put back.
#
# Merge commits produce no diff output here by default and so contribute
# nothing. That is the right answer rather than a gap: the commits a merge
# brought in are themselves reachable from HEAD, so their removals are already
# counted once, and counting the merge as well would report them twice.
#
# Usage: append_only_violations <base_ref> <file>
append_only_violations() {
    local base_ref="$1"
    local file="$2"

    # Temp files rather than `< <(git log ...)`: process substitution feeding a
    # read loop is the pattern that hangs bash 3.2 on macOS, and this runs on
    # the way to every close.
    local commits_file removed_file missing_file
    commits_file=$(mktemp)
    removed_file=$(mktemp)
    missing_file=$(mktemp)

    git log --reverse --format='%H' "${base_ref}..HEAD" -- "$file" > "$commits_file" 2>/dev/null || true

    local sha count first subject
    while IFS= read -r sha; do
        [[ -n "$sha" ]] || continue

        _append_only_removed_lines "$sha" "$file" > "$removed_file"
        [[ -s "$removed_file" ]] || continue

        # Drop every removed line that the file carries today. Whole-line
        # matching, so a line that merely reappears inside a longer one does
        # not count as restored.
        awk 'NR == FNR { have[$0] = 1; next } !($0 in have)' "$file" "$removed_file" > "$missing_file"
        [[ -s "$missing_file" ]] || continue

        count=$(awk 'END { print NR }' "$missing_file")
        first=$(awk 'NR == 1 { print; exit }' "$missing_file")
        subject=$(git show -s --format='%s' "$sha" 2>/dev/null)
        printf '%s\t%s\t%s\t%s\n' "$(git rev-parse --short "$sha")" "$subject" "$count" "$first"
    done < "$commits_file"

    rm -f "$commits_file" "$removed_file" "$missing_file"
}

# Report on every append-only file of one ticket, and judge them.
#
# Returns 0 when nothing is missing - including when there is nothing to look
# at, because a ticket that never got the file simply has nothing to protect.
# Making the file's presence mandatory is a different rule and would need its
# own key. Returns 1 when at least one declared file is missing lines it once
# had.
#
# Usage: append_only_check <base_ref> <ticket_dir> <path>...
append_only_check() {
    local base_ref="$1"; shift
    local ticket_dir="$1"; shift

    local clean=true
    local rel file record sha subject count first header_shown

    for rel in "$@"; do
        [[ -n "$rel" ]] || continue
        file="${ticket_dir}/${rel}"
        [[ -f "$file" ]] || continue

        local hits_file
        hits_file=$(mktemp)
        append_only_violations "$base_ref" "$file" > "$hits_file"

        header_shown=false
        while IFS=$'\t' read -r sha subject count first; do
            [[ -n "$sha" ]] || continue
            if [[ "$header_shown" == "false" ]]; then
                echo "✗ Append-only file is missing lines it used to have: $file"
                header_shown=true
                clean=false
            fi
            printf '    %s  %s line(s) gone  %s\n' "$sha" "$count" "$subject"
            printf '        %s\n' "$first"
            [[ "$count" -gt 1 ]] && printf '        ... and %s more\n' "$((count - 1))"
        done < "$hits_file"

        rm -f "$hits_file"
    done

    if [[ "$clean" == "false" ]]; then
        cat << EOF

These files are append-only for this branch (config: append_only_files).
Append the missing lines again, in a new commit - do not rewrite the commits
that removed them. Putting a line back is enough: what is judged is whether the
line is in the file now, not whether some commit once took it out. A record of
what was tried is the point of the file, and an edited-clean version of it is
what this check exists to stop.
Measured against '${base_ref}'.
EOF
        return 1
    fi
    return 0
}
