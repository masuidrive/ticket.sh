#!/usr/bin/env bash

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
    done < "$file"
    
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
    done < "$file"
    
    if [[ $field_updated -eq 0 ]]; then
        echo "Error: Field '$field' not found in frontmatter" >&2
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