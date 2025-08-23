#!/usr/bin/env bash

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