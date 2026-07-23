# Work Notes for 260722-074342-worktree-copy-files

## Summary

Added the `worktree_copy_files` opt-in feature: when `start` actually creates a
worktree, the paths listed in `worktree_copy_files` (config) plus any
`--copy-file <path>` CLI extras are copied from the main repo into the fresh
worktree. Existing target files are never overwritten; missing sources emit a
warning and continue.

Default is `worktree_copy_files: []` (no-op — the feature only kicks in when
deliberately configured or when `--copy-file` is passed).

## Design decisions (confirmed with the user)

- **List of paths from day 1, no `.env` hardcoding.** `worktree_copy_files: []`
  is the config key; `.env` is used only as the representative example in docs.
  This avoids a follow-up PR to generalize the shape.
- **CLI flag is `--copy-file <path>` (repeatable).** Appended to config's list
  at invocation time. Works even with an empty config list.
- **`.env` is assumed gitignored.** The initial worry ("secret gets copied to
  every collaborator") does not apply once we assume gitignore: gitignored
  files are per-machine, so each collaborator's own `.env` gets copied into
  their own worktree. README explicitly states the gitignore prerequisite.
- **Symlink mode punted.** Initial version copies only. Could add later as a
  mode selector.
- **All worktree code paths covered** by wiring a single `copy_worktree_files`
  call after `ensure_ticket_tmp_dir` in both the "worktree resume" and
  "worktree new-branch" branches inside `cmd_start`.
- **Non-worktree `start` silently ignores `--copy-file`.** The feature exists
  to bootstrap a fresh worktree; without a worktree there is nothing to
  bootstrap.

## Implementation touch points

### src/ticket.sh
- Added `copy_worktree_files()` helper (idempotent: skip-if-exists,
  warn-if-source-missing).
- Added `resolve_worktree_copy_files()` helper that reads
  `yaml_list_size` / `yaml_get "worktree_copy_files.<N>"` from the loaded
  config and appends CLI extras.
- `cmd_start` arg parser: added `--copy-file <path>` (and `--copy-file=<path>`)
  repeatable. Guards under `set -u` on bash 3.2 (empty array expansion).
- Called `copy_worktree_files` in both `cmd_start` worktree code paths
  (resume-existing-branch and new-branch), after symlink + tmp/ setup.
- Default config template (`cmd_init` heredoc) now emits
  `worktree_copy_files: []` with an explanatory comment.
- `show_usage()` updated: `start` line includes `[--copy-file <path>]...`,
  a paragraph under it explains the flag, and a new "Worktree extras"
  section under "## Configuration" documents the config key + gitignore
  prerequisite.

### yaml-sh compatibility
- Confirmed the existing parser already handles both list syntaxes
  (`- item` block and `[a, b]` inline, plus `[]` empty) via
  `yaml_list_size` / `yaml_get "key.N"`. **No parser changes needed.**

### Docs
- README.md / README.ja.md: updated `start` command summary,
  default-config example, and the Worktree Support bullet list to describe
  `worktree_copy_files` + `--copy-file`.
- spec.md / spec.ja.md: added the config key to the example
  `.ticket-config.yaml`, updated the `start` synopsis, and added a new
  "Worktree file copy (`worktree_copy_files`)" section under the
  `start` command reference.
- DEV.md: added one line to the `start_ticket()` component describing the
  post-worktree-setup copy hook.
- CLAUDE.md: no update needed (does not document worktree flags).

### Tests
- New `test/test-worktree-copy-files.sh` with 16 assertions across 8 scenarios:
  1. Default empty list → no copy (regression guard)
  2. Config-enabled + source exists → copied (happy path)
  3. Config-enabled + target exists → skip (never overwrite)
  4. Config-enabled + source missing → warn, exit 0, no copy
  5. Empty config + `--copy-file` CLI single → copies via CLI
  6. Multiple `--copy-file` flags accumulate
  7. Config entry + CLI extra merged into one effective list
  8. `--copy-file` without `--worktree` is silently ignored
- Uses `✓`/`✗` marks so `run-all.sh`'s counter picks up the assertions.
- Test fixture files are gitignored so `git worktree add` does not
  materialize them in the fresh worktree (which would otherwise trigger the
  "target already exists" skip path unintentionally in cases 5-7).

## Verification

- `bash build.sh` → clean rebuild.
- `bash test/run-all.sh` → **264/264 pass** (prior baseline 248 + 16 new).
- `bash test/run-all-on-docker.sh` → Ubuntu **245/245 pass**,
  Alpine **245/245 pass** (first docker run showed one intermittent failure
  in each platform on unrelated pre-existing tests — second run clean on
  both).

## Non-issue: `.gitignore` catches new test files

Root `.gitignore` has a global `test-*` pattern that ignores untracked files
matching `test-*` at any depth. The new `test/test-worktree-copy-files.sh` had
to be `git add -f`'d. Pre-existing test files were unaffected because git
respects .gitignore only for untracked files.
