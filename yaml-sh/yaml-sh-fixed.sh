#!/usr/bin/env bash

# yaml-sh: A simple YAML parser for Bash 3.2+
# Version: 2.0.1-fixed
# Usage: source yaml-sh.sh
#
# Supported YAML syntax:
# - Key-value pairs: key: value
# - Lists with dash notation: - item
# - Inline lists: [item1, item2, item3]
# - Multiline strings: | (literal) and > (folded)
# - Comments: # comment
# - Nested structures via indentation

# Global arrays to store parsed data
declare -a _YAML_KEYS
declare -a _YAML_VALUES

# AWK script for parsing YAML
_yaml_parse_awk() {
    local file="$1"
    awk '
    BEGIN {
        indent = 0
        in_multiline = 0
        multiline_value = ""
        multiline_key = ""
        multiline_type = ""
        multiline_base_indent = -1
        key_indent = 0
    }
    
    # Skip comments and empty lines at file start
    NR == 1 && /^(#|$)/ { next }
    
    # Handle document markers
    /^---$/ { next }
    /^\\.\\.\\.$/ { next }
    
    {
        # Save original line with spaces
        original = $0
        
        # Calculate indent
        match($0, /^[ \\t]*/)
        indent = RLENGTH
        
        # Remove leading/trailing whitespace
        line = $0
        gsub(/^[ \\t]+/, "", line)
        gsub(/[ \\t]+$/, "", line)
        
        # Remove comments (but not in strings)
        if (!in_multiline) {
            # Handle comments outside of quotes
            if (match(line, /^[^"'"'"']*#/)) {
                comment_pos = RSTART + RLENGTH - 1
                # Check if # is inside quotes
                before_comment = substr(line, 1, comment_pos - 1)
                single_quotes = gsub(/'"'"'/, "", before_comment)
                double_quotes = gsub(/"/, "", before_comment)
                if (single_quotes % 2 == 0 && double_quotes % 2 == 0) {
                    line = substr(line, 1, comment_pos - 1)
                    gsub(/[ \\t]+$/, "", line)
                }
            }
        }
        
        # In multiline mode
        if (in_multiline) {
            # First line of multiline sets the base indent
            if (multiline_base_indent == -1 && length(line) > 0) {
                multiline_base_indent = indent
            }
            
            # Check if we'"'"'re back to the original indent level or less
            if (length(line) > 0 && indent <= key_indent) {
                # Process collected multiline
                if (multiline_type == "|" || multiline_type == "|-" || multiline_type == "|+") {
                    # Literal: preserve newlines
                    if (multiline_type == "|-") {
                        # Strip final newline
                        sub(/\\n$/, "", multiline_value)
                    } else if (multiline_type == "|+") {
                        # Keep final newlines (default behavior)
                    }
                } else if (multiline_type == ">" || multiline_type == ">-" || multiline_type == ">+") {
                    # Folded: replace newlines with spaces
                    gsub(/\\n/, " ", multiline_value)
                    if (multiline_type == ">-") {
                        # Strip final newline
                        sub(/ $/, "", multiline_value)
                    }
                }
                
                # For literal blocks, ensure exactly one trailing newline
                if (multiline_type == "|") {
                    # Remove all trailing newlines first
                    gsub(/\\n+$/, "", multiline_value)
                    # Add exactly one
                    multiline_value = multiline_value "\\n"
                }
                
                # Output the multiline value
                print "VALUE", key_indent, multiline_key, multiline_value
                in_multiline = 0
                multiline_value = ""
                multiline_base_indent = -1
                # Fall through to process current line
            } else if (length(original) > 0 || multiline_type ~ /\|/) {
                # For literal style, preserve empty lines
                # For folded style, skip empty lines
                if (length(line) > 0) {
                    # Remove the base indent from each line
                    content_indent = indent - multiline_base_indent
                    if (content_indent < 0) content_indent = 0
                    spaces = sprintf("%*s", content_indent, "")
                    line_content = spaces line
                } else {
                    line_content = ""
                }
                
                if (multiline_value == "") {
                    multiline_value = line_content
                } else {
                    multiline_value = multiline_value "\\n" line_content
                }
                next
            } else {
                # Empty line in folded style - skip
                next
            }
        }
        
        # Handle multiline end detection first
        if (in_multiline && length(line) > 0 && indent <= key_indent) {
            # Output collected multiline
            if (multiline_type == "|") {
                # Ensure exactly one trailing newline
                sub(/\\n*$/, "\\n", multiline_value)
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
        gsub(/^[ \\t]+|[ \\t]+$/, "", item)
        print "LIST", indent, item
        next
    }
    
    # Key-value pair
    match(line, /^[^:]+:/) {
        # Split key and value
        pos = index(line, ":")
        key = substr(line, 1, pos - 1)
        value = substr(line, pos + 1)
        gsub(/^[ \\t]+|[ \\t]+$/, "", value)
        
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
        else if (match(value, /^\\[.*\\]$/)) {
            print "KEY", indent, key, ""
            # Remove brackets
            value = substr(value, 2, length(value) - 2)
            # Split by comma
            n = split(value, items, ",")
            for (i = 1; i <= n; i++) {
                item = items[i]
                gsub(/^[ \\t]+|[ \\t]+$/, "", item)
                # Remove quotes if present
                if (match(item, /^".*"$/) || match(item, /^'"'"'.*'"'"'$/)) {
                    item = substr(item, 2, length(item) - 2)
                }
                print "ILIST", indent, item
            }
        }
        # Regular value
        else {
            # Remove quotes if present
            if (match(value, /^".*"$/) || match(value, /^'"'"'.*'"'"'$/)) {
                value = substr(value, 2, length(value) - 2)
            }
            print "KEY", indent, key, value
        }
        next
    }
    
    END {
        # Output any remaining multiline content
        if (in_multiline) {
            if (multiline_type == "|") {
                # Ensure exactly one trailing newline
                sub(/\\n*$/, "\\n", multiline_value)
            }
            print "VALUE", key_indent, multiline_key, multiline_value
        }
    }
    ' "$file"
}

# Parse a YAML file
yaml_parse() {
    local file="$1"
    local current_path=""
    local list_index=0
    local in_list=0
    local reading_multiline=0
    local multiline_value=""
    local current_list_key=""
    local last_key_indent=0
    
    # Clear previous data
    _YAML_KEYS=()
    _YAML_VALUES=()
    
    # Check if file exists
    [[ -f "$file" ]] || return 1
    
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
                # Check if we need to reset list state based on indent
                if [[ $in_list -eq 1 ]] && [[ $indent -le $last_key_indent ]]; then
                    in_list=0
                fi
                
                current_path="$key"
                last_key_indent=$indent
                
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
                if [[ $in_list -eq 0 ]] || [[ "$current_list_key" != "$current_path" ]]; then
                    list_index=0
                    in_list=1
                    current_list_key="$current_path"
                else
                    ((list_index++))
                fi
                _YAML_KEYS+=("${current_path}.${list_index}")
                _YAML_VALUES+=("$key")  # key contains the list item
                ;;
                
            ILIST)
                if [[ $in_list -eq 0 ]] || [[ "$current_list_key" != "$current_path" ]]; then
                    list_index=0
                    in_list=1
                    current_list_key="$current_path"
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

# Update a value in a YAML file
yaml_update() {
    local file="$1"
    local key="$2"
    local new_value="$3"
    
    # Check if file exists
    [[ -f "$file" ]] || return 1
    
    # Create a temporary file
    local temp_file=$(mktemp)
    local found=0
    local in_multiline=0
    local multiline_indent=0
    
    while IFS= read -r line; do
        # Check if we're in a multiline block that needs to be skipped
        if [[ $in_multiline -eq 1 ]]; then
            # Check indent to see if multiline block ended
            if [[ "$line" =~ ^[[:space:]]* ]]; then
                local current_indent=${#BASH_REMATCH[0]}
                if [[ $current_indent -le $multiline_indent ]]; then
                    in_multiline=0
                else
                    # Skip this line (part of old multiline value)
                    continue
                fi
            else
                # Non-indented line means multiline ended
                in_multiline=0
            fi
        fi
        
        # Check if this line contains our key
        if [[ "$line" =~ ^([[:space:]]*)${key}:[[:space:]]*(.*)$ ]]; then
            local indent="${BASH_REMATCH[1]}"
            local current_value="${BASH_REMATCH[2]}"
            
            # Check if current value is a multiline indicator
            if [[ "$current_value" =~ ^[|>][-+]?$ ]]; then
                in_multiline=1
                multiline_indent=${#indent}
            fi
            
            # Write updated line
            echo "${indent}${key}: ${new_value}" >> "$temp_file"
            found=1
        else
            # Write original line
            echo "$line" >> "$temp_file"
        fi
    done < "$file"
    
    if [[ $found -eq 1 ]]; then
        mv "$temp_file" "$file"
        return 0
    else
        rm "$temp_file"
        return 1
    fi
}

# Load YAML data into environment variables
yaml_load() {
    local file="$1"
    local prefix="${2:-}"
    
    yaml_parse "$file" || return 1
    
    local i=0
    local len=${#_YAML_KEYS[@]}
    
    while [[ $i -lt $len ]]; do
        local key="${_YAML_KEYS[$i]}"
        local value="${_YAML_VALUES[$i]}"
        
        # Convert key to valid variable name
        local var_name="${key//[.-]/_}"
        var_name="${var_name//[^a-zA-Z0-9_]/_}"
        
        if [[ -n "$prefix" ]]; then
            var_name="${prefix}_${var_name}"
        fi
        
        # Export the variable
        export "$var_name=$value"
        
        ((i++))
    done
    
    return 0
}