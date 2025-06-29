#!/usr/bin/env bash

# Test AWK parsing directly

cat > test_awk.yml << 'EOF'
tags:
  - parser
  - bash
EOF

echo "=== File content with visible spaces ==="
cat test_awk.yml | sed 's/ /·/g'

echo -e "\n=== Test AWK line by line ==="
awk '
{
    # Save original line
    original = $0
    
    # Calculate indent  
    match($0, /^[ \t]*/)
    indent = RLENGTH
    
    # Remove leading/trailing whitespace
    line = $0
    gsub(/^[ \t]+/, "", line)
    gsub(/[ \t]+$/, "", line)
    
    print "Line " NR ": original=[" original "]"
    print "  indent=" indent ", line=[" line "]"
    
    # List item check
    if (match(line, /^- /)) {
        item = substr(line, 3)
        gsub(/^[ \t]+|[ \t]+$/, "", item)
        print "  -> Found LIST item: [" item "]"
    }
    # Key-value check
    else if (match(line, /^[^:]+:/)) {
        pos = index(line, ":")
        key = substr(line, 1, pos - 1)
        value = substr(line, pos + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", value)
        print "  -> Found KEY: [" key "] = [" value "]"
    }
}
' test_awk.yml

rm -f test_awk.yml