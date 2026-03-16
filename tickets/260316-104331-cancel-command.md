---
priority: 1
merge_to: default  # Override merge target branch (default: use default_branch from config)
description: "Add cancel command to ticket.sh"
created_at: "2026-03-16T10:43:31Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Add `ticket.sh cancel` command

Cancel a ticket without merging. Moves ticket to done/ directory with CANCELED marker.

## Design

- Add `canceled_at` field to YAML frontmatter (distinct from `closed_at`)
- Add `[CANCELED]` prefix to description field
- Rename file with `-CANCELED-` prefix before slug: `done/260316-052108-CANCELED-feature-name.md`
- Switch back to default branch without merging
- Keep feature branch (don't delete)
- Remove current-ticket.md / current-note.md symlinks
- Extend `get_ticket_status` to return "canceled" when `canceled_at` is set
- Add "canceled" to `list --status` filter options
- Default list (todo + doing) excludes canceled tickets
- `--status done` does NOT include canceled (they are separate)

## Tasks

- [ ] Add `canceled_at` field to ticket template
- [ ] Update `get_ticket_status` in lib/utils.sh to handle canceled status
- [ ] Update `cmd_list` to support `--status canceled` filter and exclude canceled from default/done views
- [ ] Implement `cmd_cancel` in src/ticket.sh
- [ ] Add cancel to command dispatch and show_usage
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
