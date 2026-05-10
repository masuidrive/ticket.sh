#!/usr/bin/env bash

# Early bash check (POSIX compatible)
if [ -z "${BASH_VERSION}" ]; then
    echo "Error: This script requires bash. Please run with 'bash ticket.sh' or make sure bash is your default shell."
    echo "Current shell: $0"
    exit 1
fi

# IMPORTANT NOTE: This file is generated from source files. DO NOT EDIT DIRECTLY!
# To make changes, edit the source files in src/ directory and run ./build.sh
# Source file: src/ticket.sh

# ticket.sh - Git-based Ticket Management System for Development
# Version: 20260510.023854
# Built from source files
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
#   ./ticket.sh init          # Initialize in your project
#   ./ticket.sh new my-task   # Create a new ticket
#   ./ticket.sh start <name>  # Start working on a ticket
#   ./ticket.sh close         # Complete and merge ticket

set -euo pipefail

# === Inlined Libraries ===

# --- yaml-sh.sh ---

# yaml-sh: A simple YAML parser for Bash 3.2+
# Version: 2.0.0
# Usage: source yaml-sh.sh
#
# Supported YAML syntax:
# - Key-value pairs: key: value
# - Lists with dash notation: - item
# - Inline lists: [item1, item2, item3]
# - Multiline strings:
#   - Literal style (|): Preserves newlines
#   - Folded style (>): Converts newlines to spaces
#   - Strip modifier (-): Removes final newline
#   - Keep modifier (+): Keeps all trailing newlines
# - Quoted strings: 'single quotes' and "double quotes"
# - Comments: # comment (except in multiline strings)
# - Flat structure only (no nested objects support)
#
# Known limitations:
# - Pipe multiline strings (|): May lose the final newline
# - Folded strings (>): May lose the trailing space
# - No support for nested objects or complex data structures
# - No support for anchors, aliases, or tags
# - No support for flow style mappings
#
# API Functions:
# - yaml_parse <file>: Parse a YAML file
# - yaml_get <key>: Get value by key
# - yaml_keys: List all keys
# - yaml_has_key <key>: Check if key exists
# - yaml_list_size <prefix>: Get size of a list
# - yaml_load <file> [prefix]: Load YAML into environment variables
# - yaml_update <file> <key> <value>: Update a top-level single-line value

# Global variables to store parsed data
declare -a _YAML_KEYS
declare -a _YAML_VALUES
_YAML_CURRENT_FILE=""

# Simple AWK parser for YAML
_yaml_parse_awk() {
    awk '
    BEGIN {
        in_multiline = 0
        multiline_key = ""
        multiline_value = ""
        multiline_type = ""
        key_indent = 0
        multiline_base_indent = -1
    }
    
    {
        # Store original line
        original = $0
        
        # Get indent
        indent = 0
        if (match(original, /^[ ]+/)) {
            indent = RLENGTH
        }
        
        # Skip empty lines in normal mode
        if (!in_multiline && match(original, /^[ ]*$/)) {
            next
        }
        
        # Remove comments
        line = original
        if (!in_multiline) {
            sub(/[ ]*#.*$/, "", line)
        }
        
        # Trim trailing whitespace
        sub(/[ \t]+$/, "", line)
    }
    
    # In multiline mode
    in_multiline {
        # Check if this line belongs to multiline
        if (match(original, /^[ ]*$/) || indent > key_indent) {
            # Extract content preserving internal spacing
            if (length(original) > key_indent) {
                content = substr(original, key_indent + 1)
            } else {
                content = ""
            }
            
            # For first line, determine base indent
            if (multiline_base_indent == -1 && content != "") {
                if (match(content, /^[ ]+/)) {
                    multiline_base_indent = RLENGTH
                } else {
                    multiline_base_indent = 0
                }
            }
            
            # Strip base indent from content
            if (multiline_base_indent > 0 && length(content) >= multiline_base_indent) {
                content = substr(content, multiline_base_indent + 1)
            } else if (content == "") {
                # Keep empty lines
            } else {
                # Line with less indent than base - should not happen in valid YAML
                content = ""
            }
            
            # Add to multiline value
            if (multiline_value == "") {
                multiline_value = content
            } else {
                # For folded strings, replace newlines with spaces
                if (substr(multiline_type, 1, 1) == ">") {
                    # Empty line creates paragraph break
                    if (content == "") {
                        multiline_value = multiline_value "\n"
                    } else {
                        multiline_value = multiline_value " " content
                    }
                } else {
                    # Literal strings preserve newlines
                    multiline_value = multiline_value "\n" content
                }
            }
            next
        } else {
            # End of multiline - output value
            # For folded strings, process the folding
            if (substr(multiline_type, 1, 1) == ">") {
                # First, normalize spaces and newlines
                gsub(/ +\n/, "\n", multiline_value)
                gsub(/\n\n+/, "\n\n", multiline_value)
                # Remove leading spaces from folded strings
                gsub(/^ +/, "", multiline_value)
                # Add trailing space if the string doesn'\''t end with newline
                if (match(multiline_value, /\n$/)) {
                    # Has newline at end, keep as is
                } else {
                    multiline_value = multiline_value " "
                }
            }
            # Handle strip/keep modifiers
            if (multiline_type ~ /-$/) {
                # Strip final newline
                sub(/\n$/, "", multiline_value)
            } else if (multiline_type ~ /\+$/) {
                # Keep all trailing newlines (already in multiline_value)
            } else {
                # Default: keep single final newline
                # Ensure exactly one trailing newline
                sub(/\n*$/, "\n", multiline_value)
            }
            print "VALUE", key_indent, multiline_key, multiline_value
            in_multiline = 0
            multiline_value = ""
            multiline_base_indent = -1
            # Fall through to process current line
        }
    }
    
    # Empty line
    length(line) == 0 { next }
    
    # Process non-empty lines
    {
        # Get stripped line for processing
        stripped_line = line
        if (indent > 0) {
            stripped_line = substr(original, indent + 1)
        }
        
        # List item
        if (match(stripped_line, /^- /)) {
            item = substr(stripped_line, 3)
            gsub(/^[ \t]+|[ \t]+$/, "", item)
            print "LIST", indent, item
            next
        }
        
        # Key-value pair
        if (match(stripped_line, /^[^:]+:/)) {
            # Split key and value
            pos = index(stripped_line, ":")
            key = substr(stripped_line, 1, pos - 1)
            value = substr(stripped_line, pos + 1)
            gsub(/^[ \t]+|[ \t]+$/, "", value)
        
        # Check for multiline indicator
        if (value == "|" || value == "|-" || value == "|+" || value == ">" || value == ">-" || value == ">+") {
            multiline_type = value
            multiline_key = key
            key_indent = indent
            in_multiline = 1
            multiline_value = ""
            print "KEY", indent, key, ""
        }
        # Inline list
        else if (match(value, /^\[.*\]$/)) {
            print "KEY", indent, key, ""
            # Remove brackets
            value = substr(value, 2, length(value) - 2)
            # Split by comma
            n = split(value, items, ",")
            for (i = 1; i <= n; i++) {
                item = items[i]
                gsub(/^[ \t]+|[ \t]+$/, "", item)
                # Remove quotes if present
                if (match(item, /^["'\''].*["'\'']$/)) {
                    item = substr(item, 2, length(item) - 2)
                }
                print "ILIST", indent, item
            }
        }
        # Single/double quoted strings
        else if (match(value, /^'\''.*/)) {
            # Extract content between single quotes
            content = substr(value, 2)
            if (match(content, /'\''[^'\'']*$/)) {
                content = substr(content, 1, RSTART - 1)
            }
            print "KEY", indent, key, content
        }
        else if (match(value, /^".*/)) {
            # Extract content between double quotes
            content = substr(value, 2)
            if (match(content, /"[^"]*$/)) {
                content = substr(content, 1, RSTART - 1)
            }
            print "KEY", indent, key, content
        }
            # Regular value
            else {
                print "KEY", indent, key, value
            }
        }
    }
    
    END {
        # Output any remaining multiline
        if (in_multiline) {
            # Apply same processing as in main block
            if (substr(multiline_type, 1, 1) == ">") {
                gsub(/ +\n/, "\n", multiline_value)
                gsub(/\n\n+/, "\n\n", multiline_value)
                gsub(/^ +/, "", multiline_value)
                if (match(multiline_value, /\n$/)) {
                    # Has newline at end
                } else {
                    multiline_value = multiline_value " "
                }
            }
            # Handle strip/keep modifiers
            if (multiline_type ~ /-$/) {
                sub(/\n$/, "", multiline_value)
            } else if (multiline_type ~ /\+$/) {
                # Keep all trailing newlines
            } else {
                # Default: keep single final newline
                sub(/\n*$/, "\n", multiline_value)
            }
            print "VALUE", key_indent, multiline_key, multiline_value
        }
    }
    ' "$1"
}

# Main parsing function
yaml_parse() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi
    
    _YAML_CURRENT_FILE="$file"
    
    # Clear previous data
    _YAML_KEYS=()
    _YAML_VALUES=()
    
    local current_path=""
    local list_index=0
    local in_list=0
    
    local line
    local multiline_value=""
    local reading_multiline=0
    
    # Use temporary file to avoid process substitution (bash 3.2 compatibility)
    local temp_yaml_output="/tmp/yaml_parse_$$.tmp"
    _yaml_parse_awk "$file" > "$temp_yaml_output" 2>/dev/null || true
    
    # Ensure file exists and is not empty before processing
    if [[ ! -f "$temp_yaml_output" ]]; then
        echo "Error: Failed to create temporary YAML output" >&2
        return 1
    fi
    
    # Read line by line with explicit error handling for bash 5.1+ compatibility
    while IFS='' read -r line || [[ -n "$line" ]]; do
        # Remove CRLF line endings
        line=${line%$'\r'}
        if [[ $reading_multiline -eq 1 ]]; then
            # Check if this is the start of a new entry
            if [[ "$line" =~ ^(KEY|VALUE|LIST|ILIST) ]]; then
                # Save the completed multiline value
                _YAML_KEYS+=("$current_path")
                _YAML_VALUES+=("$multiline_value")
                reading_multiline=0
                multiline_value=""
            else
                # Continue reading multiline value
                if [[ -n "$multiline_value" ]]; then
                    multiline_value+=$'\n'"$line"
                else
                    multiline_value="$line"
                fi
                continue
            fi
        fi
        
        # Parse the line
        local type=$(echo "$line" | awk '{print $1}')
        local indent=$(echo "$line" | awk '{print $2}')
        local key=$(echo "$line" | awk '{print $3}')
        local value=$(echo "$line" | cut -d' ' -f4-)
        
        # For LIST/ILIST entries, key contains the full list item (may have spaces)
        if [[ "$type" == "LIST" ]] || [[ "$type" == "ILIST" ]]; then
            key=$(echo "$line" | cut -d' ' -f3-)
        fi
        
        case "$type" in
            KEY)
                # Only reset in_list if we're changing to a different key
                if [[ "$current_path" != "$key" ]]; then
                    in_list=0
                fi
                current_path="$key"
                if [[ -n "$value" ]]; then
                    _YAML_KEYS+=("$current_path")
                    _YAML_VALUES+=("$value")
                fi
                ;;
                
            VALUE)
                # Check if value continues on next lines
                if [[ -n "$value" ]]; then
                    multiline_value="$value"
                    reading_multiline=1
                else
                    _YAML_KEYS+=("$current_path")
                    _YAML_VALUES+=("")
                fi
                ;;
                
            LIST)
                if [[ $in_list -eq 0 ]]; then
                    list_index=0
                    in_list=1
                else
                    list_index=$((list_index + 1))
                fi
                _YAML_KEYS+=("${current_path}.${list_index}")
                _YAML_VALUES+=("$key")  # key contains the list item
                ;;
                
            ILIST)
                if [[ $in_list -eq 0 ]]; then
                    list_index=0
                    in_list=1
                else
                    list_index=$((list_index + 1))
                fi
                _YAML_KEYS+=("${current_path}.${list_index}")
                _YAML_VALUES+=("$key")  # key contains the list item
                ;;
        esac
    done < "$temp_yaml_output"
    
    # Clean up temporary file
    rm -f "$temp_yaml_output"
    
    # Handle last multiline value if any
    if [[ $reading_multiline -eq 1 ]]; then
        _YAML_KEYS+=("$current_path")
        _YAML_VALUES+=("$multiline_value")
    fi
    
    return 0
}

