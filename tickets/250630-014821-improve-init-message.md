---
priority: 2
tags: []
description: "Improve init command to guide users about configuration and AI agent setup"
created_at: "2025-06-30T01:48:21Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Improve init command message

Update the init command to provide better guidance to users about:
1. Configuration options in `.ticket-config.yml`
2. Setting up AI agent instructions in `CLAUDE.md` or `AGENTS.md`
3. Workflow recommendations

## Tasks
- [ ] Update init command to display informative message after initialization
- [ ] Include configuration guidance
- [ ] Add AI agent setup instructions
- [ ] Test the new init message

## Proposed Message

```
Ticket system initialized successfully!

## Next Steps:

1. **Configure your ticket system** (optional):
   Edit `.ticket-config.yml` to customize:
   - tickets_dir: Where tickets are stored (default: "tickets")
   - default_branch: Main development branch (default: "develop")
   - branch_prefix: Feature branch naming (default: "feature/")
   - auto_push: Push on close (default: true)
   - default_content: Template for new tickets

2. **For AI coding assistants** (Claude, GitHub Copilot, etc.):
   Create `CLAUDE.md` or `AGENTS.md` with instructions like:
   
   ```markdown
   # AI Assistant Instructions for ticket.sh
   
   When working with tickets:
   1. Always run `./ticket.sh list` to see available tickets
   2. Use `./ticket.sh start <ticket-name>` before making changes
   3. Review ticket content in `current-ticket.md` for requirements
   4. Run tests and ensure quality before closing
   5. Use `./ticket.sh close` when all tasks are complete
   
   Workflow:
   - One ticket at a time
   - Commit frequently with clear messages
   - Update ticket file with progress notes
   - Mark checklist items as complete [x]
   ```

3. **Quick start**:
   - Create a ticket: `./ticket.sh new <slug>`
   - List tickets: `./ticket.sh list`
   - Start work: `./ticket.sh start <ticket-name>`
   - Complete: `./ticket.sh close`

For detailed help: `./ticket.sh help`
```

## Notes
- Message should be concise but informative
- Include ready-to-copy AI agent instructions
- Reference help command for full documentation
