#!/usr/bin/env bash

# Test the fixed yaml-sh

source yaml-sh-fixed.sh

# Create test file
cat > test_fixed.yml << 'EOF'
name: test
tags:
  - parser
  - bash
  - yaml
colors: [red, green, blue]
numbers:
  - 1
  - 2
EOF

echo "=== Parsing YAML ==="
yaml_parse "test_fixed.yml"

echo -e "\n=== All parsed keys ==="
yaml_keys

echo -e "\n=== Test dash lists ==="
echo "tags size: $(yaml_list_size 'tags')"
echo "tags.0: '$(yaml_get 'tags.0')'"
echo "tags.1: '$(yaml_get 'tags.1')'"
echo "tags.2: '$(yaml_get 'tags.2')'"

echo -e "\n=== Test inline lists ==="
echo "colors size: $(yaml_list_size 'colors')"
echo "colors.0: '$(yaml_get 'colors.0')'"
echo "colors.1: '$(yaml_get 'colors.1')'"
echo "colors.2: '$(yaml_get 'colors.2')'"

echo -e "\n=== Test second dash list ==="
echo "numbers size: $(yaml_list_size 'numbers')"
echo "numbers.0: '$(yaml_get 'numbers.0')'"
echo "numbers.1: '$(yaml_get 'numbers.1')'"

# Cleanup
rm -f test_fixed.yml