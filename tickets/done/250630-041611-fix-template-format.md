---
priority: 2
tags: []
description: "Fix default ticket template formatting changes"
created_at: "2025-06-30T04:16:11Z"
started_at: 2025-06-30T04:17:04Z # Do not modify manually
closed_at: 2025-06-30T04:48:13Z # Do not modify manually
---

# Fix default ticket template formatting

The default ticket template was modified outside of a ticket. This ticket captures those changes and ensures consistency across the codebase.

## Tasks

- [x] Review the current template format changes
- [x] Add important warning messages about not discarding user changes
- [x] Update src/ticket.sh to match the new template format
- [x] Ensure both .ticket-config.yml and src/ticket.sh have the same template
- [x] Build and test
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Get developer approval before closing

## Notes

The template was modified to:
- Remove the permission reminder message from Notes section
- Add "Get developer approval before closing" as a task item
- Adjust spacing between sections

Also added important warnings to error messages:
- check_clean_working_dir() now warns not to use 'git restore' or 'rm' without permission
- close command's force message no longer suggests 'git checkout -- .' to discard changes
