---
priority: 2
tags: []
description: "Modify ticket.sh list --status done to show closed tickets in descending order (most recently closed first)"
created_at: "2025-07-10T00:16:34Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Ticket Overview

Currently, `ticket.sh list --status done` shows closed tickets in ascending order. This should be changed to show the most recently closed tickets first (descending order by close date).

## Tasks

- [ ] Analyze current sorting logic in ticket.sh list command
- [ ] Modify the sorting to use descending order for done tickets
- [ ] Test the changes with existing done tickets
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing


## Notes

Additional notes or requirements.
