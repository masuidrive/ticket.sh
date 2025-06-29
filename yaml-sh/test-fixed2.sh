#!/usr/bin/env bash

# Test the fixed yaml-sh with more debug

source yaml-sh-fixed.sh

# Create test file
cat > test_fixed2.yml << 'EOF'
name: test
tags:
  - parser
EOF

echo "=== AWK output directly ==="
_yaml_parse_awk "test_fixed2.yml"

echo -e "\n=== Now test parsing ==="
yaml_parse "test_fixed2.yml" || echo "Parse failed with code: $?"

echo -e "\n=== Keys found ==="
echo "Number of keys: ${#_YAML_KEYS[@]}"

# Cleanup
rm -f test_fixed2.yml