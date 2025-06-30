#!/usr/bin/env bash
set -euo pipefail
VERSION="2.0"
show_version() {
    echo "Current version: $VERSION"
}

# Check if this is the first run after update
if [[ "${1:-}" == "--post-update" ]]; then
    echo "✅ Update completed successfully!"
    echo "You are now running version 2.0"
    exit 0
fi

echo "=== Updated Script ==="
show_version
