#!/usr/bin/env bash

# Build script for ticket.sh
# Combines all source files into a single executable

set -euo pipefail

# Configuration
OUTPUT_FILE="ticket.sh"
SRC_DIR="src"
LIB_DIR="lib"

echo "Building $OUTPUT_FILE..."

# Create output file with shebang
cat > "$OUTPUT_FILE" << 'EOF'
#!/usr/bin/env bash

# ticket.sh - Ticket Management System for Coding Agents
# Version: 1.0.0
# Built from source files

set -euo pipefail

EOF

# Inline library files (excluding shebang and source statements)
echo "# === Inlined Libraries ===" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Process yaml-sh.sh
echo "# --- yaml-sh.sh ---" >> "$OUTPUT_FILE"
tail -n +2 "$LIB_DIR/yaml-sh.sh" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Process yaml-frontmatter.sh
echo "# --- yaml-frontmatter.sh ---" >> "$OUTPUT_FILE"
tail -n +2 "$LIB_DIR/yaml-frontmatter.sh" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Process utils.sh
echo "# --- utils.sh ---" >> "$OUTPUT_FILE"
tail -n +2 "$LIB_DIR/utils.sh" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Process main script (excluding shebang and source statements)
echo "# === Main Script ===" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Remove shebang, source statements, and SCRIPT_DIR references
tail -n +2 "$SRC_DIR/ticket.sh" | \
    grep -v '^source.*lib/' | \
    grep -v '^SCRIPT_DIR=' | \
    cat >> "$OUTPUT_FILE"

# Make executable
chmod +x "$OUTPUT_FILE"

echo "Build complete: $OUTPUT_FILE"
echo "File size: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"
echo ""
echo "You can now use: ./$OUTPUT_FILE"