# Get a value by key
yaml_get() {
    local key="$1"
    local i=0
    local len=${#_YAML_KEYS[@]}
    
    while [[ $i -lt $len ]]; do
        if [[ "${_YAML_KEYS[$i]}" == "$key" ]]; then
            echo "${_YAML_VALUES[$i]}"
            return 0
        fi
        i=$((i + 1))
    done
    
    return 1
}

# List all keys
yaml_keys() {
    local i=0
    local len=${#_YAML_KEYS[@]}
    
    while [[ $i -lt $len ]]; do
        echo "${_YAML_KEYS[$i]}"
        i=$((i + 1))
    done
}

# Check if a key exists
yaml_has_key() {
    local key="$1"
    local i=0
    local len=${#_YAML_KEYS[@]}
    
    while [[ $i -lt $len ]]; do
        if [[ "${_YAML_KEYS[$i]}" == "$key" ]]; then
            return 0
        fi
        i=$((i + 1))
    done
    
    return 1
}

# Get the size of a list
yaml_list_size() {
    local prefix="$1"
    local count=0
    local i=0
    local len=${#_YAML_KEYS[@]}
    
    while [[ $i -lt $len ]]; do
        if [[ "${_YAML_KEYS[$i]}" =~ ^${prefix}\.([0-9]+)$ ]]; then
            local index="${BASH_REMATCH[1]}"
            if [[ $index -ge $count ]]; then
                count=$((index + 1))
            fi
        fi
        i=$((i + 1))
    done
    
    echo "$count"
}

# Load a YAML file with a prefix (variables are set in the caller's scope)
yaml_load() {
    local file="$1"
    local prefix="${2:-}"
    
    yaml_parse "$file" || return 1
    
    local i=0
    local len=${#_YAML_KEYS[@]}
    
    while [[ $i -lt $len ]]; do
        local key="${_YAML_KEYS[$i]}"
        local value="${_YAML_VALUES[$i]}"
        
        # Convert dots to underscores for valid variable names
        local var_name=$(echo "$key" | tr '.' '_')
        
        if [[ -n "$prefix" ]]; then
            var_name="${prefix}_${var_name}"
        fi
        
        # Export the variable in the caller's scope
        eval "export $var_name=\"\$value\""
        
        i=$((i + 1))
    done
    
    return 0
}

# Update a top-level single-line string value in a YAML file
# Only updates simple key: value pairs, preserves comments
yaml_update() {
    local file="$1"
    local key="$2"
    local new_value="$3"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi
    
    if [[ -z "$key" ]] || [[ -z "$new_value" ]]; then
        echo "Error: Key and value are required" >&2
        return 1
    fi
    
    # Create a temporary file
    local temp_file=$(mktemp)
    local found=0
    
    # Process the file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove CRLF line endings
        line=${line%$'\r'}
        # Check if this line contains the key we're looking for
        if [[ "$line" =~ ^[[:space:]]*${key}:[[:space:]]* ]]; then
            # Extract the value part after the colon
            local after_colon="${line#*:}"
            
            # Check for comment
            local comment=""
            local value_part="$after_colon"
            if [[ "$after_colon" =~ \# ]]; then
                # Split at the hash
                value_part="${after_colon%%#*}"
                comment=" #${after_colon#*#}"
            fi
            
            # Trim the value
            value_part="${value_part#"${value_part%%[![:space:]]*}"}"  # Trim leading
            value_part="${value_part%"${value_part##*[![:space:]]}"}"  # Trim trailing
            
            # Only update if it's not a multiline indicator or empty
            if [[ "$value_part" != "|" ]] && [[ "$value_part" != "|-" ]] && \
               [[ "$value_part" != "|+" ]] && [[ "$value_part" != ">" ]] && \
               [[ "$value_part" != ">-" ]] && [[ "$value_part" != ">+" ]] && \
               [[ -n "$value_part" ]]; then
                # Write the updated line
                echo "${key}: ${new_value}${comment}" >> "$temp_file"
                found=1
            else
                # Keep the original line for multiline or complex values
                echo "$line" >> "$temp_file"
            fi
        else
            # Keep the original line
            echo "$line" >> "$temp_file"
        fi
    done < "$file"
    
    if [[ $found -eq 1 ]]; then
        # Replace the original file
        mv "$temp_file" "$file"
        return 0
    else
        # Key not found or not updatable
        rm "$temp_file"
        echo "Error: Key '$key' not found or is not a simple value" >&2
        return 1
    fi
}
# --- yaml-frontmatter.sh ---

# Functions to handle YAML frontmatter in markdown files

# Update a field in YAML frontmatter using sed
# Usage: update_yaml_frontmatter_field <file> <field> <value>
update_yaml_frontmatter_field() {
    local file="$1"
    local field="$2"
    local value="$3"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi
    
    # Create temporary file
    local temp_file=$(mktemp)
    
    # State tracking
    local in_frontmatter=0
    local frontmatter_start=0
    local frontmatter_end=0
    local line_num=0
    local field_updated=0
    
    # First pass: find frontmatter boundaries
    while IFS= read -r line; do
        # Remove CRLF line endings
        line=${line%$'\r'}
        ((line_num++))
        
        if [[ $line_num -eq 1 ]] && [[ "$line" == "---" ]]; then
            frontmatter_start=1
            in_frontmatter=1
        elif [[ $in_frontmatter -eq 1 ]] && [[ "$line" == "---" ]]; then
            frontmatter_end=$line_num
            break
        fi
    done < "$file" || true
    
    if [[ $frontmatter_start -eq 0 ]] || [[ $frontmatter_end -eq 0 ]]; then
        echo "Error: No YAML frontmatter found in file" >&2
        rm "$temp_file"
        return 1
    fi
    
    # Second pass: update the field
    line_num=0
    in_frontmatter=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove CRLF line endings
        line=${line%$'\r'}
        ((line_num++))
        
        if [[ $line_num -eq 1 ]] && [[ "$line" == "---" ]]; then
            echo "$line" >> "$temp_file"
            in_frontmatter=1
        elif [[ $in_frontmatter -eq 1 ]] && [[ $line_num -eq $frontmatter_end ]]; then
            echo "$line" >> "$temp_file"
            in_frontmatter=0
        elif [[ $in_frontmatter -eq 1 ]]; then
            # Check if this line contains the field
            if [[ "$line" =~ ^[[:space:]]*${field}:[[:space:]]* ]]; then
                # Extract indentation
                local indent=""
                if [[ "$line" =~ ^([[:space:]]*) ]]; then
                    indent="${BASH_REMATCH[1]}"
                fi
                
                # Check for comment
                local comment=""
                local after_colon="${line#*:}"
                if [[ "$after_colon" =~ \# ]]; then
                    comment=" #${after_colon#*#}"
                fi
                
                # Write updated line
                echo "${indent}${field}: ${value}${comment}" >> "$temp_file"
                field_updated=1
            else
                echo "$line" >> "$temp_file"
            fi
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$file" || true
    
    if [[ $field_updated -eq 0 ]]; then
        echo "Error: Field '$field' not found in frontmatter" >&2
        rm "$temp_file"
        return 1
    fi
    
    # Check if the file is writable before replacing
    if [[ ! -w "$file" ]]; then
        echo "Error: File '$file' is not writable" >&2
        rm "$temp_file"
        return 1
    fi
    
    # Replace original file
    mv "$temp_file" "$file"
    return 0
}

# Extract YAML frontmatter from a markdown file
# Usage: extract_yaml_frontmatter <file>
extract_yaml_frontmatter() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi
    
    local in_frontmatter=0
    local line_num=0
    local content=""
    
    while IFS= read -r line; do
        # Remove CRLF line endings
        line=${line%$'\r'}
        ((line_num++))
        
        if [[ $line_num -eq 1 ]] && [[ "$line" == "---" ]]; then
            in_frontmatter=1
            continue
        elif [[ $in_frontmatter -eq 1 ]] && [[ "$line" == "---" ]]; then
            break
        elif [[ $in_frontmatter -eq 1 ]]; then
            content+="$line"$'\n'
        fi
    done < "$file"
    
    if [[ $in_frontmatter -eq 0 ]]; then
        echo "Error: No YAML frontmatter found" >&2
        return 1
    fi
    
    echo -n "$content"
}

# Extract markdown body (content after frontmatter)
# Usage: extract_markdown_body <file>
extract_markdown_body() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi
    
    local in_frontmatter=0
    local past_frontmatter=0
    local line_num=0
    local first_body_line=1
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove CRLF line endings
        line=${line%$'\r'}
        ((line_num++))
        
        if [[ $line_num -eq 1 ]] && [[ "$line" == "---" ]]; then
            in_frontmatter=1
        elif [[ $in_frontmatter -eq 1 ]] && [[ "$line" == "---" ]]; then
            in_frontmatter=0
            past_frontmatter=1
        elif [[ $past_frontmatter -eq 1 ]]; then
            if [[ $first_body_line -eq 1 ]]; then
                echo -n "$line"
                first_body_line=0
            else
                echo
                echo -n "$line"
            fi
        elif [[ $in_frontmatter -eq 0 ]] && [[ $line_num -eq 1 ]]; then
            # No frontmatter, output from first line
            echo -n "$line"
            past_frontmatter=1
            first_body_line=0
        fi
    done < "$file"
    
    # Add final newline if there was content
    if [[ $past_frontmatter -eq 1 ]] && [[ $first_body_line -eq 0 ]]; then
        echo
    fi
}
# --- utils.sh ---

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
# === Main Script ===


# Check if running with bash (POSIX compatible check)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script requires bash. Please run with 'bash ticket.sh' or make sure bash is your default shell."
    echo "Current shell: $0"
    exit 1
fi

# ticket.sh - Git-based Ticket Management System for Development
# Version: 20260510.023854
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


# Global variables
VERSION="20260510.023854"  # This will be replaced during build
CONFIG_FILE=""  # Will be set dynamically by get_config_file()
CURRENT_TICKET_LINK="current-ticket.md"
CURRENT_NOTE_LINK="current-note.md"

# Default configuration values
DEFAULT_TICKETS_DIR="tickets"
DEFAULT_BRANCH="main"
DEFAULT_BRANCH_PREFIX="feature/"
DEFAULT_REPOSITORY="origin"
DEFAULT_AUTO_PUSH="true"
DEFAULT_DELETE_REMOTE_ON_CLOSE="true"
DEFAULT_NEW_SUCCESS_MESSAGE=""
DEFAULT_START_SUCCESS_MESSAGE="Please review the ticket content in \`current-ticket.md\` and make any necessary adjustments before beginning work."
DEFAULT_RESTORE_SUCCESS_MESSAGE=""
DEFAULT_CLOSE_SUCCESS_MESSAGE=""
DEFAULT_WORKTREE_MODE="false"
DEFAULT_WORKTREE_DIR=""  # Empty means auto: ../<project-name>.worktrees
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
- \`$SCRIPT_COMMAND start [--worktree] <ticket-name>\` - Start working on ticket (creates or switches to feature branch, --worktree creates a separate worktree)
  - With \`--worktree\`: **cd to the worktree directory after start; cd back to the main repo after close.** In environments where cwd resets each command (e.g. LLM agents), cd must be re-run every time.
- \`$SCRIPT_COMMAND restore\` - Restore current-ticket.md symlink from branch name
- \`$SCRIPT_COMMAND check\` - Check current directory and ticket/branch synchronization status
- \`$SCRIPT_COMMAND close [--no-push] [--force|-f] [--no-delete-remote] [--keep-worktree] [--dry-run|-n]\` - Complete current ticket (squash merge to default branch)
  - \`--dry-run\` (\`-n\`) runs all preflight checks (clean working dir, branch, ticket state, base_branch existence, worktree main repo state) and exits before any commit/merge. Useful for catching format mistakes or stale state before the real close. Note: pre-commit hooks are NOT executed by --dry-run.
  - From a worktree, close refuses to merge if the main repo is on a non-default branch or has uncommitted changes (protects parallel workers).
  - **Coding agents (Claude Code / Codex / etc.) must pass \`--keep-worktree\`**: without it, the worker's worktree is deleted and the agent's shell cwd points to a removed directory → every subsequent Bash tool call fails.
- \`$SCRIPT_COMMAND cancel [--force|-f] [--keep-worktree]\` - Cancel current ticket (no merge, moves to done/ with CANCELED marker)
  - Same rule as close: coding agents should pass \`--keep-worktree\` to avoid dangling cwd.
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
- \`canceled\`: canceled (canceled_at set)

## YAML Frontmatter Fields

- \`base_branch\`: Override base branch for start/close per ticket (default: use default_branch from config)

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

## For Claude Code (and similar coding agents)

Claude Code's Bash tool resets cwd on each invocation, so any cd inside a
command evaporates by the next tool call. Combine ticket.sh's worktree
support with Claude Code's \`EnterWorktree\` to keep the session cwd pinned:

1. **Start in a worktree**: \`$SCRIPT_COMMAND start --worktree <ticket-name>\`
   - Output includes \`WORKTREE:<absolute-path>\`. Pin the session cwd to that
     path via \`EnterWorktree({ path: "<absolute-path>" })\`.
2. **Work inside the worktree** for the whole ticket. Do NOT run ticket.sh
   from the main repo — \`current-ticket.md\` only exists in the worktree.
3. **Always close with \`--keep-worktree\`**:
     \`$SCRIPT_COMMAND close --keep-worktree\`
   - Preserves the worktree so the cwd stays valid.
   - Without it, close removes the worktree and the next Bash tool call
     returns "Working directory no longer exists" → session hangs.
4. **Cancel also uses \`--keep-worktree\`**: same reason.
5. **Parallel multi-worktree**: each agent runs in its own worktree. Keep
   the main repo on the default branch (don't check out other branches
   there); close refuses if main repo HEAD has drifted, to protect the
   other workers.
6. After close, exit the worktree with \`ExitWorktree\` and pick up the
   next ticket with a fresh \`start --worktree\`.

**TL;DR for agents**: \`start --worktree\` → pin cwd → \`close --keep-worktree\`.

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

# Worktree mode: create a separate git worktree for each ticket
# When true, 'start' always creates a worktree (same as --worktree flag)
# worktree_mode: false
# worktree_dir: ""  # Custom worktree directory (default: ../<project>.worktrees/)

# Success messages (leave empty to disable)
# Message displayed after creating a new ticket
new_success_message: |
  
# Message displayed after starting work on a ticket
start_success_message: |
  Please review the ticket content in \`current-ticket.md\` and make any necessary adjustments before beginning work.

# Message displayed after restoring current ticket link
restore_success_message: |
  
# Message displayed after closing a ticket
close_success_message: |
  

# Note template (optional - if not defined, no note file will be created)
note_content: |
  # Work Notes for \$\$TICKET_NAME\$\$
  
  ## Implementation Details
  
  ...

  ## Task 1
  
  ...

  ## Task N
  
  ...
  
  
  ## Reviewer note #N
  
  ...
  

# Ticket template
default_content: |
  # Ticket Overview
  
  Write the overview and tasks for this ticket here.

  Please record any notes related to this ticket, such as debugging information, review results, or other work logs, \`\$\$NOTE_PATH\$\$\`.


  ## Tasks
  
  - [ ] Task 1
  - [ ] Task 2
  ...
  - [ ] Run tests before closing and pass all tests (No exceptions)
  - [ ] Run \`bash build.sh\` to build the project
  - [ ] Update documentation if necessary
    - [ ] Update README.*.md
    - [ ] Update spec.*.md
    - [ ] Update DEV.md
  - [ ] Get developer approval before closing
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
\`\`\`bash
$SCRIPT_COMMAND help
\`\`\`

For a list of all available commands:
\`\`\`bash
$SCRIPT_COMMAND --help
\`\`\`
EOF
        echo "Created README file: $readme_file"
    else
        echo "README file already exists: $readme_file"
    fi
    
    # Update .gitignore
    if [[ ! -f .gitignore ]]; then
        echo "$CURRENT_TICKET_LINK" > .gitignore
        echo "$CURRENT_NOTE_LINK" >> .gitignore
        echo "Created .gitignore with: $CURRENT_TICKET_LINK and $CURRENT_NOTE_LINK"
    else
        if ! grep -q "^${CURRENT_TICKET_LINK}$" .gitignore; then
            echo "$CURRENT_TICKET_LINK" >> .gitignore
            echo "Added to .gitignore: $CURRENT_TICKET_LINK"
        else
            echo ".gitignore already contains: $CURRENT_TICKET_LINK"
        fi
        if ! grep -q "^${CURRENT_NOTE_LINK}$" .gitignore; then
            echo "$CURRENT_NOTE_LINK" >> .gitignore
            echo "Added to .gitignore: $CURRENT_NOTE_LINK"
        else
            echo ".gitignore already contains: $CURRENT_NOTE_LINK"
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
    echo "### If \`current-ticket.md\` exists in project root"
    echo ""
    echo "- This file is your work instruction - follow its contents"
    echo "- When receiving additional instructions from users, add them as new tasks under \`## Tasks\` and record details in \`current-note.md\` before proceeding"
    echo "- During the work, also write down notes, logs, and findings in \`current-note.md\`"
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
    echo "3. Develop on feature branch"
    echo "4. Reference work files:"
    echo "   - \`current-ticket.md\` shows active ticket with tasks"
    echo "   - \`current-note.md\` for working notes related to this ticket (if used)"
    echo ""
    echo "## Closing Tickets"
    echo ""
    echo "1. Before closing:"
    echo "   - Review \`current-ticket.md\` content and description, collect information from \`current-note.md\` and other notes, and summarize the final work results and conclusions so that anyone reading the ticket can understand the work done on this branch"
    echo "   - Check all tasks in checklist are completed (mark with \`[x]\`)"
    echo "   - Commit all your work: \`git add . && git commit -m \"your message\"\`"
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
    local slug=""
    local epic_slug=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --epic)
                epic_slug="$2"; shift 2 ;;
            --*)
                echo "Error: Unknown option: $1" >&2
                return 1 ;;
            *)
                if [[ -z "$slug" ]]; then slug="$1"; else echo "Error: Unexpected argument: $1" >&2; return 1; fi
                shift ;;
        esac
    done

    if [[ -z "$slug" ]]; then
        echo "Error: slug required" >&2
        echo "Usage: $SCRIPT_COMMAND new <slug> [--epic <epic-slug>]" >&2
        return 1
    fi

    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1

    # Validate slug
    validate_slug "$slug" || return 1

    # If --epic provided, resolve epic and pin epic_id + base_branch
    local epic_id_value="" epic_base_branch=""
    if [[ -n "$epic_slug" ]]; then
        validate_epic_slug "$epic_slug" || return 3
        if ! resolve_epic "$epic_slug"; then
            echo "Error: Epic '$epic_slug' not found" >&2
            return 1
        fi
        local _efm
        _efm=$(epic_extract_frontmatter "$EPIC_RAW")
        local _eclosed _ecancelled
        _eclosed=$(get_yaml_field "$_efm" "closed_at"); [[ "$_eclosed" == "null" ]] && _eclosed=""
        _ecancelled=$(get_yaml_field "$_efm" "cancelled_at"); [[ "$_ecancelled" == "null" ]] && _ecancelled=""
        if [[ -n "$_eclosed" ]] || [[ -n "$_ecancelled" ]]; then
            echo "Error: Epic '$epic_slug' is already closed or cancelled" >&2
            return 2
        fi
        epic_id_value="$epic_slug"
        epic_base_branch=$(get_yaml_field "$_efm" "branch")
        [[ -z "$epic_base_branch" ]] && epic_base_branch="main"
    fi
    
    # Load configuration
    if ! yaml_parse "$CONFIG_FILE"; then
        echo "Error: Cannot parse configuration file: $CONFIG_FILE" >&2
        echo "Configuration file may be corrupted or unreadable" >&2
        return 1
    fi
    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    local default_content=$(yaml_get "default_content" || echo "$DEFAULT_CONTENT")
    local note_content=$(yaml_get "note_content" || echo "")
    local new_success_message=$(yaml_get "new_success_message" || echo "$DEFAULT_NEW_SUCCESS_MESSAGE")
    
    # Generate filename
    local ticket_name=$(generate_ticket_filename "$slug")
    local ticket_file="${tickets_dir}/${ticket_name}.md"
    local note_file="${tickets_dir}/${ticket_name}-note.md"
    
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
    
    # Check if note file already exists (when note_content is defined)
    if [[ -n "$note_content" ]] && [[ -f "$note_file" ]]; then
        cat >&2 << EOF
Error: Note file already exists
File '$note_file' already exists. Please:
1. Use a different slug name, or
2. Remove the existing file if it's no longer needed
EOF
        return 1
    fi
    
    # Process placeholders in default_content
    local processed_content="$default_content"
    if [[ -n "$note_content" ]]; then
        # Replace $$NOTE_PATH$$ with relative path to note file
        local note_path="${ticket_name}-note.md"
        processed_content="${processed_content//\$\$NOTE_PATH\$\$/$note_path}"
    else
        # Remove $$NOTE_PATH$$ placeholder if no note file
        processed_content="${processed_content//\$\$NOTE_PATH\$\$/}"
    fi
    
    # Replace $$TICKET_NAME$$ in both contents
    processed_content="${processed_content//\$\$TICKET_NAME\$\$/$ticket_name}"
    if [[ -n "$note_content" ]]; then
        note_content="${note_content//\$\$TICKET_NAME\$\$/$ticket_name}"
    fi
    
    # Create ticket file
    local timestamp=$(get_utc_timestamp)
    local _base_line="base_branch: default  # Override base branch for start/close (default: use default_branch from config)"
    local _epic_line=""
    if [[ -n "$epic_id_value" ]]; then
        _base_line="base_branch: ${epic_base_branch}"
        _epic_line=$'\n'"epic_id: ${epic_id_value}"
    fi
    if ! cat > "$ticket_file" << EOF
---
priority: 2
${_base_line}${_epic_line}
description: ""
created_at: "$timestamp"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

$processed_content
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
    if [[ -n "$epic_id_value" ]]; then
        echo "epic_id: $epic_id_value"
    fi

    # Create note file if note_content is defined
    if [[ -n "$note_content" ]]; then
        if ! cat > "$note_file" << EOF
$note_content
EOF
        then
            cat >&2 << EOF
Error: Permission denied
Cannot create note file '$note_file'. Please:
1. Check write permissions in tickets directory, or
2. Run with appropriate permissions
EOF
            # Clean up ticket file since note creation failed
            rm -f "$ticket_file"
            return 1
        fi
        echo "Created note file: $note_file"
    fi
    
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
                if [[ ! "$filter_status" =~ ^(todo|doing|done|canceled)$ ]]; then
                    cat >&2 << EOF
Error: Invalid status
Status '$filter_status' is not valid. Please use one of:
- todo (for unstarted tickets)
- doing (for in-progress tickets)
- done (for completed tickets)
- canceled (for canceled tickets)
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
    if ! yaml_parse "$CONFIG_FILE"; then
        echo "Error: Cannot parse configuration file: $CONFIG_FILE" >&2
        echo "Configuration file may be corrupted or unreadable" >&2
        return 1
    fi
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
    elif [[ "$filter_status" == "canceled" ]]; then
        echo "(sorted by canceled date, newest first)"
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
        local canceled_at=$(yaml_get "canceled_at" 2>/dev/null || echo "null")

        # Determine status
        local status=$(get_ticket_status "$started_at" "$closed_at" "$canceled_at")

        # Apply filter
        if [[ -n "$filter_status" ]] && [[ "$status" != "$filter_status" ]]; then
            continue
        fi

        # Default filter: show only todo and doing
        if [[ -z "$filter_status" ]] && [[ "$status" == "done" || "$status" == "canceled" ]]; then
            continue
        fi
        
        # Get relative path from project root
        local ticket_path="${ticket_file#./}"
        
        # Store in temp file for sorting
        # Format: status|priority|ticket_path|description|created_at|started_at|closed_at|canceled_at
        echo "${status}|${priority}|${ticket_path}|${description}|${created_at}|${started_at}|${closed_at}|${canceled_at}" >> "$temp_file"
    done
    
    # Sort and display
    # Sort by: status (doing first, then todo, then done), then by priority
    # For done tickets, sort by closed_at in descending order (most recent first)
    local sorted_file=$(mktemp)
    if [[ "$filter_status" == "done" ]]; then
        # For done tickets only: sort by closed_at in descending order
        sort -t'|' -k7,7r "$temp_file" > "$sorted_file"
    elif [[ "$filter_status" == "canceled" ]]; then
        # For canceled tickets only: sort by canceled_at in descending order
        sort -t'|' -k8,8r "$temp_file" > "$sorted_file"
    else
        # For all tickets or other statuses: use original sorting logic
        sort -t'|' -k1,1 -k2,2n "$temp_file" | sed 's/^doing|/0|/; s/^todo|/1|/; s/^done|/2|/; s/^canceled|/3|/' | sort -t'|' -k1,1n -k2,2n | sed 's/^0|/doing|/; s/^1|/todo|/; s/^2|/done|/; s/^3|/canceled|/' > "$sorted_file"
    fi

    while IFS='|' read -r status priority ticket_path description created_at started_at closed_at canceled_at; do
        [[ $displayed -ge $count ]] && break

        # Convert timestamps to local timezone
        local created_at_local=$(convert_utc_to_local "$created_at")
        local started_at_local=$(convert_utc_to_local "$started_at")
        local closed_at_local=$(convert_utc_to_local "$closed_at")
        local canceled_at_local=$(convert_utc_to_local "$canceled_at")

        echo "- status: $status"
        echo "  ticket_path: $ticket_path"
        [[ -n "$description" ]] && echo "  description: $description"
        echo "  priority: $priority"
        echo "  created_at: $created_at_local"
        [[ "$status" != "todo" ]] && echo "  started_at: $started_at_local"
        [[ "$status" == "done" ]] && [[ "$closed_at" != "null" ]] && echo "  closed_at: $closed_at_local"
        [[ "$status" == "canceled" ]] && [[ "$canceled_at" != "null" ]] && echo "  canceled_at: $canceled_at_local"

        # Show worktree info for doing tickets
        if [[ "$status" == "doing" ]]; then
            local _ticket_basename=$(basename "$ticket_path" .md)
            local _branch_prefix=$(yaml_get "branch_prefix" || echo "$DEFAULT_BRANCH_PREFIX")
            local _branch="${_branch_prefix}${_ticket_basename}"
            local _wt_path=$(git worktree list --porcelain 2>/dev/null | awk -v branch="branch refs/heads/$_branch" '/^worktree /{wt=$0} $0==branch{print wt}' | sed 's/^worktree //')
            if [[ -n "$_wt_path" ]]; then
                echo "  worktree: $_wt_path"
            fi
        fi
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
    local use_worktree=false
    local ticket_input=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --worktree)
                use_worktree=true
                shift
                ;;
            -*)
                # Ignore unknown flags for backward compatibility
                shift
                ;;
            *)
                if [[ -z "$ticket_input" ]]; then
                    ticket_input="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$ticket_input" ]]; then
        echo "Error: ticket name required" >&2
        echo "Usage: $SCRIPT_COMMAND start [--worktree] <ticket-name>" >&2
        return 1
    fi

    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1

    # Load configuration
    if ! yaml_parse "$CONFIG_FILE"; then
        echo "Error: Cannot parse configuration file: $CONFIG_FILE" >&2
        echo "Configuration file may be corrupted or unreadable" >&2
        return 1
    fi
    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    local default_branch=$(yaml_get "default_branch" || echo "$DEFAULT_BRANCH")
    local branch_prefix=$(yaml_get "branch_prefix" || echo "$DEFAULT_BRANCH_PREFIX")
    local repository=$(yaml_get "repository" || echo "$DEFAULT_REPOSITORY")
    local auto_push=$(yaml_get "auto_push" || echo "$DEFAULT_AUTO_PUSH")
    local start_success_message=$(yaml_get "start_success_message" || echo "$DEFAULT_START_SUCCESS_MESSAGE")

    # Check if worktree mode is enabled by config
    local worktree_mode=$(yaml_get "worktree_mode" || echo "$DEFAULT_WORKTREE_MODE")
    if [[ "$worktree_mode" == "true" ]]; then
        use_worktree=true
    fi
    local worktree_dir=$(yaml_get "worktree_dir" || echo "$DEFAULT_WORKTREE_DIR")

    # Get ticket file path early to determine base_branch before switching branches
    local ticket_name=$(extract_ticket_name "$ticket_input")
    local ticket_file=$(get_ticket_file "$ticket_name" "$tickets_dir")

    # Determine effective base branch (base_branch from ticket, or default_branch)
    local effective_base="$default_branch"
    if [[ -f "$ticket_file" ]]; then
        local _yaml_content=$(extract_yaml_frontmatter "$ticket_file")
        echo "$_yaml_content" >| /tmp/ticket_yaml_early.yml
        yaml_parse /tmp/ticket_yaml_early.yml
        local _base_branch=$(yaml_get "base_branch" || echo "")
        # Backward compatibility: fall back to merge_to if base_branch is not set
        if is_null_or_empty "$_base_branch" || [[ "$(echo "$_base_branch" | tr '[:upper:]' '[:lower:]')" == "default" ]]; then
            _base_branch=$(yaml_get "merge_to" || echo "default")
        fi
        rm -f /tmp/ticket_yaml_early.yml

        local _base_lower=$(echo "$_base_branch" | tr '[:upper:]' '[:lower:]')
        if ! is_null_or_empty "$_base_branch" && [[ "$_base_lower" != "default" ]]; then
            if git rev-parse --verify "$_base_branch" >/dev/null 2>&1; then
                effective_base="$_base_branch"
            fi
        fi
    fi

    # Check current branch
    local current_branch=$(get_current_branch)
    if [[ "$current_branch" != "$effective_base" ]]; then
        # We're not on the effective base branch - handle different scenarios
        local git_status_output
        if ! git_status_output=$(git status --porcelain 2>&1); then
            echo "Error: Failed to check git status" >&2
            echo "Git repository may be corrupted or inaccessible" >&2
            return 1
        fi
        if [[ -n "$git_status_output" ]]; then
            # Branch with uncommitted changes - prompt for commit and exit
            cat >&2 << EOF
Error: Uncommitted changes on feature branch
You are on feature branch '$current_branch' with uncommitted changes. Please:
1. Commit your changes: git add . && git commit -m "message"
2. Or stash changes: git stash
3. Then retry starting the new ticket
EOF
            return 1
        else
            # No uncommitted changes - switch to effective base branch
            echo "Warning: Currently on branch '$current_branch' with no uncommitted changes."
            echo "Creating new feature branch from '$effective_base' branch instead."

            # Switch to effective base branch first
            echo "Switching to '$effective_base' branch..."
            run_git_command "git checkout $effective_base" || return 1

            # Check if effective base branch has differences with the branch we were on
            local diff_count
            if ! diff_count=$(git rev-list --count "$current_branch..$effective_base" 2>&1); then
                echo "Warning: Cannot compare branches - using git log instead" >&2
                # Fallback to simpler check if rev-list fails
                diff_count="0"
            fi
            if [[ "$diff_count" -gt 0 ]]; then
                cat << EOF

Note: The branch '$effective_base' has $diff_count new commit(s) compared to branch '$current_branch'.
Consider merging or rebasing '$current_branch' to incorporate these changes:
  git checkout $current_branch
  git merge $effective_base
  # or
  git rebase $effective_base

EOF
            fi
        fi
    else
        # We're on the effective base branch - check for clean working directory
        check_clean_working_dir "$tickets_dir" || return 1
    fi

    # Check if ticket exists (after potential branch switch)
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

    # Determine worktree path if using worktree mode
    local wt_path=""
    if [[ "$use_worktree" == "true" ]]; then
        local project_root=$(git rev-parse --show-toplevel)
        local project_name=$(basename "$project_root")
        if [[ -n "$worktree_dir" ]]; then
            wt_path="${worktree_dir}/${ticket_name}"
        else
            wt_path="${project_root}/../${project_name}.worktrees/${ticket_name}"
        fi
        # Normalize path
        wt_path=$(cd "$(dirname "$wt_path")" 2>/dev/null && echo "$(pwd)/$(basename "$wt_path")" || echo "$wt_path")
    fi

    # Check if branch is already checked out in another worktree
    # This prevents worktree metadata corruption, especially in Docker/devcontainer environments
    local worktree_using_branch=$(git worktree list --porcelain 2>/dev/null | awk -v branch="branch refs/heads/$branch_name" '/^worktree /{wt=$0} $0==branch{print wt}' | sed 's/^worktree //')
    if [[ -n "$worktree_using_branch" ]]; then
        local current_toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
        # It's OK if the current directory IS the worktree that has this branch
        if [[ "$worktree_using_branch" != "$current_toplevel" ]]; then
            if [[ "$use_worktree" == "true" ]]; then
                # Worktree mode: reuse the existing worktree
                echo "Branch '$branch_name' is already checked out in worktree: $worktree_using_branch"
                wt_path="$worktree_using_branch"
            else
                cat >&2 << EOF
Error: Branch already checked out in worktree
Branch '$branch_name' is already checked out in another worktree at:
  $worktree_using_branch

You cannot checkout this branch here. Please either:
1. Work in the existing worktree: cd $worktree_using_branch
2. Use worktree mode: $SCRIPT_COMMAND start --worktree $ticket_input
3. Remove the worktree first: git worktree remove $worktree_using_branch

WARNING: Do NOT run 'git worktree prune' - it may destroy worktree metadata
and break all active worktrees.
EOF
                return 1
            fi
        fi
    fi

    # Check if branch already exists
    local branch_exists_check
    if branch_exists_check=$(git show-ref --verify "refs/heads/$branch_name" 2>&1); then
        # Branch exists - resume work
        echo "Branch '$branch_name' already exists. Resuming work on existing ticket..."

        if [[ "$use_worktree" == "true" ]]; then
            # Check if worktree already exists for this branch (may already be set above)
            local existing_wt=$(git worktree list --porcelain 2>/dev/null | awk -v branch="branch refs/heads/$branch_name" '/^worktree /{wt=$0} $0==branch{print wt}' | sed 's/^worktree //')
            if [[ -n "$existing_wt" ]]; then
                echo "Worktree already exists at: $existing_wt"
                wt_path="$existing_wt"
            else
                # Create worktree for existing branch
                if [[ -d "$wt_path" ]]; then
                    echo "Error: Directory '$wt_path' already exists but is not a worktree for this branch" >&2
                    return 1
                fi
                mkdir -p "$(dirname "$wt_path")"
                run_git_command "git worktree add $wt_path $branch_name" || return 1
            fi
        else
            # Checkout existing branch (original behavior)
            run_git_command "git checkout $branch_name" || return 1
        fi

        # Check if there are differences between this feature branch and the effective base branch
        local ahead_count behind_count
        if ! ahead_count=$(git rev-list --count "$effective_base..$branch_name" 2>&1); then
            echo "Warning: Cannot determine if feature branch is ahead of base branch" >&2
            ahead_count="0"
        fi
        if ! behind_count=$(git rev-list --count "$branch_name..$effective_base" 2>&1); then
            echo "Warning: Cannot determine if feature branch is behind base branch" >&2
            behind_count="0"
        fi

        if [[ "$behind_count" -gt 0 ]]; then
            cat << EOF

Warning: Feature branch '$branch_name' is $behind_count commit(s) behind '$effective_base'.
Consider updating your feature branch to incorporate recent changes:
  git merge $effective_base
  # or
  git rebase $effective_base

EOF
        fi

        if [[ "$ahead_count" -gt 0 ]]; then
            echo "Feature branch '$branch_name' is $ahead_count commit(s) ahead of '$effective_base'."
        fi

        # Determine target directory for symlinks
        local link_dir="."
        if [[ "$use_worktree" == "true" ]]; then
            link_dir="$wt_path"
        fi

        # Create symlink (restore functionality)
        rm -f "${link_dir}/$CURRENT_TICKET_LINK"
        if ! ln -s "$ticket_file" "${link_dir}/$CURRENT_TICKET_LINK"; then
            echo "Error: Cannot create symlink $CURRENT_TICKET_LINK" >&2
            echo "Permission denied or filesystem issue" >&2
            return 1
        fi

        # Create note symlink if note file exists
        local note_file="${tickets_dir}/${ticket_name}-note.md"
        if [[ -f "${link_dir}/${note_file}" ]]; then
            rm -f "${link_dir}/$CURRENT_NOTE_LINK"
            if ! ln -s "$note_file" "${link_dir}/$CURRENT_NOTE_LINK"; then
                echo "Warning: Cannot create note symlink $CURRENT_NOTE_LINK" >&2
            fi
            echo "Resumed ticket: $ticket_name"
            echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
            echo "Current note linked: $CURRENT_NOTE_LINK -> $note_file"
        else
            rm -f "${link_dir}/$CURRENT_NOTE_LINK"
            echo "Resumed ticket: $ticket_name"
            echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
        fi
        echo "Continuing work on existing feature branch."

        if [[ "$use_worktree" == "true" ]]; then
            echo "Worktree: $wt_path"
            echo "WORKTREE:${wt_path}"
            echo ""
            echo "CAUTION: All subsequent commands must run in the worktree directory."
            echo "  cd $wt_path"
            echo ""
            echo "When opening sub-shells, sub-agents, or new terminals, cd to the same path first."
            echo "Working in the main repo will miss current-ticket.md and may cause context confusion."
        fi

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

    # Use effective_base (already determined above from ticket's base_branch)
    local start_from="$effective_base"

    if [[ "$use_worktree" == "true" ]]; then
        # Create worktree with new branch
        mkdir -p "$(dirname "$wt_path")"
        run_git_command "git worktree add -b $branch_name $wt_path $start_from" || return 1

        # If base_branch differs from where ticket was created, bring ticket files over
        local prev_branch=$(get_current_branch)
        if [[ "$start_from" != "$prev_branch" ]]; then
            # In worktree context, use git show to copy files
            git -C "$wt_path" checkout "$prev_branch" -- "$ticket_file" 2>/dev/null || true
            local note_file="${tickets_dir}/${ticket_name}-note.md"
            git -C "$wt_path" checkout "$prev_branch" -- "$note_file" 2>/dev/null || true
            git -C "$wt_path" checkout "$prev_branch" -- "${tickets_dir}/README.md" 2>/dev/null || true
        fi

        # Update ticket started_at in worktree
        local timestamp=$(get_utc_timestamp)
        update_yaml_frontmatter_field "${wt_path}/${ticket_file}" "started_at" "$timestamp"

        # Create symlinks in worktree directory
        rm -f "${wt_path}/$CURRENT_TICKET_LINK"
        if ! ln -s "$ticket_file" "${wt_path}/$CURRENT_TICKET_LINK"; then
            echo "Error: Cannot create symlink $CURRENT_TICKET_LINK" >&2
            return 1
        fi

        local note_file="${tickets_dir}/${ticket_name}-note.md"
        if [[ -f "${wt_path}/${note_file}" ]]; then
            rm -f "${wt_path}/$CURRENT_NOTE_LINK"
            if ! ln -s "$note_file" "${wt_path}/$CURRENT_NOTE_LINK"; then
                echo "Warning: Cannot create note symlink $CURRENT_NOTE_LINK" >&2
            fi
            echo "Started ticket: $ticket_name"
            echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
            echo "Current note linked: $CURRENT_NOTE_LINK -> $note_file"
        else
            rm -f "${wt_path}/$CURRENT_NOTE_LINK"
            echo "Started ticket: $ticket_name"
            echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
        fi
        echo "Worktree created: $wt_path"
        echo "WORKTREE:${wt_path}"
        echo "Note: Branch created locally. Use 'git push -u $repository $branch_name' when ready to share."
        echo ""
        echo "CAUTION: All subsequent commands must run in the worktree directory."
        echo "  cd $wt_path"
        echo ""
        echo "When opening sub-shells, sub-agents, or new terminals, cd to the same path first."
        echo "Working in the main repo will miss current-ticket.md and may cause context confusion."
    else
        # Create and checkout new branch from base branch (original behavior)
        local prev_branch=$(get_current_branch)
        run_git_command "git checkout -b $branch_name $start_from" || return 1

        # If base_branch differs from where ticket was created, bring ticket files over
        if [[ "$start_from" != "$prev_branch" ]]; then
            run_git_command "git checkout $prev_branch -- $ticket_file" || {
                echo "Error: Failed to retrieve ticket file from $prev_branch" >&2
                return 1
            }
            local note_file="${tickets_dir}/${ticket_name}-note.md"
            git checkout "$prev_branch" -- "$note_file" 2>/dev/null || true
            run_git_command "git checkout $prev_branch -- ${tickets_dir}/README.md" 2>/dev/null || true
        fi

        # Update ticket started_at
        local timestamp=$(get_utc_timestamp)
        update_yaml_frontmatter_field "$ticket_file" "started_at" "$timestamp"

        # Create symlink
        rm -f "$CURRENT_TICKET_LINK"
        if ! ln -s "$ticket_file" "$CURRENT_TICKET_LINK"; then
            echo "Error: Cannot create symlink $CURRENT_TICKET_LINK" >&2
            echo "Permission denied or filesystem issue" >&2
            return 1
        fi

        # Create note symlink if note file exists
        local note_file="${tickets_dir}/${ticket_name}-note.md"
        if [[ -f "$note_file" ]]; then
            rm -f "$CURRENT_NOTE_LINK"
            if ! ln -s "$note_file" "$CURRENT_NOTE_LINK"; then
                echo "Warning: Cannot create note symlink $CURRENT_NOTE_LINK" >&2
            fi
            echo "Started ticket: $ticket_name"
            echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
            echo "Current note linked: $CURRENT_NOTE_LINK -> $note_file"
        else
            rm -f "$CURRENT_NOTE_LINK"
            echo "Started ticket: $ticket_name"
            echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
        fi
        echo "Note: Branch created locally. Use 'git push -u $repository $branch_name' when ready to share."
    fi

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
    if ! yaml_parse "$CONFIG_FILE"; then
        echo "Error: Cannot parse configuration file: $CONFIG_FILE" >&2
        echo "Configuration file may be corrupted or unreadable" >&2
        return 1
    fi
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
    
    # Restore note symlink if note file exists
    local note_file_regular="${tickets_dir}/${ticket_name}-note.md"
    local note_file_done="${tickets_dir}/done/${ticket_name}-note.md"
    local note_file=""
    
    if [[ -f "$note_file_regular" ]]; then
        note_file="$note_file_regular"
    elif [[ -f "$note_file_done" ]]; then
        note_file="$note_file_done"
    fi
    
    if [[ -n "$note_file" ]] && [[ -f "$note_file" ]]; then
        rm -f "$CURRENT_NOTE_LINK"
        if ! ln -s "$note_file" "$CURRENT_NOTE_LINK"; then
            echo "Warning: Cannot create note symlink $CURRENT_NOTE_LINK" >&2
            # Continue execution - note link is not critical
        fi
        echo "Restored current ticket link: $CURRENT_TICKET_LINK -> $ticket_file"
        echo "Restored current note link: $CURRENT_NOTE_LINK -> $note_file"
    else
        rm -f "$CURRENT_NOTE_LINK"  # Clean up any old note link
        echo "Restored current ticket link: $CURRENT_TICKET_LINK -> $ticket_file"
    fi
    
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
    if ! yaml_parse "$CONFIG_FILE"; then
        echo "Error: Cannot parse configuration file: $CONFIG_FILE" >&2
        echo "Configuration file may be corrupted or unreadable" >&2
        return 1
    fi
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
                        echo "Error: Cannot create symlink $CURRENT_TICKET_LINK" >&2
                        echo "Permission denied or filesystem issue" >&2
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
                            echo "Error: Cannot create symlink $CURRENT_TICKET_LINK" >&2
                            echo "Permission denied or filesystem issue" >&2
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
    local keep_worktree=false
    local dry_run=false

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
            --keep-worktree)
                keep_worktree=true
                shift
                ;;
            --dry-run|-n)
                dry_run=true
                shift
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                echo "Usage: $SCRIPT_COMMAND close [--no-push] [--force|-f] [--no-delete-remote] [--keep-worktree] [--dry-run|-n]" >&2
                return 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1

    # Check clean working directory unless --force is used
    if [[ "$force" == "false" ]]; then
        # Parse config to get tickets_dir for smarter error messages
        local _close_tickets_dir="$DEFAULT_TICKETS_DIR"
        if yaml_parse "$CONFIG_FILE" 2>/dev/null; then
            _close_tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
        fi
        if ! check_clean_working_dir "$_close_tickets_dir"; then
            cat >&2 << EOF

To ignore uncommitted changes and force close, use:
  $SCRIPT_COMMAND close --force (or -f)
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
    if ! yaml_parse "$CONFIG_FILE"; then
        echo "Error: Cannot parse configuration file: $CONFIG_FILE" >&2
        echo "Configuration file may be corrupted or unreadable" >&2
        return 1
    fi
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
    local base_branch=$(yaml_get "base_branch" || echo "")
    # Backward compatibility: fall back to merge_to if base_branch is not set
    if is_null_or_empty "$base_branch" || [[ "$(echo "$base_branch" | tr '[:upper:]' '[:lower:]')" == "default" ]]; then
        base_branch=$(yaml_get "merge_to" || echo "default")
    fi
    rm -f /tmp/ticket_yaml.yml

    # Override default_branch if base_branch is specified in ticket
    local base_branch_lower=$(echo "$base_branch" | tr '[:upper:]' '[:lower:]')
    if ! is_null_or_empty "$base_branch" && [[ "$base_branch_lower" != "default" ]]; then
        # Verify base_branch exists
        if ! git rev-parse --verify "$base_branch" >/dev/null 2>&1; then
            echo "Error: base_branch '$base_branch' does not exist" >&2
            echo "Please create the branch first or update the base_branch field in the ticket" >&2
            return 1
        fi
        default_branch="$base_branch"
    fi
    
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

    # Detect worktree mode and validate main repo state early, before we
    # mutate any ticket files. If main_repo is off default_branch or dirty,
    # we must abort so a concurrent worker's state is not clobbered.
    local in_worktree=false
    local worktree_path=""
    local main_repo=""
    if is_git_worktree; then
        in_worktree=true
        worktree_path=$(pwd)
        main_repo=$(get_main_repo_from_worktree)
        check_main_repo_ready "$main_repo" "$default_branch" || {
            echo "Aborting close to protect main repo state." >&2
            echo "Your feature branch '$current_branch' is untouched." >&2
            return 1
        }
    fi

    # --dry-run: all preflight checks passed; exit before any mutation.
    if [[ "$dry_run" == "true" ]]; then
        echo "Dry-run: all preflight checks passed."
        echo "  ticket file:    $ticket_file"
        echo "  feature branch: $current_branch"
        echo "  base branch:    $default_branch"
        if [[ "$in_worktree" == "true" ]]; then
            echo "  mode:           worktree"
            echo "  main repo:      $main_repo"
            echo "  worktree path:  $worktree_path"
        else
            echo "  mode:           in-place"
        fi
        echo ""
        echo "No changes were made. Re-run without --dry-run to close the ticket."
        echo "Note: pre-commit hooks are NOT executed by --dry-run."
        return 0
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
    
    # Remove current-ticket.md and current-note.md from git history if they exist
    # This prevents accidental commits of these files when force-added
    if git ls-files | grep -q "^current-ticket.md$"; then
        run_git_command "git rm --cached current-ticket.md" || {
            echo "Error: Failed to remove current-ticket.md from git history" >&2
            # Rollback ticket file changes
            echo "$original_ticket_content" > "$ticket_file"
            return 1
        }
    fi
    if git ls-files | grep -q "^current-note.md$"; then
        run_git_command "git rm --cached current-note.md" || {
            echo "Error: Failed to remove current-note.md from git history" >&2
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
        if ! git restore --staged "$ticket_file" 2>&1; then
            echo "Warning: Could not unstage ticket file - manual cleanup may be needed" >&2
        fi
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

    # Create commit message (used by both merge paths below)
    local commit_msg="[${ticket_name}] ${description}"
    if [[ -z "$description" ]]; then
        commit_msg="[${ticket_name}] Ticket completed"
    fi
    commit_msg="${commit_msg}\n\n${ticket_content}"

    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    local done_dir="${tickets_dir}/done"
    local note_file="${tickets_dir}/${ticket_name}-note.md"
    local new_ticket_path="${done_dir}/$(basename "$ticket_file")"
    local new_note_path="${done_dir}/$(basename "$note_file")"

    if [[ "$in_worktree" == "true" ]]; then
        # Worktree mode: perform the merge via "git -C $main_repo" so this
        # process's cwd stays in the worker's worktree. We assume main_repo
        # is already on $default_branch (the intended invariant for parallel
        # multi-worktree setups); if it is not, git will surface the error.
        echo "Closing ticket from worktree..."

        run_git_command "git -C $main_repo merge --squash $current_branch" || {
            echo "Error: Failed to squash merge feature branch into '$default_branch'" >&2
            echo "Feature branch '$current_branch' still exists with your changes" >&2
            echo "Please resolve merge conflicts manually in '$main_repo' or run 'git -C $main_repo merge --abort'" >&2
            return 1
        }

        if [[ ! -d "${main_repo}/${done_dir}" ]] && ! mkdir -p "${main_repo}/${done_dir}"; then
            echo "Error: Failed to create done directory inside main repo" >&2
            return 1
        fi

        run_git_command "git -C $main_repo mv \"$ticket_file\" \"$new_ticket_path\"" || {
            echo "Error: Failed to move ticket to done folder" >&2
            return 1
        }

        if [[ -f "${main_repo}/${note_file}" ]]; then
            run_git_command "git -C $main_repo mv \"$note_file\" \"$new_note_path\"" || {
                echo "Error: Failed to move note file to done folder" >&2
                return 1
            }
        fi

        echo -e "$commit_msg" | run_git_command "git -C $main_repo commit -F -" || {
            echo "Error: Failed to commit final merge" >&2
            return 1
        }

        if [[ "$auto_push" == "true" ]] && [[ "$no_push" == "false" ]]; then
            run_git_command "git -C $main_repo push $repository $default_branch" || {
                echo "Warning: Failed to push to remote repository" >&2
                echo "Local ticket closing completed. Please push manually later:" >&2
                echo "  git -C $main_repo push $repository $default_branch" >&2
            }
        fi

        if [[ "$delete_remote_on_close" == "true" ]] && [[ "$no_delete_remote" == "false" ]]; then
            if [[ "$auto_push" == "true" ]] || [[ "$no_push" == "false" ]]; then
                if git -C "$main_repo" ls-remote --heads "$repository" "$current_branch" | grep -q "$current_branch"; then
                    run_git_command "git -C $main_repo push $repository --delete $current_branch" || {
                        echo "Warning: Failed to delete remote branch '$current_branch'" >&2
                    }
                else
                    echo "Note: Remote branch '$current_branch' not found (may have been already deleted)"
                fi
            fi
        fi

        # Optionally remove the worker's feature worktree. Agents pass
        # --keep-worktree so their shell cwd stays valid and they can
        # continue on to the next ticket; humans typically let it go.
        if [[ "$keep_worktree" == "true" ]]; then
            echo "Worker worktree preserved: $worktree_path"
            echo "(--keep-worktree: branch '$current_branch' was merged but the worktree stays.)"
        else
            run_git_command "git -C $main_repo worktree remove $worktree_path" || {
                echo "Warning: Failed to remove worktree at '$worktree_path'" >&2
                echo "You can manually remove it with: git worktree remove $worktree_path" >&2
            }
            echo "Worktree removed: $worktree_path"
            echo ""
            echo "CAUTION: The worktree has been removed. Return to the main repository."
            echo "  cd $main_repo"
            echo ""
            echo "Your shell is still in the removed worktree directory; subsequent commands will fail until you cd."
        fi
    else
        # Non-worktree mode: classic in-place merge on the current checkout.
        run_git_command "git checkout $default_branch" || {
            echo "Error: Failed to switch to default branch '$default_branch'" >&2
            echo "Your changes have been committed on feature branch '$current_branch'" >&2
            echo "Please manually switch to '$default_branch' and run close again" >&2
            return 1
        }

        run_git_command "git merge --squash $current_branch" || {
            echo "Error: Failed to squash merge feature branch" >&2
            echo "You are now on '$default_branch' branch" >&2
            echo "Feature branch '$current_branch' still exists with your changes" >&2
            echo "Please resolve merge conflicts manually or run 'git merge --abort'" >&2
            return 1
        }

        if [[ ! -d "$done_dir" ]] && ! mkdir -p "$done_dir"; then
            echo "Error: Failed to create done directory: $done_dir" >&2
            return 1
        fi

        run_git_command "git mv \"$ticket_file\" \"$new_ticket_path\"" || {
            echo "Error: Failed to move ticket to done folder" >&2
            return 1
        }

        if [[ -f "$note_file" ]]; then
            run_git_command "git mv \"$note_file\" \"$new_note_path\"" || {
                echo "Error: Failed to move note file to done folder" >&2
                return 1
            }
        fi

        echo -e "$commit_msg" | run_git_command "git commit -F -" || {
            echo "Error: Failed to commit final merge" >&2
            echo "Squash merge is staged but not committed" >&2
            echo "You can commit manually with: git commit" >&2
            echo "Or abort with: git reset --hard HEAD" >&2
            return 1
        }

        if [[ "$auto_push" == "true" ]] && [[ "$no_push" == "false" ]]; then
            run_git_command "git push $repository $default_branch" || {
                echo "Warning: Failed to push to remote repository" >&2
            }
        fi

        if [[ "$delete_remote_on_close" == "true" ]] && [[ "$no_delete_remote" == "false" ]]; then
            if [[ "$auto_push" == "true" ]] || [[ "$no_push" == "false" ]]; then
                if git ls-remote --heads "$repository" "$current_branch" | grep -q "$current_branch"; then
                    run_git_command "git push $repository --delete $current_branch" || {
                        echo "Warning: Failed to delete remote branch '$current_branch'" >&2
                    }
                else
                    echo "Note: Remote branch '$current_branch' not found (may have been already deleted)"
                fi
            fi
        fi
    fi

    # Remove current ticket and note links - core workflow is complete, safe to remove
    rm -f "$CURRENT_TICKET_LINK"
    rm -f "$CURRENT_NOTE_LINK"

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

# Command: cancel
# Cancel the current ticket without merging
cmd_cancel() {
    local force=false
    local keep_worktree=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force|-f)
                force=true
                shift
                ;;
            --keep-worktree)
                keep_worktree=true
                shift
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                echo "Usage: $SCRIPT_COMMAND cancel [--force|-f] [--keep-worktree]" >&2
                return 1
                ;;
        esac
    done

    # Check prerequisites
    check_git_repo || return 1
    check_config || return 1

    # Check clean working directory unless --force is used
    if [[ "$force" == "false" ]]; then
        # Parse config to get tickets_dir for smarter error messages
        local _cancel_tickets_dir="$DEFAULT_TICKETS_DIR"
        if yaml_parse "$CONFIG_FILE" 2>/dev/null; then
            _cancel_tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
        fi
        if ! check_clean_working_dir "$_cancel_tickets_dir"; then
            cat >&2 << EOF

To ignore uncommitted changes and force cancel, use:
  $SCRIPT_COMMAND cancel --force (or -f)
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
EOF
        return 1
    fi

    # Load configuration
    if ! yaml_parse "$CONFIG_FILE"; then
        echo "Error: Cannot parse configuration file: $CONFIG_FILE" >&2
        return 1
    fi
    local default_branch=$(yaml_get "default_branch" || echo "$DEFAULT_BRANCH")
    local branch_prefix=$(yaml_get "branch_prefix" || echo "$DEFAULT_BRANCH_PREFIX")

    # Check current branch
    local current_branch=$(get_current_branch)
    if [[ ! "$current_branch" =~ ^${branch_prefix} ]]; then
        cat >&2 << EOF
Error: Not on a feature branch
Must be on a feature branch to cancel ticket. Please:
1. Switch to feature branch: git checkout ${branch_prefix}<ticket-name>
2. Or check current branch: git branch
EOF
        return 1
    fi

    # Check ticket status
    local yaml_content=$(extract_yaml_frontmatter "$ticket_file")
    echo "$yaml_content" >| /tmp/ticket_yaml.yml
    yaml_parse /tmp/ticket_yaml.yml
    local started_at=$(yaml_get "started_at" || echo "null")
    local closed_at=$(yaml_get "closed_at" || echo "null")
    local canceled_at=$(yaml_get "canceled_at" || echo "null")
    local description=$(yaml_get "description" || echo "")
    local base_branch=$(yaml_get "base_branch" || echo "")
    # Backward compatibility: fall back to merge_to if base_branch is not set
    if is_null_or_empty "$base_branch" || [[ "$(echo "$base_branch" | tr '[:upper:]' '[:lower:]')" == "default" ]]; then
        base_branch=$(yaml_get "merge_to" || echo "default")
    fi
    rm -f /tmp/ticket_yaml.yml

    # Override default_branch if base_branch is specified
    local base_branch_lower=$(echo "$base_branch" | tr '[:upper:]' '[:lower:]')
    if ! is_null_or_empty "$base_branch" && [[ "$base_branch_lower" != "default" ]]; then
        if ! git rev-parse --verify "$base_branch" >/dev/null 2>&1; then
            echo "Error: base_branch '$base_branch' does not exist" >&2
            return 1
        fi
        default_branch="$base_branch"
    fi

    if ! is_null_or_empty "$closed_at"; then
        echo "Error: Ticket already completed (closed_at is set)" >&2
        return 1
    fi

    if ! is_null_or_empty "$canceled_at"; then
        echo "Error: Ticket already canceled (canceled_at is set)" >&2
        return 1
    fi

    # Detect worktree mode and validate main repo state early. See cmd_close
    # for the same rationale.
    local in_worktree=false
    local worktree_path=""
    local main_repo=""
    if is_git_worktree; then
        in_worktree=true
        worktree_path=$(pwd)
        main_repo=$(get_main_repo_from_worktree)
        check_main_repo_ready "$main_repo" "$default_branch" || {
            echo "Aborting cancel to protect main repo state." >&2
            return 1
        }
    fi

    # Store original ticket state for rollback
    local original_ticket_content=$(cat "$ticket_file")

    # Update canceled_at
    local timestamp=$(get_utc_timestamp)
    update_yaml_frontmatter_field "$ticket_file" "canceled_at" "$timestamp" || {
        echo "Error: Failed to update ticket canceled_at field" >&2
        return 1
    }

    # Update description with [CANCELED] prefix
    local new_description="[CANCELED] ${description}"
    update_yaml_frontmatter_field "$ticket_file" "description" "$new_description" || {
        echo "Error: Failed to update ticket description" >&2
        echo "$original_ticket_content" > "$ticket_file"
        return 1
    }

    # Remove current-ticket.md and current-note.md from git history if they exist
    if git ls-files | grep -q "^current-ticket.md$"; then
        run_git_command "git rm --cached current-ticket.md" || {
            echo "Error: Failed to remove current-ticket.md from git history" >&2
            echo "$original_ticket_content" > "$ticket_file"
            return 1
        }
    fi
    if git ls-files | grep -q "^current-note.md$"; then
        run_git_command "git rm --cached current-note.md" || {
            echo "Error: Failed to remove current-note.md from git history" >&2
            echo "$original_ticket_content" > "$ticket_file"
            return 1
        }
    fi

    # Commit the change on feature branch
    run_git_command "git add $ticket_file" || {
        echo "Error: Failed to stage ticket file" >&2
        echo "$original_ticket_content" > "$ticket_file"
        return 1
    }

    run_git_command "git commit -m \"Cancel ticket\"" || {
        echo "Error: Failed to commit ticket cancellation" >&2
        echo "$original_ticket_content" > "$ticket_file"
        git restore --staged "$ticket_file" 2>/dev/null || true
        return 1
    }

    # Get ticket name BEFORE proceeding with cleanup paths
    local ticket_name=$(basename "$ticket_file" .md)

    local tickets_dir=$(yaml_get "tickets_dir" || echo "$DEFAULT_TICKETS_DIR")
    local done_dir="${tickets_dir}/done"
    local note_file="${tickets_dir}/${ticket_name}-note.md"

    # Build canceled filename: insert -CANCELED- before the slug part
    # Original: YYMMDD-hhmmss-slug-name.md -> YYMMDD-hhmmss-CANCELED-slug-name.md
    local base_name=$(basename "$ticket_file")
    local canceled_name
    if [[ "$base_name" =~ ^([0-9]{6}-[0-9]{6})-(.*)$ ]]; then
        canceled_name="${BASH_REMATCH[1]}-CANCELED-${BASH_REMATCH[2]}"
    else
        canceled_name="CANCELED-${base_name}"
    fi
    local new_ticket_path="${done_dir}/${canceled_name}"

    local note_base=$(basename "$note_file")
    local canceled_note_name
    if [[ "$note_base" =~ ^([0-9]{6}-[0-9]{6})-(.*)$ ]]; then
        canceled_note_name="${BASH_REMATCH[1]}-CANCELED-${BASH_REMATCH[2]}"
    else
        canceled_note_name="CANCELED-${note_base}"
    fi
    local new_note_path="${done_dir}/${canceled_note_name}"

    local commit_msg="[${ticket_name}] Ticket canceled"

    if [[ "$in_worktree" == "true" ]]; then
        # Worktree mode: stage the cancel commit via "git -C $main_repo"
        # without cd'ing. main_repo is assumed to already be on $default_branch.
        echo "Canceling ticket from worktree..."

        if [[ ! -d "${main_repo}/${done_dir}" ]] && ! mkdir -p "${main_repo}/${done_dir}"; then
            echo "Error: Failed to create done directory inside main repo" >&2
            return 1
        fi

        run_git_command "git -C $main_repo checkout $current_branch -- $ticket_file" || {
            echo "Error: Failed to retrieve ticket file from feature branch" >&2
            return 1
        }

        mv "${main_repo}/${ticket_file}" "${main_repo}/${new_ticket_path}" || {
            echo "Error: Failed to move ticket to canceled location" >&2
            return 1
        }

        if git -C "$main_repo" show "${current_branch}:${note_file}" >/dev/null 2>&1; then
            run_git_command "git -C $main_repo checkout $current_branch -- $note_file" || true
            if [[ -f "${main_repo}/${note_file}" ]]; then
                mv "${main_repo}/${note_file}" "${main_repo}/${new_note_path}" || true
            fi
        fi

        run_git_command "git -C $main_repo add ${done_dir}/" || {
            echo "Error: Failed to stage canceled ticket" >&2
            return 1
        }

        run_git_command "git -C $main_repo commit -m \"$commit_msg\"" || {
            echo "Error: Failed to commit canceled ticket" >&2
            return 1
        }

        if [[ "$keep_worktree" == "true" ]]; then
            echo "Worker worktree preserved: $worktree_path"
        else
            run_git_command "git -C $main_repo worktree remove $worktree_path" || {
                echo "Warning: Failed to remove worktree at '$worktree_path'" >&2
                echo "You can manually remove it with: git worktree remove $worktree_path" >&2
            }
            echo "Worktree removed: $worktree_path"
            echo ""
            echo "CAUTION: The worktree has been removed. Return to the main repository."
            echo "  cd $main_repo"
            echo ""
            echo "Your shell is still in the removed worktree directory; subsequent commands will fail until you cd."
        fi
    else
        # Non-worktree mode: classic in-place behavior on the current checkout.
        run_git_command "git checkout $default_branch" || {
            echo "Error: Failed to switch to default branch '$default_branch'" >&2
            echo "Your changes have been committed on feature branch '$current_branch'" >&2
            return 1
        }

        if [[ ! -d "$done_dir" ]] && ! mkdir -p "$done_dir"; then
            echo "Error: Failed to create done directory: $done_dir" >&2
            return 1
        fi

        run_git_command "git checkout $current_branch -- $ticket_file" || {
            echo "Error: Failed to retrieve ticket file from feature branch" >&2
            return 1
        }

        mv "$ticket_file" "$new_ticket_path"

        if git show "${current_branch}:${note_file}" >/dev/null 2>&1; then
            run_git_command "git checkout $current_branch -- $note_file" || true
            if [[ -f "$note_file" ]]; then
                mv "$note_file" "$new_note_path"
            fi
        fi

        run_git_command "git add ${done_dir}/" || {
            echo "Error: Failed to stage canceled ticket" >&2
            return 1
        }

        run_git_command "git commit -m \"$commit_msg\"" || {
            echo "Error: Failed to commit canceled ticket" >&2
            return 1
        }
    fi

    # Remove current ticket and note links
    rm -f "$CURRENT_TICKET_LINK"
    rm -f "$CURRENT_NOTE_LINK"

    echo "Ticket canceled: $ticket_name"
    echo "Moved to: $new_ticket_path"
    echo "Feature branch '$current_branch' has been kept (not deleted)"
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

### If `current-ticket.md` exists in project root

- This file is your work instruction - follow its contents
- When receiving additional instructions from users, add them as new tasks under `## Tasks` and record details in `current-note.md` before proceeding
- During the work, also write down notes, logs, and findings in `current-note.md`
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
3. Develop on feature branch
4. Reference work files:
   - `current-ticket.md` shows active ticket with tasks
   - `current-note.md` for working notes related to this ticket (if used)

## Closing Tickets

1. Before closing:
   - Review `current-ticket.md` content and description, collect information from `current-note.md` and other notes, and summarize the final work results and conclusions so that anyone reading the ticket can understand the work done on this branch
   - Check all tasks in checklist are completed (mark with `[x]`)
   - Commit all your work: `git add . && git commit -m "your message"`
   - Get user approval before proceeding
2. Complete: `./ticket.sh close`
   - **When inside a worktree, always add `--keep-worktree`**: `./ticket.sh close --keep-worktree`
     Without it, ticket.sh removes the worktree and your shell's cwd becomes dangling, which makes every subsequent Bash tool call fail.
   - Same rule for cancel: `./ticket.sh cancel --keep-worktree`.
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
# Wait for parent process to exit
sleep 1

# Ensure LF line endings (CRLF compatibility fix)
# This prevents "/usr/bin/env: 'bash\r': No such file or directory" errors
if command -v dos2unix >/dev/null 2>&1; then
    dos2unix "$temp_file" >/dev/null 2>&1
elif command -v sed >/dev/null 2>&1; then
    # Remove any CR characters using sed (more portable)
    sed -i.bak 's/\r$//' "$temp_file" && rm -f "${temp_file}.bak"
else
    # Fallback: try tr command
    if command -v tr >/dev/null 2>&1; then
        tr -d '\r' < "$temp_file" > "${temp_file}.tmp" && mv "${temp_file}.tmp" "$temp_file"
    fi
fi

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

# ============================================================================
# Epic management
# ============================================================================
# Epic = a hand-named, longer-lived unit of work that contains multiple tickets.
# Epic files live at epics/<slug>.md (open) and epics/done/<slug>/index.md
# (closed/cancelled). Branch policy is declared in the epic's `branch:` frontmatter:
#   - "main"          : main-direct, edits land on main, tickets branch off main
#   - "epic/<slug>"   : epic-branch, work isolated, tickets branch off the epic branch
# See gist 09b482ac for the full spec.

# Validate epic slug: ^[a-z][a-z0-9._-]{0,79}$ (looser than ticket slugs).
validate_epic_slug() {
    local slug="$1"
    if [[ ! "$slug" =~ ^[a-z][a-z0-9._-]{0,79}$ ]]; then
        cat >&2 << EOF
Error: Invalid epic slug
Epic slug '$slug' must match ^[a-z][a-z0-9._-]{0,79}\$.
1. Start with a lowercase letter (a-z)
2. Use lowercase letters, digits, '.', '_', '-' only
3. Max 80 characters
EOF
        return 1
    fi
    return 0
}

# Escape a string for inclusion in JSON. Handles \, ", and control chars (0x00-0x1F).
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\b'/\\b}"
    s="${s//$'\f'/\\f}"
    printf '%s' "$s"
}

# Read a single field from raw YAML frontmatter content (no $file required).
# Strips surrounding quotes and inline `# comment` tail.
# Usage: get_yaml_field <yaml_content> <field>
get_yaml_field() {
    local content="$1"
    local field="$2"
    local line
    while IFS= read -r line; do
        line=${line%$'\r'}
        if [[ "$line" =~ ^[[:space:]]*${field}:[[:space:]]*(.*)$ ]]; then
            local value="${BASH_REMATCH[1]}"
            # Strip trailing inline comment ' #...' (only when preceded by space)
            if [[ "$value" =~ ^(.*[^[:space:]])[[:space:]]+#.*$ ]]; then
                value="${BASH_REMATCH[1]}"
            elif [[ "$value" =~ ^[[:space:]]*#.*$ ]]; then
                value=""
            fi
            # Strip surrounding double or single quotes
            if [[ "$value" =~ ^\"(.*)\"[[:space:]]*$ ]]; then
                value="${BASH_REMATCH[1]}"
            elif [[ "$value" =~ ^\'(.*)\'[[:space:]]*$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi
            # Trim trailing whitespace
            value="${value%"${value##*[![:space:]]}"}"
            printf '%s' "$value"
            return 0
        fi
    done <<< "$content"
    return 1
}

# Resolve an epic slug to its source. Search order:
#   1. main:epics/<slug>.md                     (open on main / main-direct)
#   2. <each refs/heads/epic/*>:epics/<slug>.md (open on epic branch)
#   3. main:epics/done/<slug>/index.md          (closed/cancelled)
# Sets globals: EPIC_ORIGIN ("main"|"branch"|"done"), EPIC_SOURCE_REF (the git ref
# we read from), EPIC_PATH (the path within that ref), EPIC_RAW (full file content).
# Returns 0 on success, 1 if not found.
resolve_epic() {
    local slug="$1"
    local content

    # 1. main:epics/<slug>.md
    if content=$(git show "main:epics/${slug}.md" 2>/dev/null); then
        EPIC_ORIGIN="main"
        EPIC_SOURCE_REF="main"
        EPIC_PATH="epics/${slug}.md"
        EPIC_RAW="$content"
        return 0
    fi

    # 2. each refs/heads/epic/*
    local branch
    while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue
        if content=$(git show "${branch}:epics/${slug}.md" 2>/dev/null); then
            EPIC_ORIGIN="branch"
            EPIC_SOURCE_REF="$branch"
            EPIC_PATH="epics/${slug}.md"
            EPIC_RAW="$content"
            return 0
        fi
    done < <(git for-each-ref --format='%(refname:short)' refs/heads/epic/ 2>/dev/null)

    # 3. main:epics/done/<slug>/index.md
    if content=$(git show "main:epics/done/${slug}/index.md" 2>/dev/null); then
        EPIC_ORIGIN="done"
        EPIC_SOURCE_REF="main"
        EPIC_PATH="epics/done/${slug}/index.md"
        EPIC_RAW="$content"
        return 0
    fi

    return 1
}

# Extract just the frontmatter portion from EPIC_RAW (or any markdown content).
# Usage: epic_extract_frontmatter <raw_content>
epic_extract_frontmatter() {
    local raw="$1"
    local in_fm=0 line_num=0 out=""
    while IFS= read -r line; do
        line=${line%$'\r'}
        ((line_num++))
        if [[ $line_num -eq 1 ]] && [[ "$line" == "---" ]]; then
            in_fm=1
            continue
        elif [[ $in_fm -eq 1 ]] && [[ "$line" == "---" ]]; then
            break
        elif [[ $in_fm -eq 1 ]]; then
            out+="$line"$'\n'
        fi
    done <<< "$raw"
    printf '%s' "$out"
}

# Extract the body (after frontmatter) from a raw markdown content.
epic_extract_body() {
    local raw="$1"
    local in_fm=0 past=0 line_num=0 out=""
    while IFS= read -r line; do
        line=${line%$'\r'}
        ((line_num++))
        if [[ $line_num -eq 1 ]] && [[ "$line" == "---" ]]; then
            in_fm=1
            continue
        elif [[ $in_fm -eq 1 ]] && [[ "$line" == "---" ]]; then
            in_fm=0
            past=1
            continue
        elif [[ $past -eq 1 ]]; then
            out+="$line"$'\n'
        fi
    done <<< "$raw"
    printf '%s' "$out"
}

# Write an epic file with given frontmatter values + body.
# Usage: write_epic_file <path> <slug> <title> <branch> <status> <created_at> \
#                       [<closed_at>] [<cancelled_at>] [<cancel_reason>] [<started_at>]
# Empty string = unset (rendered as null). Body comes from $EPIC_BODY (caller sets).
write_epic_file() {
    local path="$1" slug="$2" title="$3" branch="$4" status="$5" created_at="$6"
    local closed_at="${7:-}" cancelled_at="${8:-}" cancel_reason="${9:-}" started_at="${10:-}"
    local body="${EPIC_BODY:-}"

    {
        echo "---"
        echo "version: 1"
        echo "epic_id: $slug"
        # title — quote it for safety
        echo "title: \"$(printf '%s' "$title" | sed 's/"/\\"/g')\""
        echo "status: $status"
        echo "branch: $branch"
        echo "created_at: $created_at"
        if [[ -n "$started_at" ]]; then echo "started_at: $started_at"; else echo "started_at: null"; fi
        if [[ -n "$closed_at" ]]; then echo "closed_at: $closed_at"; else echo "closed_at: null"; fi
        if [[ -n "$cancelled_at" ]]; then echo "cancelled_at: $cancelled_at"; else echo "cancelled_at: null"; fi
        if [[ -n "$cancel_reason" ]]; then
            echo "cancel_reason: \"$(printf '%s' "$cancel_reason" | sed 's/"/\\"/g')\""
        else
            echo "cancel_reason: null"
        fi
        echo "---"
        echo ""
        printf '%s' "$body"
    } > "$path"
}

# Default epic body template.
epic_default_body() {
    local title="$1"
    cat << EOF
# ${title}

## Outcome

(when this epic completes, what new capability exists?)

## Problem

(what problem does this directly solve?)

## Scope

(concrete deliverables — granular enough that "is X in scope" is unambiguous)

## Non-goals

(what we are deliberately NOT doing — name the AI-temptations to drift into)

## Exit Criteria

(when these are true, close the epic. all linked tickets done is necessary but not sufficient)

## Tickets

(filled as tickets are cut)
EOF
}

# Scan for tickets linked to this epic. Searches working tree (tickets/*.md and
# tickets/done/**/*.md) plus the epic branch (when given) and emits one line
# per match: "<status>|<location>|<path>" where status is open/closed and
# location is "working tree" or "<branch>".
# Usage: epic_find_linked_tickets <slug> [<epic-branch>]
epic_find_linked_tickets() {
    local slug="$1" epic_branch="${2:-}"
    local tickets_dir="tickets"

    # Working tree: open tickets at tickets/*.md
    local f
    if [[ -d "$tickets_dir" ]]; then
        for f in "$tickets_dir"/*.md; do
            [[ -f "$f" ]] || continue
            local base="${f##*/}"
            [[ "$base" == "README.md" ]] && continue
            local fm body
            fm=$(extract_yaml_frontmatter "$f" 2>/dev/null) || continue
            local eid
            eid=$(get_yaml_field "$fm" "epic_id") || true
            if [[ "$eid" == "$slug" ]]; then
                echo "open|working tree|$f"
            fi
        done
        # Closed tickets at tickets/done/*.md
        if [[ -d "$tickets_dir/done" ]]; then
            for f in "$tickets_dir"/done/*.md; do
                [[ -f "$f" ]] || continue
                local fm
                fm=$(extract_yaml_frontmatter "$f" 2>/dev/null) || continue
                local eid
                eid=$(get_yaml_field "$fm" "epic_id") || true
                if [[ "$eid" == "$slug" ]]; then
                    echo "closed|working tree|$f"
                fi
            done
        fi
    fi

    # Epic branch (if provided): scan tickets/*.md
    if [[ -n "$epic_branch" ]]; then
        local seen_paths=()
        local path
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            [[ "$path" == "tickets/done/"* ]] && continue
            [[ "$path" == "tickets/README.md" ]] && continue
            local content
            content=$(git show "${epic_branch}:${path}" 2>/dev/null) || continue
            local fm
            fm=$(epic_extract_frontmatter "$content")
            local eid
            eid=$(get_yaml_field "$fm" "epic_id") || true
            if [[ "$eid" == "$slug" ]]; then
                # Skip if already seen on working tree
                if [[ ! -f "$path" ]]; then
                    echo "open|${epic_branch}|${path}"
                fi
            fi
        done < <(git ls-tree -r --name-only "$epic_branch" -- "$tickets_dir" 2>/dev/null | grep -E '\.md$' || true)
    fi
}

# Command: epic new <slug> [opts]
cmd_epic_new() {
    local slug=""
    local title=""
    local branch=""
    local main_direct=false
    local from_ref="main"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)
                title="$2"; shift 2 ;;
            --branch)
                branch="$2"; shift 2 ;;
            --main-direct)
                main_direct=true; shift ;;
            --from-ref)
                from_ref="$2"; shift 2 ;;
            --*)
                echo "Error: Unknown option: $1" >&2
                return 1 ;;
            *)
                if [[ -z "$slug" ]]; then
                    slug="$1"
                else
                    echo "Error: Unexpected argument: $1" >&2
                    return 1
                fi
                shift ;;
        esac
    done

    if [[ -z "$slug" ]]; then
        echo "Error: epic slug required" >&2
        echo "Usage: $SCRIPT_COMMAND epic new <slug> [--title <t>] [--branch epic/<slug>|--main-direct] [--from-ref <ref>]" >&2
        return 3
    fi

    check_git_repo || return 1
    validate_epic_slug "$slug" || return 3

    # Resolve branch policy
    if [[ "$main_direct" == "true" ]]; then
        if [[ -n "$branch" ]]; then
            echo "Error: --branch and --main-direct are mutually exclusive" >&2
            return 1
        fi
        branch="main"
    elif [[ -z "$branch" ]]; then
        branch="epic/${slug}"
    fi

    [[ -z "$title" ]] && title="$slug"

    # Verify epic file does NOT exist on main
    if git show "main:epics/${slug}.md" >/dev/null 2>&1; then
        echo "Error: Epic '$slug' already exists on main (epics/${slug}.md)" >&2
        return 4
    fi
    if git show "main:epics/done/${slug}/index.md" >/dev/null 2>&1; then
        echo "Error: Epic '$slug' already exists at epics/done/${slug}/index.md (closed/cancelled)" >&2
        return 4
    fi

    # If using an epic branch, verify it does NOT exist
    if [[ "$branch" != "main" ]]; then
        if git rev-parse --verify "refs/heads/${branch}" >/dev/null 2>&1; then
            echo "Error: Branch '$branch' already exists" >&2
            return 5
        fi
    fi

    # Verify working tree clean
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        echo "Error: Working tree has uncommitted changes; commit or stash first" >&2
        return 6
    fi

    local original_branch
    original_branch=$(get_current_branch)

    # Switch to the right branch
    if [[ "$branch" == "main" ]]; then
        if [[ "$original_branch" != "main" ]]; then
            run_git_command "git switch main" || return 1
        fi
    else
        run_git_command "git switch -c $branch $from_ref" || return 1
    fi

    # Write the epic file
    local epic_dir="epics"
    [[ -d "$epic_dir" ]] || mkdir -p "$epic_dir"
    local epic_file="${epic_dir}/${slug}.md"
    local now
    now=$(get_utc_timestamp)

    EPIC_BODY="$(epic_default_body "$title")"
    write_epic_file "$epic_file" "$slug" "$title" "$branch" "open" "$now"

    run_git_command "git add $epic_file" || {
        # Rollback
        rm -f "$epic_file"
        if [[ "$branch" != "main" ]]; then
            run_git_command "git switch $original_branch" 2>/dev/null
            run_git_command "git branch -D $branch" 2>/dev/null
        fi
        return 1
    }
    run_git_command "git commit -m \"[epic/new] Create epic ${slug}\"" || {
        rm -f "$epic_file"
        if [[ "$branch" != "main" ]]; then
            run_git_command "git switch $original_branch" 2>/dev/null
            run_git_command "git branch -D $branch" 2>/dev/null
        fi
        return 1
    }

    echo "Epic ${slug} created."
    echo "  branch: ${branch}"
    echo "  file:   ${epic_file}"
    echo "Next: $SCRIPT_COMMAND new <ticket-slug> --epic ${slug}"
}

# Command: epic close <slug> [opts]
cmd_epic_close() {
    _cmd_epic_close_or_cancel "close" "$@"
}

# Command: epic cancel <slug> --reason <text> [opts]
cmd_epic_cancel() {
    _cmd_epic_close_or_cancel "cancel" "$@"
}

# Shared close/cancel implementation.
_cmd_epic_close_or_cancel() {
    local mode="$1"; shift
    local slug=""
    local dry_run=false
    local no_push=false
    local no_delete_remote=false
    local force=false
    local reason=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|-n) dry_run=true; shift ;;
            --no-push) no_push=true; shift ;;
            --no-delete-remote) no_delete_remote=true; shift ;;
            --force|-f) force=true; shift ;;
            --reason) reason="$2"; shift 2 ;;
            --*) echo "Error: Unknown option: $1" >&2; return 1 ;;
            *)
                if [[ -z "$slug" ]]; then slug="$1"; else echo "Error: Unexpected argument: $1" >&2; return 1; fi
                shift ;;
        esac
    done

    if [[ -z "$slug" ]]; then
        echo "Error: epic slug required" >&2
        return 1
    fi
    if [[ "$mode" == "cancel" ]] && [[ -z "$reason" ]]; then
        echo "Error: --reason required for cancel" >&2
        return 1
    fi

    check_git_repo || return 1

    if ! resolve_epic "$slug"; then
        echo "Error: Epic '$slug' not found" >&2
        return 1
    fi

    local epic_fm epic_body
    epic_fm=$(epic_extract_frontmatter "$EPIC_RAW")
    epic_body=$(epic_extract_body "$EPIC_RAW")
    local epic_branch
    epic_branch=$(get_yaml_field "$epic_fm" "branch")
    [[ -z "$epic_branch" ]] && epic_branch="main"

    local push_label="push to origin"; [[ "$no_push" == "true" ]] && push_label="skip"
    local delete_label="delete after merge"
    if [[ "$no_push" == "true" ]] || [[ "$no_delete_remote" == "true" ]]; then delete_label="skip"; fi

    echo "Epic: $slug"
    echo "Branch policy: $epic_branch"
    echo "Mode: $mode"
    echo "Push: $push_label"
    echo "Remote branch delete: $delete_label"
    echo "note: Epic file resolved via git show ${EPIC_SOURCE_REF}:${EPIC_PATH}"

    # ---- Preflight ----
    local blockers=()
    local closed_at cancelled_at
    closed_at=$(get_yaml_field "$epic_fm" "closed_at"); [[ "$closed_at" == "null" ]] && closed_at=""
    cancelled_at=$(get_yaml_field "$epic_fm" "cancelled_at"); [[ "$cancelled_at" == "null" ]] && cancelled_at=""

    if [[ "$mode" == "close" ]] && [[ -n "$closed_at" ]]; then
        blockers+=("Epic is already closed (closed_at: $closed_at)")
    fi
    if [[ "$mode" == "cancel" ]] && [[ -n "$cancelled_at" ]]; then
        blockers+=("Epic is already cancelled (cancelled_at: $cancelled_at)")
    fi

    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        blockers+=("Working tree is dirty (uncommitted changes)")
    fi

    if [[ "$epic_branch" != "main" ]]; then
        if ! git rev-parse --verify "refs/heads/${epic_branch}" >/dev/null 2>&1; then
            blockers+=("Epic branch '${epic_branch}' does not exist locally")
        fi
    fi

    # Open linked tickets
    local linked_open=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local status="${line%%|*}"
        if [[ "$status" == "open" ]]; then
            linked_open+=("$line")
        fi
    done < <(epic_find_linked_tickets "$slug" "$epic_branch")
    if [[ ${#linked_open[@]} -gt 0 ]]; then
        local msg="Epic still has ${#linked_open[@]} open ticket(s) linked to it:"
        local L
        for L in "${linked_open[@]}"; do
            local loc="${L#*|}"; loc="${loc%|*}"
            local p="${L##*|}"
            msg+=$'\n'"    ${p} (${loc})"
        done
        blockers+=("$msg")
    fi

    if [[ ${#blockers[@]} -gt 0 ]] && [[ "$force" != "true" ]]; then
        echo "Preflight: BLOCKED"
        local b
        for b in "${blockers[@]}"; do
            # Print first line with arrow, indent subsequent lines
            local first_line="${b%%$'\n'*}"
            echo "  ✗ $first_line"
            if [[ "$b" == *$'\n'* ]]; then
                echo "${b#*$'\n'}"
            fi
        done
        echo "error: Preflight failed for epic $slug. Resolve the blockers above, or pass --force." >&2
        return 2
    fi

    if [[ ${#blockers[@]} -eq 0 ]]; then
        echo "Preflight: OK"
    else
        echo "Preflight: BLOCKED (proceeding due to --force)"
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "Dry-run: no changes were made."
        return 0
    fi

    # ---- Mutation ----
    local now
    now=$(get_utc_timestamp)

    if [[ "$mode" == "close" ]]; then
        if [[ "$epic_branch" == "main" ]]; then
            _epic_close_main_direct "$slug" "$epic_fm" "$epic_body" "$now" "$no_push" || return 3
        else
            _epic_close_epic_branch "$slug" "$epic_fm" "$epic_body" "$epic_branch" "$now" "$no_push" "$no_delete_remote" || return 3
        fi
    else
        if [[ "$epic_branch" == "main" ]]; then
            _epic_cancel_main_direct "$slug" "$epic_fm" "$epic_body" "$now" "$reason" "$no_push" || return 3
        else
            _epic_cancel_epic_branch "$slug" "$epic_fm" "$epic_body" "$epic_branch" "$now" "$reason" "$no_push" "$no_delete_remote" || return 3
        fi
    fi
}

# Resolve all unmerged paths after `git merge --squash -X theirs <epic-branch>`.
# For each unmerged path: take the epic-branch version if it exists there,
# otherwise drop the file. Returns 0 on success, 1 if residuals remain.
_epic_resolve_squash_residuals() {
    local epic_branch="$1"
    local path
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        if git cat-file -e "${epic_branch}:${path}" 2>/dev/null; then
            git checkout --theirs -- "$path" || return 1
            git add -- "$path" || return 1
        else
            git rm -f -- "$path" || return 1
        fi
    done < <(git diff --name-only --diff-filter=U 2>/dev/null)
    # Verify clean
    if [[ -n "$(git diff --name-only --diff-filter=U 2>/dev/null)" ]]; then
        return 1
    fi
    return 0
}

# Close, epic-branch case.
_epic_close_epic_branch() {
    local slug="$1" epic_fm="$2" epic_body="$3" epic_branch="$4" now="$5" no_push="$6" no_delete_remote="$7"

    run_git_command "git switch $epic_branch" || return 1

    local done_dir="epics/done/${slug}"
    mkdir -p "$done_dir"

    local source_path="epics/${slug}.md"
    local target_path="${done_dir}/index.md"

    if [[ -f "$source_path" ]]; then
        run_git_command "git mv $source_path $target_path" || return 1
    fi

    # Rewrite frontmatter on target
    local title branch_field created_at started_at
    title=$(get_yaml_field "$epic_fm" "title")
    branch_field=$(get_yaml_field "$epic_fm" "branch")
    created_at=$(get_yaml_field "$epic_fm" "created_at")
    started_at=$(get_yaml_field "$epic_fm" "started_at"); [[ "$started_at" == "null" ]] && started_at=""
    EPIC_BODY="$epic_body"
    write_epic_file "$target_path" "$slug" "$title" "$branch_field" "closed" "$created_at" "$now" "" "" "$started_at"

    run_git_command "git add -A epics/" || return 1
    run_git_command "git commit -m \"[epic/close] Close epic ${slug}\"" || return 1

    run_git_command "git switch main" || return 1

    # Squash merge with theirs preference; squash with conflicts returns nonzero
    # but leaves the index in a recoverable state.
    git merge --squash -X theirs "$epic_branch" 2>&1 | grep -v '^$' >&2 || true

    if ! _epic_resolve_squash_residuals "$epic_branch"; then
        echo "error: Squash merge has unresolved conflicts for epic '${slug}'" >&2
        return 1
    fi

    run_git_command "git commit -m \"[epic/close] Close epic ${slug}\"" || return 1

    if [[ "$no_push" != "true" ]]; then
        run_git_command "git push origin main" || echo "Warning: failed to push main" >&2
    fi

    run_git_command "git branch -D $epic_branch" || echo "Warning: failed to delete local branch $epic_branch" >&2

    if [[ "$no_push" != "true" ]] && [[ "$no_delete_remote" != "true" ]]; then
        if git ls-remote --heads origin "$epic_branch" 2>/dev/null | grep -q "$epic_branch"; then
            run_git_command "git push origin --delete $epic_branch" || echo "Warning: failed to delete remote branch" >&2
        fi
    fi

    echo "Epic ${slug} closed. main contains the squash merge; ${epic_branch} branch deleted."
}

# Close, main-direct case.
_epic_close_main_direct() {
    local slug="$1" epic_fm="$2" epic_body="$3" now="$4" no_push="$5"

    run_git_command "git switch main" || return 1

    local done_dir="epics/done/${slug}"
    mkdir -p "$done_dir"
    local source_path="epics/${slug}.md"
    local target_path="${done_dir}/index.md"
    if [[ -f "$source_path" ]]; then
        run_git_command "git mv $source_path $target_path" || return 1
    fi

    local title branch_field created_at started_at
    title=$(get_yaml_field "$epic_fm" "title")
    branch_field=$(get_yaml_field "$epic_fm" "branch")
    created_at=$(get_yaml_field "$epic_fm" "created_at")
    started_at=$(get_yaml_field "$epic_fm" "started_at"); [[ "$started_at" == "null" ]] && started_at=""
    EPIC_BODY="$epic_body"
    write_epic_file "$target_path" "$slug" "$title" "$branch_field" "closed" "$created_at" "$now" "" "" "$started_at"

    run_git_command "git add -A epics/" || return 1
    run_git_command "git commit -m \"[epic/close] Close epic ${slug}\"" || return 1

    if [[ "$no_push" != "true" ]]; then
        run_git_command "git push origin main" || echo "Warning: failed to push main" >&2
    fi

    echo "Epic ${slug} closed (main-direct)."
}

# Cancel, epic-branch case. Impl commits stay on the epic branch and are
# intentionally NOT merged into main; only the epic body lands on main with
# cancel metadata. Branch is then force-deleted.
_epic_cancel_epic_branch() {
    local slug="$1" epic_fm="$2" epic_body="$3" epic_branch="$4" now="$5" reason="$6" no_push="$7" no_delete_remote="$8"

    run_git_command "git switch main" || return 1

    local done_dir="epics/done/${slug}"
    mkdir -p "$done_dir"
    local target_path="${done_dir}/index.md"

    local title branch_field created_at started_at
    title=$(get_yaml_field "$epic_fm" "title")
    branch_field=$(get_yaml_field "$epic_fm" "branch")
    created_at=$(get_yaml_field "$epic_fm" "created_at")
    started_at=$(get_yaml_field "$epic_fm" "started_at"); [[ "$started_at" == "null" ]] && started_at=""
    EPIC_BODY="$epic_body"
    write_epic_file "$target_path" "$slug" "$title" "$branch_field" "cancelled" "$created_at" "" "$now" "$reason" "$started_at"

    # Best-effort: copy any other artefacts under epics/done/<slug>/ from the
    # epic branch (verification.md, screenshots/, etc.)
    local extra_path
    while IFS= read -r extra_path; do
        [[ -z "$extra_path" ]] && continue
        # Skip the index.md we just authored
        [[ "$extra_path" == "${done_dir}/index.md" ]] && continue
        local content
        content=$(git show "${epic_branch}:${extra_path}" 2>/dev/null) || continue
        local target_extra="${extra_path}"
        mkdir -p "$(dirname "$target_extra")"
        printf '%s' "$content" > "$target_extra"
    done < <(git ls-tree -r --name-only "$epic_branch" -- "$done_dir" 2>/dev/null || true)

    run_git_command "git add -A epics/" || return 1
    run_git_command "git commit -m \"[epic/cancel] Cancel epic ${slug}: ${reason}\"" || return 1

    if [[ "$no_push" != "true" ]]; then
        run_git_command "git push origin main" || echo "Warning: failed to push main" >&2
    fi

    run_git_command "git branch -D $epic_branch" || echo "Warning: failed to delete local branch $epic_branch" >&2

    if [[ "$no_push" != "true" ]] && [[ "$no_delete_remote" != "true" ]]; then
        if git ls-remote --heads origin "$epic_branch" 2>/dev/null | grep -q "$epic_branch"; then
            run_git_command "git push origin --delete $epic_branch" || echo "Warning: failed to delete remote branch" >&2
        fi
    fi

    echo "Epic ${slug} cancelled. main has cancel metadata; impl on ${epic_branch} discarded; branch deleted."
}

# Cancel, main-direct case.
_epic_cancel_main_direct() {
    local slug="$1" epic_fm="$2" epic_body="$3" now="$4" reason="$5" no_push="$6"

    run_git_command "git switch main" || return 1

    local done_dir="epics/done/${slug}"
    mkdir -p "$done_dir"
    local source_path="epics/${slug}.md"
    local target_path="${done_dir}/index.md"
    if [[ -f "$source_path" ]]; then
        run_git_command "git mv $source_path $target_path" || return 1
    fi

    local title branch_field created_at started_at
    title=$(get_yaml_field "$epic_fm" "title")
    branch_field=$(get_yaml_field "$epic_fm" "branch")
    created_at=$(get_yaml_field "$epic_fm" "created_at")
    started_at=$(get_yaml_field "$epic_fm" "started_at"); [[ "$started_at" == "null" ]] && started_at=""
    EPIC_BODY="$epic_body"
    write_epic_file "$target_path" "$slug" "$title" "$branch_field" "cancelled" "$created_at" "" "$now" "$reason" "$started_at"

    run_git_command "git add -A epics/" || return 1
    run_git_command "git commit -m \"[epic/cancel] Cancel epic ${slug}: ${reason}\"" || return 1

    if [[ "$no_push" != "true" ]]; then
        run_git_command "git push origin main" || echo "Warning: failed to push main" >&2
    fi

    echo "Epic ${slug} cancelled (main-direct)."
}

# Walk all known epic locations and emit one line per epic:
#   <origin>|<source_ref>|<path>|<slug>
# Origins: main (open, main:epics/<slug>.md), branch (open, refs/heads/epic/*),
#          done (closed/cancelled, main:epics/done/<slug>/index.md).
_epic_enumerate() {
    local seen_slugs=()
    local seen_set="|"

    # main:epics/*.md
    local p
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        [[ "$p" != epics/*.md ]] && continue
        [[ "$p" == epics/done/* ]] && continue
        local slug="${p#epics/}"; slug="${slug%.md}"
        [[ "$seen_set" == *"|main:${slug}|"* ]] && continue
        seen_set+="main:${slug}|"
        echo "main|main|${p}|${slug}"
    done < <(git ls-tree -r --name-only main 2>/dev/null | grep -E '^epics/[^/]+\.md$' || true)

    # refs/heads/epic/*:epics/*.md
    local branch
    while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue
        local p2
        while IFS= read -r p2; do
            [[ -z "$p2" ]] && continue
            [[ "$p2" != epics/*.md ]] && continue
            [[ "$p2" == epics/done/* ]] && continue
            local slug2="${p2#epics/}"; slug2="${slug2%.md}"
            [[ "$seen_set" == *"|${branch}:${slug2}|"* ]] && continue
            seen_set+="${branch}:${slug2}|"
            echo "branch|${branch}|${p2}|${slug2}"
        done < <(git ls-tree -r --name-only "$branch" 2>/dev/null | grep -E '^epics/[^/]+\.md$' || true)
    done < <(git for-each-ref --format='%(refname:short)' refs/heads/epic/ 2>/dev/null)

    # main:epics/done/*/index.md
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        [[ "$p" != epics/done/*/index.md ]] && continue
        local slug3="${p#epics/done/}"; slug3="${slug3%/index.md}"
        echo "done|main|${p}|${slug3}"
    done < <(git ls-tree -r --name-only main 2>/dev/null | grep -E '^epics/done/[^/]+/index\.md$' || true)
}

# Command: epic list [--status <s>] [--json]
cmd_epic_list() {
    local status_filter=""
    local as_json=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --status) status_filter="$2"; shift 2 ;;
            --json) as_json=true; shift ;;
            --*) echo "Error: Unknown option: $1" >&2; return 1 ;;
            *) echo "Error: Unexpected argument: $1" >&2; return 1 ;;
        esac
    done
    check_git_repo || return 1

    local rows=()
    local entry
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        local origin="${entry%%|*}"; local rest="${entry#*|}"
        local source_ref="${rest%%|*}"; rest="${rest#*|}"
        local path="${rest%%|*}"; local slug="${rest##*|}"
        local content
        content=$(git show "${source_ref}:${path}" 2>/dev/null) || continue
        local fm
        fm=$(epic_extract_frontmatter "$content")
        local title status branch created_at closed_at cancelled_at cancel_reason
        title=$(get_yaml_field "$fm" "title")
        status=$(get_yaml_field "$fm" "status")
        branch=$(get_yaml_field "$fm" "branch")
        created_at=$(get_yaml_field "$fm" "created_at")
        closed_at=$(get_yaml_field "$fm" "closed_at")
        cancelled_at=$(get_yaml_field "$fm" "cancelled_at")
        cancel_reason=$(get_yaml_field "$fm" "cancel_reason")
        [[ "$closed_at" == "null" ]] && closed_at=""
        [[ "$cancelled_at" == "null" ]] && cancelled_at=""
        [[ "$cancel_reason" == "null" ]] && cancel_reason=""

        if [[ -n "$status_filter" ]] && [[ "$status" != "$status_filter" ]]; then
            continue
        fi

        # Count linked tickets (working tree + epic branch if applicable)
        local total=0 open=0 closed=0
        local epic_b=""
        if [[ "$branch" != "main" ]] && git rev-parse --verify "refs/heads/${branch}" >/dev/null 2>&1; then
            epic_b="$branch"
        fi
        local L
        while IFS= read -r L; do
            [[ -z "$L" ]] && continue
            total=$((total + 1))
            if [[ "${L%%|*}" == "open" ]]; then
                open=$((open + 1))
            else
                closed=$((closed + 1))
            fi
        done < <(epic_find_linked_tickets "$slug" "$epic_b")

        rows+=("${slug}|${title}|${status}|${branch}|${created_at}|${closed_at}|${cancelled_at}|${cancel_reason}|${total}|${open}|${closed}")
    done < <(_epic_enumerate)

    if [[ "$as_json" == "true" ]]; then
        printf '['
        local i=0
        local row
        for row in ${rows[@]+"${rows[@]}"}; do
            [[ $i -gt 0 ]] && printf ','
            i=$((i + 1))
            local IFS='|'
            local arr=($row)
            local slug="${arr[0]}" title="${arr[1]}" status="${arr[2]}" branch="${arr[3]}"
            local created_at="${arr[4]}" closed_at="${arr[5]}" cancelled_at="${arr[6]}" cancel_reason="${arr[7]}"
            local total="${arr[8]}" open_c="${arr[9]}" closed_c="${arr[10]}"
            printf '{"epic_id":"%s","title":"%s","status":"%s","branch":"%s","created_at":"%s",' \
                "$(json_escape "$slug")" "$(json_escape "$title")" "$(json_escape "$status")" \
                "$(json_escape "$branch")" "$(json_escape "$created_at")"
            if [[ -n "$closed_at" ]]; then printf '"closed_at":"%s",' "$(json_escape "$closed_at")"; else printf '"closed_at":null,'; fi
            if [[ -n "$cancelled_at" ]]; then printf '"cancelled_at":"%s",' "$(json_escape "$cancelled_at")"; else printf '"cancelled_at":null,'; fi
            if [[ -n "$cancel_reason" ]]; then printf '"cancel_reason":"%s",' "$(json_escape "$cancel_reason")"; else printf '"cancel_reason":null,'; fi
            printf '"ticket_count":%s,"open_ticket_count":%s,"closed_ticket_count":%s}' "$total" "$open_c" "$closed_c"
        done
        printf ']\n'
    else
        printf '%-14s %-10s %-22s %5s %7s  %s\n' "SLUG" "STATUS" "BRANCH" "OPEN" "CLOSED" "TITLE"
        local row
        for row in ${rows[@]+"${rows[@]}"}; do
            local IFS='|'
            local arr=($row)
            printf '%-14s %-10s %-22s %5s %7s  %s\n' \
                "${arr[0]}" "${arr[2]}" "${arr[3]}" "${arr[9]}" "${arr[10]}" "${arr[1]}"
        done
    fi
}

# Command: epic show <slug> [--json]
cmd_epic_show() {
    local slug=""
    local as_json=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) as_json=true; shift ;;
            --*) echo "Error: Unknown option: $1" >&2; return 1 ;;
            *)
                if [[ -z "$slug" ]]; then slug="$1"; else echo "Error: Unexpected argument: $1" >&2; return 1; fi
                shift ;;
        esac
    done
    if [[ -z "$slug" ]]; then
        echo "Error: epic slug required" >&2
        return 1
    fi
    check_git_repo || return 1
    if ! resolve_epic "$slug"; then
        echo "Error: Epic '$slug' not found" >&2
        return 1
    fi

    local fm body
    fm=$(epic_extract_frontmatter "$EPIC_RAW")
    body=$(epic_extract_body "$EPIC_RAW")

    local title status branch created_at closed_at cancelled_at cancel_reason started_at
    title=$(get_yaml_field "$fm" "title")
    status=$(get_yaml_field "$fm" "status")
    branch=$(get_yaml_field "$fm" "branch")
    created_at=$(get_yaml_field "$fm" "created_at")
    closed_at=$(get_yaml_field "$fm" "closed_at"); [[ "$closed_at" == "null" ]] && closed_at=""
    cancelled_at=$(get_yaml_field "$fm" "cancelled_at"); [[ "$cancelled_at" == "null" ]] && cancelled_at=""
    cancel_reason=$(get_yaml_field "$fm" "cancel_reason"); [[ "$cancel_reason" == "null" ]] && cancel_reason=""
    started_at=$(get_yaml_field "$fm" "started_at"); [[ "$started_at" == "null" ]] && started_at=""

    # Linked tickets
    local epic_b=""
    if [[ "$branch" != "main" ]] && git rev-parse --verify "refs/heads/${branch}" >/dev/null 2>&1; then
        epic_b="$branch"
    fi
    local linked=()
    local L
    while IFS= read -r L; do
        [[ -z "$L" ]] && continue
        linked+=("$L")
    done < <(epic_find_linked_tickets "$slug" "$epic_b")

    # Branch state
    local has_branch_state=false head_sha="" ahead=0 behind=0
    if [[ -n "$epic_b" ]]; then
        has_branch_state=true
        head_sha=$(git rev-parse --short "$epic_b" 2>/dev/null || echo "")
        local counts
        counts=$(git rev-list --left-right --count "main...${epic_b}" 2>/dev/null || echo "0	0")
        behind="${counts%%	*}"
        ahead="${counts##*	}"
    fi

    if [[ "$as_json" == "true" ]]; then
        printf '{'
        printf '"epic_id":"%s",' "$(json_escape "$slug")"
        printf '"title":"%s",' "$(json_escape "$title")"
        printf '"status":"%s",' "$(json_escape "$status")"
        printf '"branch":"%s",' "$(json_escape "$branch")"
        printf '"created_at":"%s",' "$(json_escape "$created_at")"
        if [[ -n "$closed_at" ]]; then printf '"closed_at":"%s",' "$(json_escape "$closed_at")"; else printf '"closed_at":null,'; fi
        if [[ -n "$cancelled_at" ]]; then printf '"cancelled_at":"%s",' "$(json_escape "$cancelled_at")"; else printf '"cancelled_at":null,'; fi
        if [[ -n "$cancel_reason" ]]; then printf '"cancel_reason":"%s",' "$(json_escape "$cancel_reason")"; else printf '"cancel_reason":null,'; fi

        # epic_frontmatter (object)
        printf '"epic_frontmatter":{'
        local k v first=1
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*):[[:space:]]*(.*)$ ]]; then
                k="${BASH_REMATCH[1]}"
                v="${BASH_REMATCH[2]}"
                # Strip trailing inline comment
                if [[ "$v" =~ ^(.*[^[:space:]])[[:space:]]+#.*$ ]]; then v="${BASH_REMATCH[1]}"; fi
                # Trim trailing whitespace
                v="${v%"${v##*[![:space:]]}"}"
                # Strip surrounding quotes
                if [[ "$v" =~ ^\"(.*)\"[[:space:]]*$ ]]; then v="${BASH_REMATCH[1]}"; fi
                if [[ $first -eq 0 ]]; then printf ','; fi
                first=0
                if [[ "$v" == "null" ]]; then
                    printf '"%s":null' "$(json_escape "$k")"
                elif [[ "$v" =~ ^-?[0-9]+$ ]]; then
                    printf '"%s":%s' "$(json_escape "$k")" "$v"
                else
                    printf '"%s":"%s"' "$(json_escape "$k")" "$(json_escape "$v")"
                fi
            fi
        done <<< "$fm"
        printf '},'

        printf '"epic_body":"%s",' "$(json_escape "$body")"

        # linked_tickets array
        printf '"linked_tickets":['
        local i=0
        for L in ${linked[@]+"${linked[@]}"}; do
            local lstatus="${L%%|*}"
            local lloc="${L#*|}"; lloc="${lloc%|*}"
            local lpath="${L##*|}"
            local lcontent="" lfm=""
            if [[ "$lloc" == "working tree" ]]; then
                lcontent=$(cat "$lpath" 2>/dev/null || echo "")
            else
                lcontent=$(git show "${lloc}:${lpath}" 2>/dev/null || echo "")
            fi
            lfm=$(epic_extract_frontmatter "$lcontent")
            local lslug="${lpath##*/}"; lslug="${lslug%.md}"
            local ltitle ldesc lbase leid
            ltitle=$(get_yaml_field "$lfm" "title"); [[ -z "$ltitle" ]] && ltitle="$lslug"
            ldesc=$(get_yaml_field "$lfm" "description")
            lbase=$(get_yaml_field "$lfm" "base_branch")
            leid=$(get_yaml_field "$lfm" "epic_id")
            local lstatus_norm="open"
            if [[ "$lpath" == */done/* ]]; then lstatus_norm="done"; fi
            [[ $i -gt 0 ]] && printf ','
            i=$((i + 1))
            printf '{"slug":"%s","title":"%s","status":"%s","epic_id":"%s","base_branch":"%s","file_location":"%s"}' \
                "$(json_escape "$lslug")" "$(json_escape "$ltitle")" "$(json_escape "$lstatus_norm")" \
                "$(json_escape "$leid")" "$(json_escape "$lbase")" "$(json_escape "$lpath")"
        done
        printf '],'

        # branch_state
        if [[ "$has_branch_state" == "true" ]]; then
            printf '"branch_state":{"head_sha":"%s","ahead_of_main":%s,"behind_main":%s},' \
                "$(json_escape "$head_sha")" "$ahead" "$behind"
        else
            printf '"branch_state":null,'
        fi

        # preflight summary (just blocker check for show; not a full dry-run)
        local blockers_json=""
        if [[ "$status" == "open" ]]; then
            local n=0
            for L in ${linked[@]+"${linked[@]}"}; do
                if [[ "${L%%|*}" == "open" ]]; then n=$((n + 1)); fi
            done
            if [[ $n -gt 0 ]]; then
                blockers_json="\"Epic still has $n open ticket(s) linked to it\""
            fi
        fi
        if [[ -n "$blockers_json" ]]; then
            printf '"preflight":{"ok":false,"blockers":[%s]}' "$blockers_json"
        else
            printf '"preflight":{"ok":true,"blockers":[]}'
        fi

        printf '}\n'
    else
        echo "Epic: $slug"
        echo "  Title:     $title"
        echo "  Status:    $status"
        echo "  Branch:    $branch"
        echo "  Created:   $created_at"
        [[ -n "$started_at" ]] && echo "  Started:   $started_at"
        [[ -n "$closed_at" ]] && echo "  Closed:    $closed_at"
        [[ -n "$cancelled_at" ]] && echo "  Cancelled: $cancelled_at"
        [[ -n "$cancel_reason" ]] && echo "  Reason:    $cancel_reason"
        echo ""
        echo "Linked tickets: ${#linked[@]}"
        for L in ${linked[@]+"${linked[@]}"}; do
            local s="${L%%|*}" loc="${L#*|}"; loc="${loc%|*}"; local p="${L##*|}"
            echo "  [$s] $p ($loc)"
        done
        echo ""
        echo "--- body ---"
        printf '%s' "$body"
    fi
}

# Dispatcher: epic <action> [args...]
cmd_epic() {
    local action="${1:-}"; shift || true
    case "$action" in
        new) cmd_epic_new "$@" ;;
        close) cmd_epic_close "$@" ;;
        cancel) cmd_epic_cancel "$@" ;;
        list) cmd_epic_list "$@" ;;
        show) cmd_epic_show "$@" ;;
        ""|help|--help|-h)
            cat << EOF
Usage: $SCRIPT_COMMAND epic <action> [args]

Actions:
  new <slug> [--title <t>] [--branch epic/<slug>|--main-direct] [--from-ref <ref>]
      Create a new epic.
  close <slug> [--dry-run|-n] [--no-push] [--no-delete-remote] [--force|-f]
      Close an epic. Squash-merges epic branch into main (or edits in place
      for main-direct epics) and moves the file to epics/done/<slug>/index.md.
  cancel <slug> --reason "<text>" [--dry-run|-n] [--no-push] [--no-delete-remote] [--force|-f]
      Cancel an epic. Discards impl commits on the epic branch; only the epic
      body lands on main with cancel metadata.
  list [--status open|closed|cancelled] [--json]
      List epics.
  show <slug> [--json]
      Show one epic with linked tickets and branch state.

See gist 09b482ac for the full feature spec.
EOF
            ;;
        *)
            echo "Error: Unknown epic action: $action" >&2
            echo "Run '$SCRIPT_COMMAND epic help' for usage" >&2
            return 1 ;;
    esac
}

# Main command dispatcher
main() {
    case "${1:-}" in
        init)
            cmd_init
            ;;
        new)
            shift
            if [[ -z "${1:-}" ]]; then
                echo "Error: slug required" >&2
                echo "Usage: $SCRIPT_COMMAND new <slug> [--epic <epic-slug>]" >&2
                exit 1
            fi
            cmd_new "$@"
            ;;
        epic)
            shift
            cmd_epic "$@"
            ;;
        list)
            shift
            cmd_list "$@"
            ;;
        start)
            shift
            cmd_start "$@"
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
        cancel)
            shift
            cmd_cancel "$@"
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
