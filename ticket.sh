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
# Version: 20250823.071009
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
# === Main Script ===


# Check if running with bash (POSIX compatible check)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script requires bash. Please run with 'bash ticket.sh' or make sure bash is your default shell."
    echo "Current shell: $0"
    exit 1
fi

# ticket.sh - Git-based Ticket Management System for Development
# Version: 20250823.071009
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
VERSION="20250823.071009"  # This will be replaced during build
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
    echo "3. Develop on feature branch"
    echo "4. Reference work files:"
    echo "   - \`current-ticket.md\` shows active ticket with tasks"
    echo "   - \`current-note.md\` for debugging logs and investigation notes (if configured)"
    echo ""
    echo "## Closing Tickets"
    echo ""
    echo "1. Before closing:"
    echo "   - Review \`current-ticket.md\` content and description"
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
    if ! cat > "$ticket_file" << EOF
---
priority: 2
description: ""
created_at: "$timestamp"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
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
        
        # Create note symlink if note file exists
        local note_file="${tickets_dir}/${ticket_name}-note.md"
        if [[ -f "$note_file" ]]; then
            rm -f "$CURRENT_NOTE_LINK"
            ln -s "$note_file" "$CURRENT_NOTE_LINK"
            echo "Resumed ticket: $ticket_name"
            echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
            echo "Current note linked: $CURRENT_NOTE_LINK -> $note_file"
        else
            rm -f "$CURRENT_NOTE_LINK"  # Clean up any old note link
            echo "Resumed ticket: $ticket_name"
            echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
        fi
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
    
    # Create note symlink if note file exists
    local note_file="${tickets_dir}/${ticket_name}-note.md"
    if [[ -f "$note_file" ]]; then
        rm -f "$CURRENT_NOTE_LINK"
        ln -s "$note_file" "$CURRENT_NOTE_LINK"
        echo "Started ticket: $ticket_name"
        echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
        echo "Current note linked: $CURRENT_NOTE_LINK -> $note_file"
    else
        rm -f "$CURRENT_NOTE_LINK"  # Clean up any old note link
        echo "Started ticket: $ticket_name"
        echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
    fi
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
        ln -s "$note_file" "$CURRENT_NOTE_LINK"
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
        
        # Move note file if it exists
        local note_file="${tickets_dir}/${ticket_name}-note.md"
        if [[ -f "$note_file" ]]; then
            local new_note_path="${done_dir}/$(basename "$note_file")"
            run_git_command "git mv \"$note_file\" \"$new_note_path\"" || {
                echo "Warning: Failed to move note to done folder" >&2
            }
        fi
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
3. Develop on feature branch
4. Reference work files:
   - `current-ticket.md` shows active ticket with tasks
   - `current-note.md` for debugging logs and investigation notes (if configured)

## Closing Tickets

1. Before closing:
   - Review `current-ticket.md` content and description
   - Check all tasks in checklist are completed (mark with `[x]`)
   - Commit all your work: `git add . && git commit -m "your message"`
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
