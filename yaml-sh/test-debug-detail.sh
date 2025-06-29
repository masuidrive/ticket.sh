#!/usr/bin/env bash

# Detailed debug of list parsing

source yaml-sh.sh

# Create test file
cat > test_debug_detail.yml << 'EOF'
tags:
  - parser
  - bash
EOF

echo "=== AWK output ==="
_yaml_parse_awk "test_debug_detail.yml" | cat -n

echo -e "\n=== Parse with debug ==="
# Temporarily modify yaml_parse to add debug output
yaml_parse_debug() {
    local file="$1"
    local current_path=""
    local list_index=0
    local in_list=0
    local reading_multiline=0
    local multiline_value=""
    
    # Clear previous data
    _YAML_KEYS=()
    _YAML_VALUES=()
    
    while IFS='' read -r line; do
        echo "DEBUG: Processing line: $line"
        
        # Parse the line
        local type=$(echo "$line" | awk '{print $1}')
        local indent=$(echo "$line" | awk '{print $2}')
        local key=$(echo "$line" | awk '{print $3}')
        local value=$(echo "$line" | cut -d' ' -f4-)
        
        echo "  type=$type, indent=$indent, key=$key, value=$value"
        echo "  current_path=$current_path, in_list=$in_list, list_index=$list_index"
        
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
                echo "  -> Set current_path=$current_path, in_list=$in_list"
                ;;
                
            LIST)
                if [[ $in_list -eq 0 ]]; then
                    list_index=0
                    in_list=1
                else
                    ((list_index++))
                fi
                local full_key="${current_path}.${list_index}"
                _YAML_KEYS+=("$full_key")
                _YAML_VALUES+=("$key")  # key contains the list item
                echo "  -> Added key=$full_key, value=$key, list_index=$list_index"
                ;;
        esac
        echo
    done < <(_yaml_parse_awk "$file")
}

yaml_parse_debug "test_debug_detail.yml"

echo -e "\n=== Final state ==="
echo "Number of keys: ${#_YAML_KEYS[@]}"
for i in "${!_YAML_KEYS[@]}"; do
    echo "[$i] key='${_YAML_KEYS[$i]}' value='${_YAML_VALUES[$i]}'"
done

# Cleanup
rm -f test_debug_detail.yml