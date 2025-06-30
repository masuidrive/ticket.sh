---
priority: 2
tags: []
description: "Fix default ticket template formatting changes"
created_at: "2025-06-30T04:16:11Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Fix default ticket template formatting

The default ticket template was modified outside of a ticket. This ticket captures those changes and ensures consistency across the codebase.

## Tasks

- [ ] Review the current template format changes
- [ ] Update src/ticket.sh to match the new format
- [ ] Ensure both .ticket-config.yml and src/ticket.sh have the same template
- [ ] Build and test
- [ ] Get developer approval before closing

## Notes

The template was modified to:
- Remove the permission reminder message from Notes section
- Add "Get developer approval before closing" as a task item
- Adjust spacing between sections
