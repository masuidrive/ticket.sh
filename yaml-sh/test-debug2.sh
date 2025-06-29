#!/usr/bin/env bash

# Debug AWK parsing with hexdump

cat > test_debug2.yml << 'EOF'
name: test
tags:
  - parser
  - bash
  - yaml
EOF

echo "=== YAML content with visible whitespace ==="
cat test_debug2.yml | sed 's/ /·/g; s/\t/→/g'

echo -e "\n=== AWK debug output ==="
awk '
BEGIN {
    indent = 0
    in_multiline = 0
}

{
    # Save original line
    original = $0
    
    # Calculate indent
    match($0, /^[ \t]*/)
    indent = RLENGTH
    
    # Remove indent
    line = substr($0, indent + 1)
    
    print "DEBUG: indent=" indent " line=[" line "]"
    
    # List item
    if (match(line, /^- /)) {
        item = substr(line, 3)
        gsub(/^[ \t]+|[ \t]+$/, "", item)
        print "  -> LIST", indent, item
    }
    # Key-value pair
    else if (match(line, /^[^:]+:/)) {
        pos = index(line, ":")
        key = substr(line, 1, pos - 1)
        value = substr(line, pos + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", value)
        print "  -> KEY", indent, key, value
    }
}
' test_debug2.yml

rm -f test_debug2.yml