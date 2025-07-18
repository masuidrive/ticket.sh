#!/usr/bin/env bash

# Build script for ticket.sh
# Combines all source files into a single executable

set -euo pipefail

# Configuration
OUTPUT_FILE="ticket.sh"
SRC_DIR="src"
LIB_DIR="lib"

# Generate version number from current timestamp (YYYYMMDD.HHMMSS)
VERSION=$(date -u '+%Y%m%d.%H%M%S')

echo "Building $OUTPUT_FILE..."
echo "Version: $VERSION"

# Create output file with shebang and header from source
cat > "$OUTPUT_FILE" << EOF
#!/usr/bin/env bash

# Early bash check (POSIX compatible)
if [ -z "\${BASH_VERSION}" ]; then
    echo "Error: This script requires bash. Please run with 'bash ticket.sh' or make sure bash is your default shell."
    echo "Current shell: \$0"
    exit 1
fi

# IMPORTANT NOTE: This file is generated from source files. DO NOT EDIT DIRECTLY!
# To make changes, edit the source files in src/ directory and run ./build.sh
# Source file: src/ticket.sh

# ticket.sh - Git-based Ticket Management System for Development
# Version: $VERSION
# Built from source files
#
# A lightweight ticket management system that uses Git branches and Markdown files.
# Perfect for small teams, solo developers, and AI coding assistants.
#
# Features:
#   - Each ticket is a Markdown file with YAML frontmatter
#   - Automatic Git branch creation/management per ticket
#   - Simple CLI interface for common workflows
#   - No external dependencies (pure Bash + Git)
#
# For detailed documentation, installation instructions, and examples:
# https://github.com/masuidrive/ticket.sh
#
# Quick Start:
#   ./ticket.sh init          # Initialize in your project
#   ./ticket.sh new my-task   # Create a new ticket
#   ./ticket.sh start <name>  # Start working on a ticket
#   ./ticket.sh close         # Complete and merge ticket

set -euo pipefail

EOF

# Inline library files (excluding shebang and source statements)
{
    echo "# === Inlined Libraries ==="
    echo ""
    
    # Process yaml-sh.sh from yaml-sh directory
    echo "# --- yaml-sh.sh ---"
    tail -n +2 "yaml-sh/yaml-sh.sh"
    echo ""
    
    # Process yaml-frontmatter.sh
    echo "# --- yaml-frontmatter.sh ---"
    tail -n +2 "$LIB_DIR/yaml-frontmatter.sh"
    echo ""
    
    # Process utils.sh
    echo "# --- utils.sh ---"
    tail -n +2 "$LIB_DIR/utils.sh"
    echo ""
    
    # Process main script (excluding shebang and source statements)
    echo "# === Main Script ==="
    echo ""
} >> "$OUTPUT_FILE"

# Process main script, removing:
# - shebang line
# - SCRIPT_DIR definition
# - entire source block (from "# Source required libraries" to "fi")
# And replacing version number
awk -v version="$VERSION" '
    BEGIN { skip = 0 }
    /^#!/ { next }
    /^SCRIPT_DIR=/ { next }
    /^# Source required libraries/ { skip = 1; next }
    skip && /^fi$/ { skip = 0; next }
    skip { next }
    /^# Version:/ { print "# Version: " version; next }
    /^VERSION="1.0.0"/ { print "VERSION=\"" version "\"  # This will be replaced during build"; next }
    { print }
' "$SRC_DIR/ticket.sh" >> "$OUTPUT_FILE"

# Make executable
chmod +x "$OUTPUT_FILE"

echo "Build complete: $OUTPUT_FILE"
echo "File size: $(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "unknown") bytes"
echo ""
echo "You can now use: ./$OUTPUT_FILE"