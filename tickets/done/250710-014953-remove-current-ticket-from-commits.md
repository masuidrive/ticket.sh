---
priority: 2
tags: []
description: "Remove current-ticket.md from git history during close command to prevent accidental commits"
created_at: "2025-07-10T01:49:53Z"
started_at: 2025-07-10T01:51:02Z # Do not modify manually
closed_at: 2025-07-10T01:56:12Z # Do not modify manually
---

# Ticket Overview

Modify the close command to remove `current-ticket.md` from git history before creating the "Close ticket" commit. This prevents `current-ticket.md` from being accidentally included in commits when users force-add it with `git add -f`.

## Problem
- `current-ticket.md` is normally in `.gitignore` but can be force-added with `git add -f`
- If committed in the feature branch, it gets included in the final merge to main
- This should be prevented as `current-ticket.md` is a temporary working file

## Solution
Add `git rm --cached current-ticket.md` before the "Close ticket" commit to:
- Remove from current index (won't be in next commit)
- Remove from past commits in the feature branch
- Keep the file in working directory (for later cleanup)

## Tasks

- [x] Locate the close command implementation in src/ticket.sh
- [x] Add check for current-ticket.md in git index before "Close ticket" commit
- [x] Implement git rm --cached current-ticket.md if present
- [x] Test the functionality with force-added current-ticket.md
- [x] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing


## Notes

Implementation should be added around line 1150-1160 in cmd_close function, before the "Close ticket" commit is created.

**テスト追加完了：**
- Test 6: `current-ticket.md`がgit履歴に強制追加された場合の除去テスト
- Test 7: 通常のclose動作テスト（`current-ticket.md`がgit履歴にない場合）
- 両テストともに成功
