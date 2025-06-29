#!/usr/bin/env bash

# yaml-sh: A pure Bash YAML parser (v2)
# Version: 2.0.0
# Requirements: Bash 3.2+ (macOS compatible)

# Global variables - Using parallel arrays instead of associative arrays
_YAML_KEYS=()
_YAML_VALUES=()
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
        gsub(/#.*$/, "", line)
        
        # Trim
        gsub(/^[ \t]+|[ \t]+$/, "", line)
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
    
    # List item
    match(line, /^- /) {
        item = substr(line, 3)
        gsub(/^[ \t]+|[ \t]+$/, "", item)
        print "LIST", indent, item
        next
    }
    
    # Key-value pair
    match(line, /^[^:]+:/) {
        # Split key and value
        pos = index(line, ":")
        key = substr(line, 1, pos - 1)
        value = substr(line, pos + 1)
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
                # Remove quotes
                gsub(/^["'\'']|["'\'']$/, "", item)
                print "ILIST", indent, item
            }
        }
        # Normal value
        else {
            # Remove quotes
            gsub(/^["'\'']|["'\'']$/, "", value)
            print "KEY", indent, key, value
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
                current_path="$key"
                if [[ -n "$value" ]]; then
                    _YAML_KEYS+=("$current_path")
                    _YAML_VALUES+=("$value")
                fi
                in_list=0
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
    done < <(_yaml_parse_awk "$file")
    
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
}

# Get all keys
yaml_keys() {
    printf '%s\n' "${_YAML_KEYS[@]}"
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

# Get list size
yaml_list_size() {
    local prefix="$1"
    local count=0
    
    while yaml_has_key "${prefix}.${count}"; do
        ((count++))
    done
    
    echo "$count"
}

# Dump all data
yaml_dump() {
    local i=0
    local len=${#_YAML_KEYS[@]}
    
    while [[ $i -lt $len ]]; do
        printf '%s=%s\n' "${_YAML_KEYS[$i]}" "${_YAML_VALUES[$i]}"
        ((i++))
    done
}

# Clear data
yaml_clear() {
    _YAML_KEYS=()
    _YAML_VALUES=()
    _YAML_CURRENT_FILE=""
}