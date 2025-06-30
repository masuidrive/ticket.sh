#!/usr/bin/env bash

# Test script for self-update mechanism
# This script demonstrates how a running script can update itself

set -euo pipefail

VERSION="2.0"

# Show current version
show_version() {
    echo "Current version: $VERSION"
    echo "Script path: $0"
    echo "PID: $$"
}

# Self-update function
selfupdate() {
    echo "=== Starting self-update test ==="
    
    local script_path="$(realpath "$0")"
    local backup_path="${script_path}.backup"
    local new_script="${script_path}.new"
    local update_script=$(mktemp)
    
    # Create a "new version" (just modify the VERSION variable)
    echo "Creating new version..."
    cp "$script_path" "$new_script"
    sed -i '' 's/VERSION="2.0"/VERSION="2.0"/' "$new_script" 2>/dev/null || \
    sed -i 's/VERSION="2.0"/VERSION="2.0"/' "$new_script"
    
    # Show what we're about to do
    echo "Current script: $script_path"
    echo "New version: $new_script"
    echo "Update script: $update_script"
    
    # Create the update script
    cat > "$update_script" << EOF
#!/bin/bash
# Update script - runs after parent exits
echo "Update script started (PID: \$\$)"
echo "Waiting for parent process to exit..."
sleep 2

# Backup current version
echo "Backing up current version..."
cp "$script_path" "$backup_path"

# Replace with new version
echo "Installing new version..."
mv "$new_script" "$script_path"
chmod +x "$script_path"

echo "Update completed successfully!"
echo "Backup saved to: $backup_path"
echo "You can now run: $script_path"

# Clean up update script
rm -f "\$0"
EOF
    
    chmod +x "$update_script"
    
    # Launch update script in background, detached from this process
    echo "Launching update process..."
    nohup bash "$update_script" > "${update_script}.log" 2>&1 &
    local update_pid=$!
    echo "Update process started with PID: $update_pid"
    
    echo "This script will now exit to allow the update to proceed."
    echo "Check ${update_script}.log for update progress."
    exit 0
}

# Main menu
main() {
    echo "=== Self-Update Test Script ==="
    show_version
    echo ""
    echo "Options:"
    echo "1. Run self-update"
    echo "2. Show version"
    echo "3. Exit"
    echo ""
    
    read -p "Choose option: " choice
    
    case "$choice" in
        1)
            selfupdate
            ;;
        2)
            show_version
            ;;
        3)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option"
            exit 1
            ;;
    esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi