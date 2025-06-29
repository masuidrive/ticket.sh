#!/usr/bin/env bash

# Cross-platform compatibility layer for tests
# Provides portable alternatives to common commands that differ between GNU/BSD

# =============================================================================
# Platform Detection
# =============================================================================

# Detect the operating system type
detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        *BSD)    echo "bsd" ;;
        *)       echo "unknown" ;;
    esac
}

# Check if running on GNU or BSD userland
is_gnu() {
    # Check if GNU coreutils is installed
    if command -v gdate >/dev/null 2>&1; then
        return 0  # GNU coreutils installed (e.g., via homebrew)
    elif [[ "$(detect_os)" == "linux" ]]; then
        return 0  # Linux usually has GNU tools
    else
        return 1  # Likely BSD
    fi
}

# =============================================================================
# sed compatibility
# =============================================================================

# Portable sed in-place editing
# Usage: sed_i 's/old/new/' file
sed_i() {
    if is_gnu; then
        sed -i "$@"
    else
        # BSD sed requires backup extension, use .bak and delete it
        local last_arg="${@: -1}"
        local other_args=("${@:1:$#-1}")
        sed -i.bak "${other_args[@]}" "$last_arg" && rm -f "${last_arg}.bak"
    fi
}

# Alternative: Use perl if available (more portable)
sed_i_perl() {
    if command -v perl >/dev/null 2>&1; then
        perl -i -pe "$@"
    else
        sed_i "$@"
    fi
}

# =============================================================================
# date compatibility
# =============================================================================

# Portable date formatting
# Usage: date_fmt "+%Y-%m-%d"
date_fmt() {
    local format="$1"
    shift
    
    if command -v gdate >/dev/null 2>&1; then
        gdate "$format" "$@"
    else
        date "$format" "$@"
    fi
}

# Get timestamp N days ago (portable)
# Usage: days_ago 7
days_ago() {
    local days="$1"
    
    if is_gnu || command -v gdate >/dev/null 2>&1; then
        date_fmt "+%Y-%m-%d" -d "$days days ago"
    else
        # BSD date
        date_fmt -v "-${days}d" "+%Y-%m-%d"
    fi
}

# =============================================================================
# mktemp compatibility
# =============================================================================

# Portable temporary file creation
# Usage: mktemp_portable [template]
mktemp_portable() {
    local template="${1:-tmp.XXXXXX}"
    
    if is_gnu; then
        mktemp -t "$template"
    else
        # BSD mktemp requires template to end with .XXXXXX
        if [[ ! "$template" =~ \.XXXXXX$ ]]; then
            template="${template}.XXXXXX"
        fi
        mktemp -t "$template"
    fi
}

# Portable temporary directory creation
# Usage: mktemp_dir [prefix]
mktemp_dir() {
    local prefix="${1:-tmp}"
    
    if is_gnu; then
        mktemp -d -t "${prefix}.XXXXXX"
    else
        mktemp -d -t "${prefix}"
    fi
}

# =============================================================================
# grep compatibility
# =============================================================================

# Extended grep (portable)
# Usage: grep_e "pattern" file
grep_e() {
    # Both GNU and BSD support -E
    grep -E "$@"
}

# Perl-compatible grep (if available)
# Usage: grep_p "pattern" file
grep_p() {
    if command -v ggrep >/dev/null 2>&1; then
        ggrep -P "$@"
    elif grep -P "test" /dev/null 2>&1; then
        grep -P "$@"
    else
        # Fallback to extended regex
        grep -E "$@"
    fi
}

# =============================================================================
# find compatibility
# =============================================================================

# Portable find with regex
# Usage: find_regex "." ".*\.txt$"
find_regex() {
    local path="$1"
    local pattern="$2"
    
    if is_gnu; then
        find "$path" -regextype posix-extended -regex "$pattern"
    else
        find -E "$path" -regex "$pattern"
    fi
}

# =============================================================================
# readlink compatibility
# =============================================================================

# Portable readlink
# Usage: readlink_f file
readlink_f() {
    if command -v greadlink >/dev/null 2>&1; then
        greadlink -f "$1"
    elif readlink -f "$1" 2>/dev/null; then
        readlink -f "$1"
    else
        # Fallback for BSD without -f
        python -c "import os; print(os.path.realpath('$1'))" 2>/dev/null || \
        perl -e "use Cwd 'abs_path'; print abs_path('$1')" 2>/dev/null || \
        echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
    fi
}

# =============================================================================
# stat compatibility
# =============================================================================

# Get file modification time (portable)
# Usage: stat_mtime file
stat_mtime() {
    if is_gnu; then
        stat -c "%Y" "$1"
    else
        stat -f "%m" "$1"
    fi
}

# Get file size (portable)
# Usage: stat_size file
stat_size() {
    if is_gnu; then
        stat -c "%s" "$1"
    else
        stat -f "%z" "$1"
    fi
}

# =============================================================================
# Other utilities
# =============================================================================

# Portable array join
# Usage: join_by "," "${array[@]}"
join_by() {
    local IFS="$1"
    shift
    echo "$*"
}

# Check command availability
# Usage: has_command "git"
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Get number of CPU cores (portable)
# Usage: cpu_count
cpu_count() {
    if is_gnu; then
        nproc 2>/dev/null || echo 1
    else
        sysctl -n hw.ncpu 2>/dev/null || echo 1
    fi
}

# =============================================================================
# Best Practices and Recommendations
# =============================================================================

# 1. Use POSIX-compliant syntax when possible:
#    - Use [ ] instead of [[ ]] for simple tests
#    - Use $(cmd) instead of `cmd`
#    - Avoid bash-specific features when not needed

# 2. For complex operations, consider using:
#    - perl (usually available on both platforms)
#    - python (if available)
#    - awk (very portable for text processing)

# 3. Test with both GNU and BSD tools:
#    - Install GNU coreutils on macOS: brew install coreutils
#    - Use Docker to test on different Linux distributions

# 4. Common pitfalls to avoid:
#    - echo -n (use printf instead)
#    - seq (use {1..10} or for loop)
#    - head -n -1 (not portable, use sed instead)

# Export all functions
export -f detect_os is_gnu sed_i sed_i_perl date_fmt days_ago
export -f mktemp_portable mktemp_dir grep_e grep_p find_regex
export -f readlink_f stat_mtime stat_size join_by has_command cpu_count