---
priority: 2
tags: [feature]
description: "Add selfupdate command to update ticket.sh from GitHub"
created_at: "2025-06-30T14:22:45Z"
started_at: 2025-06-30T14:23:14Z # Do not modify manually
closed_at: 2025-06-30T15:37:43Z # Do not modify manually
---

# Self-Update Command Implementation

## Overview
Implement a `selfupdate` command that allows ticket.sh to update itself from the latest version on GitHub. This needs to handle the challenge of a running script updating itself without breaking.

## Tasks

- [x] Implement selfupdate command
- [x] Download latest version from GitHub to temporary file
- [x] Verify download was successful
- [x] Create update script in tmp directory to handle replacement
- [x] Execute update script and exit cleanly
- [x] Add error handling for network issues
- [x] Update documentation with new command
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Get developer approval before closing

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
