#!/usr/bin/env bash

cat > test-ml.yaml << 'EOF'
name: test
description: |
  Line 1
  Line 2
end: value
EOF

echo "=== AWK parsing test ==="
awk '
BEGIN {
    in_multiline = 0
    multiline_value = ""
    multiline_key = ""
}
{
    # Get original line with spaces
    original = $0
    
    # Calculate indent
    indent = 0
    if (match(original, /^[ ]+/)) {
        indent = RLENGTH
    }
    
    # Trim line
    line = original
    gsub(/^[ \t]+|[ \t]+$/, "", line)
    
    print "DEBUG: indent=" indent " in_multiline=" in_multiline " line=[" line "]"
    
    # In multiline mode
    if (in_multiline) {
        if (indent > base_indent || length(line) == 0) {
            # Part of multiline
            if (length(original) > base_indent) {
                content = substr(original, base_indent + 1)
            } else {
                content = ""
            }
            if (length(multiline_value) > 0) {
                multiline_value = multiline_value "\n" content
            } else {
                multiline_value = content
            }
            print "  -> Adding to multiline: [" content "]"
        } else {
            # End of multiline
            print "MULTILINE", multiline_key, multiline_value
            in_multiline = 0
            multiline_value = ""
            
            # Process this line normally
            if (match(line, /^([^:]+):(.*)$/)) {
                key = substr(line, 1, RSTART + RLENGTH - length($2) - 2)
                value = substr(line, RSTART + RLENGTH - length($2))
                gsub(/^[ \t]+|[ \t]+$/, "", value)
                print "KEY", key, value
            }
        }
    } else {
        # Normal processing
        if (match(line, /^([^:]+):(.*)$/)) {
            key = substr(line, 1, RSTART + RLENGTH - length($2) - 2)
            value = substr(line, RSTART + RLENGTH - length($2))
            gsub(/^[ \t]+|[ \t]+$/, "", value)
            
            if (value == "|") {
                print "  -> Starting multiline for key: " key
                in_multiline = 1
                multiline_key = key
                base_indent = indent  # Save current indent
                multiline_value = ""
            } else {
                print "KEY", key, value
            }
        }
    }
}
END {
    if (in_multiline && length(multiline_value) > 0) {
        print "MULTILINE", multiline_key, multiline_value
    }
}
' test-ml.yaml

rm -f test-ml.yaml