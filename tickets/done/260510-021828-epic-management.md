---
priority: 2
base_branch: default
description: "Add epic management (cmd_epic + cmd_new --epic) per gist spec 09b482ac"
created_at: "2026-05-10T02:18:28Z"
started_at: 2026-05-10T02:19:43Z
closed_at: 2026-05-10T02:41:02Z
canceled_at: null
---

# Epic Management

Implement the Epic management feature for ticket.sh as specified in
https://gist.github.com/masuidrive/09b482ac49812feec2d074cb116cb3e1

## Scope

- `epic` subcommand dispatcher: `new`, `close`, `cancel`, `list`, `show`
- `new --epic <slug>` augmentation (auto-set epic_id + base_branch)
- Epic frontmatter contract (version 1, branch policy: main-direct or epic/<slug>)
- JSON output on `epic list` / `epic show` for pdh-flow web API
- Mutation paths for close x cancel x {epic-branch, main-direct} = 4 sequences
- `merge --squash -X theirs` + auto-resolve for structural conflicts
- Preflight checks (working tree clean, epic branch existence, no open linked tickets, dry-run squash)
- Reference impl: pdh commit c5cba8e (TypeScript -> bash translation)

## Tasks

- [x] yaml-sh helpers / frontmatter (de)serialize for epic files
- [x] `resolve_epic <slug>` helper
- [x] `cmd_epic_new` with --title / --branch / --main-direct / --from-ref + template
- [x] `cmd_new --epic` augmentation (sets epic_id + base_branch)
- [x] `cmd_epic_close` epic-branch path (squash + auto-resolve)
- [x] `cmd_epic_close` main-direct path
- [x] `cmd_epic_cancel` epic-branch path (drop impl, keep epic body)
- [x] `cmd_epic_cancel` main-direct path
- [x] Conflict resolver after `merge --squash -X theirs`
- [x] Preflight (clean tree, branch existence, closed-already, open linked tickets, dry-run squash)
- [x] `cmd_epic_list` text + --json
- [x] `cmd_epic_show` text + --json (full schema for pdh-flow)
- [x] `cmd_epic` dispatcher + help text
- [x] Tests: test-epic-happy-path.sh, test-epic-cancel.sh, test-epic-preflight.sh, test-epic-dirty-tree.sh
- [x] Run tests before closing and pass all tests
- [x] Run `bash build.sh` to build the project
- [x] Push and comment on the gist
