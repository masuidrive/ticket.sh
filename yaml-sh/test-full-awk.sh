#!/usr/bin/env bash

# Test full AWK function

source yaml-sh.sh

cat > test_full.yml << 'EOF'
tags:
  - parser
  - bash
EOF

echo "=== Full AWK function output ==="
_yaml_parse_awk "test_full.yml"

echo -e "\n=== Check if LIST lines are there ==="
_yaml_parse_awk "test_full.yml" | grep LIST

rm -f test_full.yml