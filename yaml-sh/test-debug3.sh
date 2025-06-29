#!/usr/bin/env bash

# Debug yaml_parse function

source yaml-sh.sh

# Create test file
cat > test_debug3.yml << 'EOF'
name: test
tags:
  - parser
  - bash
colors: [red, green]
EOF

echo "=== AWK output ==="
_yaml_parse_awk "test_debug3.yml"

echo -e "\n=== Parsing and checking internal state ==="

# Clear existing state
_YAML_KEYS=()
_YAML_VALUES=()

# Add debug output to yaml_parse
yaml_parse "test_debug3.yml"

echo -e "\n=== Internal arrays after parsing ==="
echo "Number of keys: ${#_YAML_KEYS[@]}"
for i in "${!_YAML_KEYS[@]}"; do
    echo "[$i] key='${_YAML_KEYS[$i]}' value='${_YAML_VALUES[$i]}'"
done

rm -f test_debug3.yml