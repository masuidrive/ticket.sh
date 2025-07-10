---
priority: 2
tags: []
description: "Modify ticket.sh list --status done to show closed tickets in descending order (most recently closed first)"
created_at: "2025-07-10T00:16:34Z"
started_at: 2025-07-10T00:16:56Z # Do not modify manually
closed_at: 2025-07-10T01:04:01Z # Do not modify manually
---

# Ticket Overview

Currently, `ticket.sh list --status done` shows closed tickets in ascending order. This should be changed to show the most recently closed tickets first (descending order by close date).

## Tasks

- [x] Analyze current sorting logic in ticket.sh list command
- [x] Modify the sorting to use descending order for done tickets
- [x] Test the changes with existing done tickets
- [x] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing


## Notes

**実装完了**：
- `ticket.sh list --status done` が閉じた順序で降順（最近閉じたものが上）になるよう修正
- テストは全て通過（Failed: 0）
- 既存機能への影響なし
