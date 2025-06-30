#!/usr/bin/env bash

# IMPORTANT NOTE: This file is generated from source files. DO NOT EDIT DIRECTLY!
# To make changes, edit the source files in src/ directory and run ./build.sh
# Source file: src/ticket.sh

# ticket.sh - Git-based Ticket Management System for Development
# Version: 1.0.0
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
    
    while IFS='' read -r line; do
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
                    ((list_index++))
                fi
                _YAML_KEYS+=("${current_path}.${list_index}")
                _YAML_VALUES+=("$key")  # key contains the list item
                ;;
                
            ILIST)
                if [[ $in_list -eq 0 ]]; then
                    list_index=0
                    in_list=1
                else
                    ((list_index++))
                fi
                _YAML_KEYS+=("${current_path}.${list_index}")
                _YAML_VALUES+=("$key")  # key contains the list item
                ;;
        esac
    done < <(_yaml_parse_awk "$file") || true
    
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
        ((i++))
    done
    
    return 1
}

# List all keys
yaml_keys() {
    local i=0
    local len=${#_YAML_KEYS[@]}
    
    while [[ $i -lt $len ]]; do
        echo "${_YAML_KEYS[$i]}"
        ((i++))
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
        ((i++))
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
        ((i++))
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
        
        ((i++))
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
    if [[ ! -f .ticket-config.yml ]]; then
        cat >&2 << EOF
Error: Ticket system not initialized
Configuration file '.ticket-config.yml' not found. Please:
1. Run 'ticket.sh init' to initialize the ticket system, or
2. Navigate to the project root directory where the config exists
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
    git rev-parse --abbrev-ref HEAD 2>/dev/null
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
# === Main Script ===


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
#   ./ticket.sh init          # Initialize in your project
#   ./ticket.sh new my-task   # Create a new ticket
#   ./ticket.sh start <name>  # Start working on a ticket
#   ./ticket.sh close         # Complete and merge ticket

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
...
- [ ] Get developer approval before closing


## Notes

Additional notes or requirements.'

# Show usage information
show_usage() {
    cat << 'EOF'
# Ticket Management System for Coding Agents

## Overview

This is a self-contained ticket management system using shell script + files + Git.
Each ticket is a single Markdown file with YAML frontmatter metadata.

## Usage

- `./ticket.sh init` - Initialize system (create config, directories, .gitignore)
- `./ticket.sh new <slug>` - Create new ticket file (slug: lowercase, numbers, hyphens only)
- `./ticket.sh list [--status STATUS] [--count N]` - List tickets (default: todo + doing, count: 20)
- `./ticket.sh start <ticket-name>` - Start working on ticket (creates feature branch locally)
- `./ticket.sh restore` - Restore current-ticket.md symlink from branch name
- `./ticket.sh close [--no-push] [--force|-f]` - Complete current ticket (squash merge to default branch)

## Ticket Naming

- Format: `YYMMDD-hhmmss-<slug>`
- Example: `241225-143502-implement-user-auth`
- Generated automatically when creating tickets

## Ticket Status

- `todo`: not started (started_at: null)
- `doing`: in progress (started_at set, closed_at: null)
- `done`: completed (closed_at set)

## Configuration

- Config file: `.ticket-config.yml` (in project root)
- Initialize with: `./ticket.sh init`
- Edit to customize directories, branches, and templates

## Push Control

- Set `auto_push: false` in config to disable automatic pushing for close command
- Use `--no-push` flag with close command to skip pushing
- Feature branches are always created locally (no auto-push on start)
- Git commands and outputs are displayed for transparency

## Workflow

### Create New Ticket

1. Create ticket: `./ticket.sh new feature-name`
2. Edit ticket content and description in the generated file

### Start Work

1. Check available tickets: `./ticket.sh list` or browse tickets directory
2. Start work: `./ticket.sh start 241225-143502-feature-name`
3. Develop on feature branch (`current-ticket.md` shows active ticket)

### Closing

1. Before closing:
   - Review ticket content and description
   - Check all tasks in checklist are completed (mark with `[x]`)
   - Get user approve before proceeding
2. Complete: `./ticket.sh close`

**Note**: If specific workflow instructions are provided elsewhere (e.g., in project documentation or CLAUDE.md), those take precedence over this general workflow.

## Troubleshooting

- Run from project root (where `.git` and `.ticket-config.yml` exist)
- Use `restore` if `current-ticket.md` is missing after clone/pull
- Check `list` to see available tickets and their status
- Ensure Git working directory is clean before start/close

**Note**: `current-ticket.md` is git-ignored and needs `restore` after clone/pull.
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
    
    # Check if already initialized
    local already_initialized=true
    [[ ! -f "$CONFIG_FILE" ]] && already_initialized=false
    [[ ! -d "${DEFAULT_TICKETS_DIR}" ]] && already_initialized=false
    
    if [[ "$already_initialized" == "true" ]]; then
        echo "Ticket system is already initialized!"
        echo ""
        echo "For help and usage information, run:"
        echo "  ./ticket.sh help"
        echo ""
        echo "Quick reference:"
        echo "  - Create a ticket: './ticket.sh new <slug>'"
        echo "  - List tickets: './ticket.sh list'"
        echo "  - Start work: './ticket.sh start <ticket-name>'"
        echo "  - Complete: './ticket.sh close'"
        return 0
    fi
    
    echo "Initializing ticket system..."
    
    # Create config file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
# Ticket system configuration

# Directory settings
tickets_dir: "$DEFAULT_TICKETS_DIR"

# Git settings
default_branch: "$default_branch_value"
branch_prefix: "$DEFAULT_BRANCH_PREFIX"
repository: "$DEFAULT_REPOSITORY"
auto_push: $DEFAULT_AUTO_PUSH

# Ticket template
default_content: |
  # Ticket Overview
  
  Write the overview and tasks for this ticket here.
  
  
  ## Tasks
  
  - [ ] Task 1
  - [ ] Task 2
  ...
  - [ ] Get developer approval before closing
  

  ## Notes
  
  Additional notes or requirements.
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
    echo "Ticket system initialized successfully!"
    echo ""
    echo "The setup is not yet complete. Please ensure that you and your users follow the steps below. It is your mission."
    echo ""
    echo "## Next Steps:"
    echo ""
    echo "1. **Configure your ticket system** (optional):"
    echo "   Edit '.ticket-config.yml' to customize:"
    echo "   - tickets_dir: Where tickets are stored (default: \"tickets\")"
    echo "   - default_branch: Main development branch (default: \"develop\")"
    echo "   - branch_prefix: Feature branch naming (default: \"feature/\")"
    echo "   - auto_push: Push on close (default: true)"
    echo "   - default_content: Template for new tickets"
    echo ""
    echo "2. **Present the following instructions to the developer without modification,"
    echo "   and tell them to add it to their coding agent's custom prompt:**"
    echo ""
    echo "\`\`\`markdown"
    echo "# Ticket Management Instructions"
    echo ""
    echo "Use \`./ticket.sh\` for ticket management."
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
    echo "1. Create ticket: \`./ticket.sh new feature-name\`"
    echo "2. Edit ticket content and description in the generated file"
    echo ""
    echo "## Start Working on Ticket"
    echo ""
    echo "1. Check available tickets: \`./ticket.sh\` list or browse tickets directory"
    echo "2. Start work: \`./ticket.sh start 241225-143502-feature-name\`"
    echo "3. Develop on feature branch (\`current-ticket.md\` shows active ticket)"
    echo ""
    echo "## Closing Tickets"
    echo ""
    echo "1. Before closing:"
    echo "   - Review \`current-ticket.md\` content and description"
    echo "   - Check all tasks in checklist are completed (mark with \`[x]\`)"
    echo "   - Get user approval before proceeding"
    echo "2. Complete: \`./ticket.sh close\`"
    echo "\`\`\`"
    echo ""
    echo "   **Note**: These instructions are critical for proper ticket workflow!"
    echo ""
    echo "3. **Quick start**:"
    echo "   - Create a ticket: \`./ticket.sh new <slug>\`"
    echo "   - List tickets: \`./ticket.sh list\`"
    echo "   - Start work: \`./ticket.sh start <ticket-name>\`"
    echo "   - Complete: \`./ticket.sh close\`"
    echo ""
    echo "For detailed help: \`./ticket.sh help\`"
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
    local sorted_file=$(mktemp)
    sort -t'|' -k1,1 -k2,2n "$temp_file" | sed 's/^doing|/0|/; s/^todo|/1|/; s/^done|/2|/' | sort -t'|' -k1,1n -k2,2n | sed 's/^0|/doing|/; s/^1|/todo|/; s/^2|/done|/' > "$sorted_file"
    
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
    echo "$yaml_content" >| /tmp/ticket_yaml.yml
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
    
    # Create symlink
    rm -f "$CURRENT_TICKET_LINK"
    ln -s "$ticket_file" "$CURRENT_TICKET_LINK"
    
    echo "Started ticket: $ticket_name"
    echo "Current ticket linked: $CURRENT_TICKET_LINK -> $ticket_file"
    echo "Note: Branch created locally. Use 'git push -u $repository $branch_name' when ready to share."
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
}

# Close current ticket
cmd_close() {
    local no_push=false
    local force=false
    
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
            *)
                echo "Error: Unknown option: $1" >&2
                echo "Usage: ticket.sh close [--no-push] [--force|-f]" >&2
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
  ticket.sh close --force (or -f)

Or handle the changes:
  1. Commit your changes: git add . && git commit -m "message"
  2. Stash changes: git stash

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
    
    # Move ticket to done folder
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
        
        # Commit the move
        run_git_command "git commit -m \"Move completed ticket to done folder\"" || {
            echo "Warning: Failed to commit ticket move" >&2
        }
        
        # Push the move if auto_push
        if [[ "$auto_push" == "true" ]] && [[ "$no_push" == "false" ]]; then
            run_git_command "git push $repository $default_branch" || {
                echo "Warning: Failed to push ticket move to remote" >&2
            }
        fi
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
                echo "Usage: ticket.sh start <ticket-name>" >&2
                exit 1
            fi
            cmd_start "$2"
            ;;
        restore)
            cmd_restore
            ;;
        close)
            shift
            cmd_close "$@"
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
