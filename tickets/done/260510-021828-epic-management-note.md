# Work Notes for 260510-021828-epic-management

## Summary

Implemented the Epic management feature per gist 09b482ac. All work landed in `src/ticket.sh` (built into root `ticket.sh` via `build.sh`).

## What was added

### New commands
- `ticket.sh epic new <slug> [--title <t>] [--branch epic/<slug>|--main-direct] [--from-ref <ref>]`
- `ticket.sh epic close <slug> [--dry-run|-n] [--no-push] [--no-delete-remote] [--force|-f]`
- `ticket.sh epic cancel <slug> --reason "<text>" [...]`
- `ticket.sh epic list [--status open|closed|cancelled] [--json]`
- `ticket.sh epic show <slug> [--json]`
- `ticket.sh epic help`

### Augmented command
- `ticket.sh new <slug> --epic <epic-slug>` — sets `epic_id` and `base_branch` from the resolved epic, refusing if the epic is closed or cancelled.

### Internal helpers (all in src/ticket.sh)
- `validate_epic_slug` — `^[a-z][a-z0-9._-]{0,79}$` (looser than ticket slugs)
- `json_escape` — escapes `\`, `"`, and control chars (`\n \r \t \b \f`)
- `get_yaml_field <yaml_content> <field>` — read a single field from raw frontmatter, strips quotes and inline comments
- `resolve_epic <slug>` — searches `main:epics/<slug>.md`, then `refs/heads/epic/*:epics/<slug>.md`, then `main:epics/done/<slug>/index.md`. Sets `EPIC_ORIGIN`, `EPIC_SOURCE_REF`, `EPIC_PATH`, `EPIC_RAW`.
- `epic_extract_frontmatter` / `epic_extract_body` — variants of the existing helpers that read from a string instead of a file
- `write_epic_file` — writes a full epic file with frontmatter + body
- `epic_default_body` — the spec's body template
- `epic_find_linked_tickets <slug> [<branch>]` — scans `tickets/*.md` and `tickets/done/*.md` (working tree) plus the epic branch via `git ls-tree`. Emits `<status>|<location>|<path>` lines.
- `_epic_resolve_squash_residuals` — implements the §4.3 algorithm: for each unmerged path after `merge --squash -X theirs`, take theirs if the file exists on the epic branch, otherwise `git rm`.
- `_epic_close_epic_branch` / `_epic_close_main_direct` / `_epic_cancel_epic_branch` / `_epic_cancel_main_direct` — the 4 mutation sequences from §4.

## Test coverage

Single test file `test/test-epic-management.sh` covering the 4 spec scenarios + a list/show smoke test:

1. Happy path (epic-branch case): epic new → ticket new --epic → start/close ticket on epic branch → epic close → epics/done/alpha/index.md with status: closed; src/feat.js on main; epic/alpha branch deleted.
2. Cancel discards impl: epic new → impl commits → epic cancel --reason → main has cancel metadata only; impl file NOT on main.
3. Preflight blockers: open linked ticket blocks epic close; --force overrides.
4. Dirty tree refusal: untracked file blocks epic close via preflight.
5. list/show JSON: epic_id/title in `list --json`; epic_id/branch in `show --json`.

Result: 21/21 PASS. Full test/run-all.sh: 158/158 PASS. test/run-all-on-docker.sh (Ubuntu + Alpine): all PASS.

## Notes / decisions

- **bash 3.2 compatibility**: macOS bash + `set -euo pipefail` makes `"${arr[@]}"` fail when arrays are empty. Used the `${arr[@]+"${arr[@]}"}` idiom for safe expansion in `cmd_epic_list` and `cmd_epic_show`.
- **JSON output**: implemented in pure bash via `json_escape` + `printf`. Handles `\\ \" \n \r \t \b \f`. Numbers (e.g. `version: 1`) are emitted unquoted; nulls as `null`.
- **`epic show` preflight**: the JSON `preflight` field is a lightweight blocker check (just open linked tickets), not a full dry-run squash simulation. The full simulation is only in `epic close --dry-run`.
- **gitignore note**: the project's root `.gitignore` has a broad `test-*` pattern that catches `test/test-epic-management.sh`. Force-added with `git add -f`. A follow-up could narrow the pattern to `^test-*` (root-only) so new test files don't need force-add.
- **Test file consolidation**: spec lists 4 separate test files (test-epic-happy-path.sh, etc.). I consolidated them into one `test-epic-management.sh` with sections — easier to maintain and the spec scenarios are identifiable by the section headers.
- **`status: closed` recording**: handled by `write_epic_file` rewriting the whole frontmatter on close/cancel, rather than `update_yaml_frontmatter_field` (since multiple fields change at once and we want a canonical block ordering).

## Gist reference

https://gist.github.com/masuidrive/09b482ac49812feec2d074cb116cb3e1
