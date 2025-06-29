#!/usr/bin/env bash

# Helper functions for tests to handle cross-platform issues

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