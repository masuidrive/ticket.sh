---
priority: 2
tags: [feature, enhancement]
description: "Add remote branch cleanup on close and configurable success messages"
created_at: "2025-06-30T13:05:19Z"
started_at: 2025-06-30T13:06:46Z # Do not modify manually
closed_at: 2025-06-30T13:10:56Z # Do not modify manually
---

# Remote Branch Cleanup and Configurable Messages

## Overview
This ticket implements two features to improve the ticket management workflow:
1. Automatic deletion of remote feature branches when closing tickets (to prevent GitHub's "Compare & pull request" banner)
2. Configurable success messages for start and close commands

## Tasks

### 1. Remote Branch Deletion on Close
- [ ] Add configuration option for remote branch deletion (default: enabled)
- [ ] Implement remote branch deletion in close command
- [ ] Add command-line flag to override config setting
- [ ] Handle errors gracefully (e.g., remote branch already deleted)

### 2. Configurable Success Messages  
- [ ] Add configuration for start success message
  - Default: "チケットに内容を見直してからtaskを開始してください"
- [ ] Add configuration for close success message  
  - Default: "" (empty)
- [ ] Implement message display at end of command output
- [ ] Ensure messages work with both start and close commands

### 3. Documentation
- [ ] Update README with new features
- [ ] Document configuration options
- [ ] Add examples of usage

### 4. Testing & Approval
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing

## Notes

- Remote branches left after merge cause clutter in GitHub UI
- Success messages guide users on next steps in workflow
- Both features should be configurable to accommodate different team preferences
