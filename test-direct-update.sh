#!/usr/bin/env bash
set -euo pipefail
VERSION="2.0"
show_version() {
    echo "Current version: $VERSION"
    echo "Script path: $0"
    echo "PID: $$"
}
echo "=== Updated Script ==="
show_version
echo "Update was successful!"
