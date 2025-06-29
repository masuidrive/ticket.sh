#!/usr/bin/env bash

# Debug yaml-sh list parsing

source yaml-sh.sh

# Create test file
cat > test_debug.yml << 'EOF'
name: test
tags:
  - parser
  - bash
  - yaml
colors: [red, green, blue]
EOF

echo "=== Parsing YAML ==="
yaml_parse "test_debug.yml"

echo -e "\n=== All parsed keys ==="
yaml_keys

echo -e "\n=== Checking specific keys ==="
echo "tags: '$(yaml_get 'tags')'"
echo "tags.0: '$(yaml_get 'tags.0')'"
echo "tags.1: '$(yaml_get 'tags.1')'"
echo "tags.2: '$(yaml_get 'tags.2')'"

echo -e "\n=== List sizes ==="
echo "tags size: $(yaml_list_size 'tags')"
echo "colors size: $(yaml_list_size 'colors')"

echo -e "\n=== Raw AWK output ==="
_yaml_parse_awk "test_debug.yml" | head -20

# Cleanup
rm -f test_debug.yml