---
priority: 2
tags: []
description: "Further improvements to init command message based on user feedback"
created_at: "2025-06-30T02:22:50Z"
started_at: 2025-06-30T02:23:14Z # Do not modify manually
closed_at: 2025-06-30T04:10:32Z # Do not modify manually
---

# Further improve init command message

Improvements requested by user:
1. Add message to default ticket template's Notes section about getting permission before closing
2. Update this project's .ticket-config.yml file
3. Change init command behavior for already initialized environments
4. Update AI assistant instructions to tell developers to add to their coding agent's custom prompt
5. Auto-detect current branch (main/master/develop) for default_branch in init
6. Replace AI instructions with new English version focusing on ticket management workflow
7. Remove indentation from markdown block for easier copy-paste
8. Add help command reference to instructions
9. Change "Ticket Closing" to "Closing Tickets" for better English

## Tasks
- [x] Add message to DEFAULT_CONTENT about getting permission before closing
- [x] Update the config file template in init command
- [x] Update this project's .ticket-config.yml file
- [x] Change init command to show simple help for already initialized environments
- [x] Update AI instructions message to be clearer about adding to custom prompt
- [x] Auto-detect current branch for default_branch setting
- [x] Replace instructions with new English version
- [x] Remove indentation from markdown instructions
- [x] Add ./ticket.sh help reference
- [x] Change section title to "Closing Tickets"
- [x] Build and test all changes
- [ ] Get user approval before closing

## Notes
- User requested not to close tickets automatically
- Need to understand what specific improvements are needed
