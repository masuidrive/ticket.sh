---
priority: 2
tags: [feature]
description: "Add selfupdate command to update ticket.sh from GitHub"
created_at: "2025-06-30T14:22:45Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Self-Update Command Implementation

## Overview
Implement a `selfupdate` command that allows ticket.sh to update itself from the latest version on GitHub. This needs to handle the challenge of a running script updating itself without breaking.

## Tasks

- [ ] Implement selfupdate command
- [ ] Download latest version from GitHub to temporary file
- [ ] Verify download was successful
- [ ] Create update script in tmp directory to handle replacement
- [ ] Execute update script and exit cleanly
- [ ] Add error handling for network issues
- [ ] Update documentation with new command
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing

## Notes

- Self-updating a running script is tricky - need to use a temporary script
- The update process:
  1. Download new version to temp file
  2. Create small update script that will:
     - Wait briefly for parent to exit
     - Replace the original file
     - Set correct permissions
  3. Execute update script in background
  4. Exit the current script
- Should handle cases where download fails gracefully
- Preserve file permissions (executable bit)
