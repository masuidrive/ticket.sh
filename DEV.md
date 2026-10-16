# Developer Documentation

This document contains detailed information for developers working on ticket.sh.

## Architecture Overview

ticket.sh is designed as a self-contained shell script that manages tickets using Git and markdown files. The system follows these principles:

- **Self-contained**: Compiles to a single executable shell script
- **Git-native**: Uses Git for version control and branch management
- **File-based**: Stores tickets as markdown files with YAML frontmatter
- **Cross-platform**: Works on macOS and Linux with Bash 3.2+

## Project Structure

```
ticket-sh/
├── src/
│   └── ticket.sh          # Main script source
├── lib/
│   ├── yaml-sh.sh         # YAML parser library
│   ├── yaml-frontmatter.sh # YAML frontmatter handler
│   ├── utils.sh           # Utility functions (incl. ticket↔branch resolution)
│   ├── checklist.sh       # Ticket/note checklist scanner (check/close)
│   └── append-only.sh     # append_only_files gate (check/close)
├── test/
│   ├── test-*.sh          # Feature-specific test files
│   ├── run-all.sh         # Local test runner
│   └── run-all-on-docker.sh # Docker test runner
├── build.sh               # Build script
├── spec.md                # English specification
├── spec.ja.md             # Japanese specification
└── README.md              # User documentation
```

## Building

The build process combines all source files into a single executable:

```bash
bash ./build.sh
```

This creates `ticket.sh` in the project root by:
1. Starting with the shebang and warning header
2. Including all library files from `lib/`
3. Appending the main script from `src/ticket.sh`
4. Making the output executable

The build script adds an important warning header:
```bash
# IMPORTANT NOTE: This file is generated from source files. DO NOT EDIT DIRECTLY!
# To make changes, edit the source files in src/ directory and run ./build.sh
```

## Development Environment Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/masuidrive/ticket.sh.git
   cd ticket.sh
   ```

2. **Build the script**:
   ```bash
   bash ./build.sh
   ```

3. **Run tests**:
   ```bash
   bash ./test/run-all.sh
   ```

## Code Structure

### Main Components

#### Command Handler (src/ticket.sh)
The main script uses a case statement to route commands:
- `init`: Initialize ticket system
- `new`: Create new ticket
- `list`: List tickets with filters and options
- `start`: Start work on ticket
- `close`: Complete ticket
- `cancel`: Cancel ticket without merging
- `restore`: Rebuild the active-ticket symlinks (`current-ticket/`, `current-ticket.md`, `current-note.md`) from the current branch name
- `check`: Diagnose current state and provide guidance
- `version`: Display version information
- `selfupdate`: Update to latest release from GitHub

#### YAML Processing (yaml-sh/yaml-sh.sh, lib/yaml-frontmatter.sh)
- Parses YAML frontmatter from markdown files
- Updates YAML fields (timestamps)
- Preserves formatting and comments
- yaml-sh is otherwise a flat parser, with one exception: a dash list whose
  items are maps (`- path: a.md` followed by an indented `content: |` block) is
  read as `<list>.<N>.<key>`, which is what `ticket_files` is written in. The
  raw item text is still stored at `<list>.<N>` as well, because
  `yaml_list_size` counts those keys and a map item that produced only
  `<list>.<N>.<key>` would make the list look empty. A list item's first key
  must carry an inline value; a block scalar goes on its own indented line
  below it. Nesting is one level only.
- `yaml_parse_text()` bridges the gap between `yaml_parse`, which takes a file,
  and frontmatter that is already a string. It writes to an `mktemp` file and
  removes it. Three callers used to bridge it with a path of their own naming
  (`/tmp/ticket_yaml.yml`, `/tmp/ticket_yaml_early.yml`), which is a fixed name
  in a world-writable directory — see design note 23. `yaml_parse` itself makes
  its awk scratch file with `mktemp` for the same reason, rather than from `$$`.

#### Utilities (lib/utils.sh)
- Date/time handling and timezone conversion
- Git operations with output display
- File manipulation and validation
- Cross-platform compatibility
- Dynamic command name detection
- Git worktree detection and main repo resolution
- Ticket↔branch resolution: `ticket_branch_name()` is the single place a
  ticket's feature branch name is decided (its frontmatter `branch:` when set,
  otherwise `{branch_prefix}<ticket-name>`), and `ticket_claiming_branch()` /
  `ticket_name_for_branch()` are the reverse lookup for commands that start from
  a branch name. The frontmatter is read with awk rather than yaml-sh, because
  `yaml_parse` writes to globals the caller is usually mid-way through using for
  the config — the same reason `started_at_on_branch()` does it that way.
- `pre_close_run()` runs the project's `pre_close_command` and turns a non-zero
  exit into a refusal. The command's streams are left alone, so the project's own
  message is what the user reads. It runs in a subshell with `errexit`,
  `nounset` and `pipefail` off: the value is one line of shell written
  elsewhere, and `set -e` would read `grep -q x f && echo ok` as a failure where
  its author meant a test. The subshell also keeps a check that `cd`s or exports
  from changing the close that continues after it.
- `branch_carries_only()` answers whether a branch holds anything beyond the
  base other than the named files. It lists the commits (`log --name-only`)
  rather than diffing, because a file added on the branch and deleted again
  leaves no net diff while its commits still land wherever the branch is
  merged. It returns non-zero when it cannot tell: a caller deciding whether to
  move a branch should hear "no" rather than a guess.

### Key Functions

#### `init_repo()`
- Creates `.ticket-config.yaml`
- Creates `tickets/` directory
- Updates `.gitignore`

#### `create_ticket()`
- Validates slug format
- Generates timestamp-based ticket name (`YYMMDD-hhmmss-<slug>`)
- Creates the per-ticket directory `tickets/<TICKETNAME>/` with `ticket.md` (body, from `default_content` template) and `note.md` (log, from `note_content` template when configured)
- Creates each `ticket_files` entry from config. A `note.md` entry overrides `note_content` and is written through the note path above rather than in the loop, so the `$$NOTE_PATH$$` substitution and the "Created note file:" line live in one place. Existing files are never overwritten, and a path that would escape the ticket directory is skipped with a warning (`ticket_file_path_ok()`).
- `--branch <name>` writes `branch: <name>` into the frontmatter after validating it with `git check-ref-format --branch`, plus explicit refusals for names starting with `-` or containing `@{` (which that command resolves rather than rejects)
- `tmp/` inside the directory is auto-created by `start` / `restore` and its contents are ignored via `<tickets_dir>/.gitignore` (generated by `init`).

#### `start_ticket()`
- Creates feature branch (or git worktree with `--worktree` flag)
- Carries the ticket's companion files from config's `ticket_files` wherever the ticket goes: into the worktree (both the `git checkout <prev-branch> --` path and the fallback copy for an uncommitted ticket), into the `[start]` commit via `record_start_on_base()`'s `commit_paths`, and into the `<path> <hash>` pairs that clear the base tree's untracked copies before the fast-forward. `ticket_extra_file_rels()` is the single place that list is derived, because each of those sites used to name `ticket.md` and `note.md` and stop — so `new` created the file and `start` left it untracked in the base branch's working tree, where it blocked every later `close` from the worktree. The fallback copy decides file by file rather than under the `! -f <worktree>/ticket.md` test, since a ticket already committed on the base branch skipped that whole block and with it the one file that was actually missing. The hashes are snapshotted at the same point as the ticket's and the note's — before the commit is built — because that is what `drop_untracked_if_unchanged()` compares against.
- `--no-worktree` turns `worktree_mode: true` off for one call. The parser records *which way the flags asked* (`worktree_flag_set` / `no_worktree_flag_set`) rather than only the resulting boolean, because the config read is a default and has to stay silent when the command line spoke. That read used to be unconditional and sat after the parsing, so `worktree_mode: true` set `use_worktree` back to true a few lines after the parser had honoured the flag — the flag could never have worked without moving it. Both flags together is an error, not last-one-wins: argument order is exactly what a caller assembling the command line from several places cannot see. `--copy-file` with `--no-worktree` warns and continues (nothing to copy into, and ignoring it is already its contract, so a wrapper that always passes it keeps working). Both flags are matched by name, not by a catch-all — see design note 11 below.
- Updates `started_at` timestamp
- Creates the active-ticket symlinks in the working tree root (or the worktree root in `--worktree` mode):
  - `current-ticket/` → `tickets/<TICKETNAME>/` (dir symlink; new-format tickets only)
  - `current-ticket.md` → the ticket body file (compat)
  - `current-note.md` → the note file (compat)
- For legacy flat tickets, only the two compat file symlinks are created (there is no per-ticket directory to link to)
- Reads the ticket's `branch:` into `pre_switch_branch_override` **before any branch switching**, and prefers it when settling `branch_name`. The read that settles the branch name used to happen after the checkout, off the base branch's copy — which carries no `branch:` at all when the field was added on the agent branch alone (a bot adopting a ticket already committed to the backlog). The override was discarded on every such `start` and the work piled up on `{branch_prefix}<ticket-name>`; `start` returned 0 and stamped `started_at`, so nothing said otherwise until the PR came up empty.
- Stays on the current branch when that is the branch the ticket names and the base branch also has the ticket: `branch_name` resolves to it and the resume path below would check it out again anyway, so the detour through the base branch only churns the tree twice and prints a "creating a new feature branch from `<base>` instead" warning that never comes true. Everything else is unchanged — the branch is resumed as before, and the base branch is still fast-forwarded onto the `[start]` commit.
- Stays on the current branch, instead of returning to the base branch, when the ticket lives only there: current branch == the ticket's `branch:`, the ticket file is present, and the base branch has no copy of it. `record_start_on_base()` is then called with its `skip_base_ff` argument set — the stamp is committed on the branch and the base branch is left alone, because there is no copy of the ticket there to fast-forward onto. Worktree mode never takes this path (it does not touch the caller's HEAD anyway). Without it, a ticket created and committed on its own branch made `start` check out the base branch and report `Ticket not found`.
- Emits an `Active ticket paths:` block listing resolved paths so a downstream agent can consume the output without guessing layout. `ticket_files` entries that exist appear as `file:` lines; the config list is read into `TICKET_FILE_PATHS[]` right after the config is parsed, because the ticket's own frontmatter overwrites the yaml-sh globals before the block is emitted.
- Holds the base branch back when the branch it is resuming carries changes outside the ticket's own files. `record_start_on_base()` fast-forwards the base branch onto the `[start]` commit, which is harmless where the branch is the base plus that commit — the shape of every branch `start` creates itself, and of a branch that adopted the ticket by writing `branch:` into it. A branch only being resumed need not be that shape (a bot committed before anyone ran `start`; an interrupted `start` left `started_at` null; the already-started error tells people to reset it by hand), and the fast-forward then carried every commit on the branch into the base branch — a merge nobody asked `start` for, which broke close's one-commit-per-ticket history and outlived `cancel`. The decision is `branch_carries_only()` over `ticket_file`, `note_file_rel` and `extra_rels`, not `ahead_count`: counting commits would hold the base branch back for the ticket's own bookkeeping too, which is what the fast-forward is *for*. `record_start_on_base()`'s own skip note now checks whether the base branch really lacks the ticket before claiming that as the reason, since the caller has its own and the two were printed together.
- Reads the ticket wherever this tree can see it, which is what makes `start` work from inside *another* ticket's worktree. Three places used to read the cwd and cannot: the probe that reads a ticket's `branch:` out of git (it tries the branch in hand first, and a branch that was cut before this ticket existed does not carry it — `git show`'s 128, with its message already discarded, ended the whole run through `set -e`, so the call printed nothing and exited 128), the already-started check (`extract_yaml_frontmatter` on a path the cwd lacks printed `File not found` and then read as *never started*, the one answer that check must not reach by accident — `ticket_frontmatter_text()` now falls back to the first ref that carries the ticket), and `emit_active_ticket_paths()` (it probed the cwd for a layout it had just created in the worktree, reporting `layout: unknown` and a `tickets/done/<name>.md` that does not exist — it now probes `link_dir` when that is absolute).
- Worktree mode: creates directory at `../<project>.worktrees/<ticket-name>/`
- Worktree mode: after the worktree is ready and symlinks/`tmp/` are set up, `copy_worktree_files()` runs against the effective `worktree_copy_files` list (config entries + `--copy-file <path>` CLI extras). Each entry: skip if the target exists, warn if the source is missing, otherwise `cp -p`. Silently no-op when the resolved list is empty (default), so the feature is off unless deliberately configured.

#### `cmd_close_no_merge()`
- Finalizes without a squash-merge: sets `closed_at`, `git mv`s the ticket into `done/`, commits and pushes on the current branch.
- Applies the checklist, append-only and `pre_close_command` gates **when the current branch is not the ticket's base branch** (`base_branch` frontmatter, falling back to `default_branch`), and skips them when it is. The original skip was reasoning about where the command runs, not about the command: the same call now also happens before the PR exists, on the ticket's own branch, because a workflow token cannot push to a protected default branch and the move into `done/` has to ride in on the PR. Skipping there let a gate that refuses `--force` be walked around by changing the call site, with no output. On the base branch the merge has already happened, so refusing would strand the ticket outside `done/`.
- Honours `--dry-run`, which `cmd_close` used to accept and drop on the floor for this path.

#### `close_ticket()`
- Runs the project's own `pre_close_command` last of the gates and still before any mutation, refusing on a non-zero exit (`pre_close_run()` in `lib/utils.sh`). Exported for it: `TICKET_NAME`, `TICKET_DIR` (empty for a legacy flat ticket), `TICKET_FILE`, `TICKET_BRANCH`, `TICKET_BASE_BRANCH` — resolved here, after the ticket's `base_branch` has already overridden `default_branch`, so a retargeted ticket hands the check the branch it is actually merging into. Runs under `--dry-run`, not bypassed by `--force`, and `cancel_ticket()` does not call it.
- Refuses, before any mutation, when an `append_only_files` entry is missing a line it used to hold (`append_only_check()` in `lib/append-only.sh`). The judgement is per line and forgiven once the line is back in the file, not per commit — otherwise the only available repair (appending the lines again, since history is not rewritten) would not clear the gate. Runs alongside the checklist gates, before the `--dry-run` exit, and is not bypassed by `--force`.
- Updates `closed_at` timestamp in `ticket.md`
- Removes any `current-ticket.md` / `current-note.md` that were force-committed to git history
- Detects worktree mode and switches to main repo for merge
- Squash merges to target branch (ticket's `base_branch` field if set, otherwise config's `default_branch`)
- Moves the ticket to `done/`:
  - New layout: `git mv tickets/<TICKETNAME> tickets/done/<TICKETNAME>` in one step, then `git add` on the moved `ticket.md` so the `closed_at` edit lands in the SAME final commit as the rename (avoids the pre-edit blob problem)
  - Legacy layout: `git mv` on the `.md` file plus (if present) the `-note.md` sibling
- Keeps the worktree when running from one; `--delete-worktree` removes it
- Removes all active-ticket symlinks (`current-ticket/`, `current-ticket.md`, `current-note.md`)
- Optional remote branch cleanup

#### `cancel_ticket()`
- Sets `canceled_at` timestamp and adds `[CANCELED]` prefix to description
- Renames the ticket directory (or, for legacy tickets, the flat `.md` file) with `-CANCELED-` inserted after the timestamp prefix
- Moves the whole directory to `done/`
- Detects worktree mode and switches to main repo
- Switches to default branch without merging (keeps feature branch)
- Keeps the worktree when running from one; `--delete-worktree` removes it
- Removes all active-ticket symlinks

## Testing

### Test Structure

See `test/README.md` for detailed test documentation. Key points:

- **Unit tests**: Test individual commands and features
- **Integration tests**: Test complete workflows
- **Edge case tests**: Test error conditions and boundary cases
- **Compatibility tests**: Test on different platforms and environments
- **UTF-8 tests**: Test Unicode support and international characters
- **Timezone tests**: Test date/time conversion functionality
- **Worktree tests** (`test-worktree.sh`): worktree creation, close, cancel, resume, config mode, `--no-worktree`, and `start` run from inside another ticket's worktree
- **Checklist tests** (`test-checklist.sh`): `require_checklist`, `require_checklist_groups`, `check --require`, and the Markdown scanner's edge cases
- **ticket_files tests** (`test-ticket-files.sh`): file creation, placeholder substitution, the `note.md` override, path escapes, the `Active ticket paths:` lines, and the declared files travelling into a worktree (both routes) without leaving anything untracked in the main repo
- **append-only tests** (`test-append-only.sh`): the refusal, the message, `--force`/`--dry-run`, and that appending the lines again clears the gate without rewriting history
- **pre-close-command tests** (`test-pre-close-command.sh`): that nothing is run and nothing is said when the key is absent or empty, that a failing command stops the close with its own output and leaves `closed_at` unstamped, that `--force` does not get past it and `--dry-run` shows it, that every `TICKET_*` variable holds what it claims (including a retargeted `base_branch` and a legacy flat ticket's empty `TICKET_DIR`), that `cancel` never runs it, that in worktree mode it runs in the worktree, that `--no-merge` gates it only off the base branch, and that a check which `cd`s away or ends on a false test cannot derail the close around it
- **temp-file isolation tests** (`test-tmpfile-isolation.sh`): that two closes running in parallel never read each other's frontmatter (40 paired runs, failing on a single occurrence — against the old code 40 of 80 runs read the wrong ticket), that a file planted at the old fixed paths is left alone by `close`, `start` and `cancel`, that `description: |` still reads as its content (the guard against "fix" by replacing `yaml_parse` with a line matcher), that every temp file made is removed again, and that a `mktemp` which cannot deliver stops the run instead of carrying on
- **Branch override tests** (`test-branch-override.sh`): `new --branch` validation, the full lifecycle (start/check/restore/close/list) on a ticket whose branch is named in its frontmatter, and the case where the ticket exists only on that branch
- **Start base-sync tests** (`test-start-base-sync.sh`): both fast-forward mechanisms, the untracked ticket file `new` leaves behind, the fallback when the fast-forward cannot happen, and the base branch being held back when the resumed branch carries work of its own — including that a branch ahead only by the ticket's own files still advances it, and that `cancel` leaves nothing behind
- **Error reporting tests** (`test-error-reporting.sh`): that a deliberate refusal is not dressed up as a crash, that an unplanned failure names the command and keeps its exit code, that a signal-class exit stays quiet, and that a detached main-repo HEAD reaches its own refusal. The crash cases inject a failing line into a *copy* of the built `ticket.sh`, right after the traps are installed — there is no way in from outside, and the hook has no business in the shipped script.

### Running Tests

```bash
# All tests locally
test/run-all.sh

# Specific test file
test/test-additional.sh

# Docker environments
test/run-all-on-docker.sh
```

### Writing Tests

Tests use helper functions from `test-helpers.sh`:

```bash
# Setup test repository
setup_test_repo "test-dir"

# Get ticket name safely
TICKET=$(safe_get_ticket_name "*feature.md")

# Portable sed
sed_i 's/old/new/' file.txt
```

## Platform Compatibility

### Supported Platforms
- macOS (BSD utilities)
- Linux (GNU utilities)
- Alpine Linux (busybox)

### Compatibility Considerations

1. **Date command**: Supports both GNU date (Linux) and BSD date (macOS) for timezone conversion
2. **Sed command**: Use `sed_i` function for in-place editing
3. **Bash version**: Target Bash 3.2+ for macOS compatibility
4. **File paths**: Always use double quotes around variables
5. **Process detection**: Uses `/proc/self/cmdline` on Linux, `ps` command on macOS for dynamic command names
6. **UTF-8 support**: Automatic locale setting (LANG=C.UTF-8) for consistent Unicode handling

### Cross-Platform Testing

```bash
# Ubuntu
docker run --rm -v "$PWD:/workspace" -w /workspace ubuntu:22.04 \
  bash -c "apt-get update && apt-get install -y git && test/run-all.sh"

# Alpine
docker run --rm -v "$PWD:/workspace" -w /workspace alpine:latest \
  sh -c "apk add --no-cache git bash && test/run-all.sh"
```

## Debugging

### Enable Debug Output

Add to any script:
```bash
set -x  # Enable command tracing
```

### Common Issues

1. **Permission errors**: Check file ownership in Docker
2. **Date parsing**: Verify date format compatibility and timezone handling
3. **Git errors**: Ensure clean working directory
4. **Symlink issues**: Check filesystem support
5. **UTF-8 issues**: Verify locale settings and character encoding
6. **Command detection**: Test dynamic command name detection on different shells

## Contributing

### Code Style

- Use 2-space indentation
- Quote all variables: `"$var"`
- Use `[[ ]]` for conditionals
- Add error checking for commands
- Comment complex logic

### Documentation Requirements

**IMPORTANT**: When making code changes, always update relevant documentation:

1. **User-facing changes**: Update README.md and README.ja.md
2. **New features**: Add to both English and Japanese documentation
3. **API changes**: Update this DEV.md file
4. **Command changes**: Update help text and usage examples
5. **Configuration changes**: Update config documentation

Documentation updates should be part of the same PR as code changes.

### Pull Request Process

1. Create feature branch from `develop`
2. Write/update tests
3. Ensure all tests pass
4. Update documentation
5. Submit PR with clear description

### Testing Requirements

- All tests must pass locally
- Docker tests must pass (Ubuntu + Alpine)
- New features need test coverage
- Edge cases should be tested

## Release Process

1. Merge all features to `develop`
2. Run full test suite
3. Update version in relevant files
4. Build final script: `./build.sh`
5. Create release tag
6. Update release binary

## Security Considerations

- Never commit sensitive data
- Validate all user input
- Use proper quoting to prevent injection
- Test with malicious filenames/content

## Performance Notes

- Minimize subshell usage
- Cache repeated operations
- Use built-in bash features when possible
- Profile with `time` command for bottlenecks

## Architecture Features

### Key Design Decisions

1. **Self-contained**: Single executable script with inlined dependencies
2. **Git-native**: Leverages Git for branch management and version control
3. **Markdown-based**: Human-readable ticket format with YAML frontmatter
4. **Timezone-aware**: Converts UTC timestamps to local timezone for display
5. **Error recovery**: Comprehensive diagnostic and recovery commands
6. **Cross-platform**: Works consistently across different Unix-like systems
7. **No sidecar state files**: A ticket's state lives in its YAML frontmatter and
   nowhere else. We do not keep a `tickets/.state.json` or similar. Such a file
   would have to be gitignored, so it would not survive a clone and would never
   reach a collaborator, a worktree, or CI — while duplicating what the
   frontmatter already holds, with no way to settle which copy is right once the
   two drift. When state needs to be visible from another branch, commit it
   there (see `record_start_on_base`), don't shadow it in an untracked file.
8. **Commit messages carry the ticket body, not its frontmatter**: `close` embeds
   the ticket's Markdown into the squash commit so `git blame` reaches the "why"
   without opening `tickets/done/`. The YAML frontmatter is deliberately left
   out — it is written for whoever edits the ticket, not whoever reads the
   history, and the same commit already carries the ticket file itself. Build the
   message with `$'\n\n'` and plain `echo`, never `echo -e`: the body is
   arbitrary Markdown and may contain backslash escapes that `-e` would expand.
9. **The checklist is scanned, not reconciled against the template**: `check`
   and `close` read the ticket body and the note themselves and group the
   checkboxes by the nearest preceding heading, per file. They deliberately do NOT compare it against `note_content`
   in the config to detect deleted lines. The config holds the *current*
   template, while a ticket started last week was handed an older one, so adding
   a line to the template would mark every in-flight ticket as having deleted it;
   and item lines are edited in normal use (evidence appended, a skip reason
   added), which any text match would then miss. Deleting a line is an act that
   shows up in `git diff`; leaving a box unchecked is what happens when nobody
   does anything, and that is the hole worth closing. See issue #3.
10. **Four columns of indentation inside a list is not a code block**: the
   scanner excludes fenced and indented code blocks, because a work note quotes
   the very template it came from. But in CommonMark, indentation inside a list
   is the item's own continuation - treating it as code would drop nested
   checkboxes from the count, handing back an "indent it and it stops blocking"
   loophole in a check whose whole point is that items cannot be made to
   disappear.
11. **`--force` does not bypass the checklist**: `--force` is about the state of
   the Git tree. The way past the checklist is `- [-] ... - skip: <reason>`,
   which leaves the reason in the file where a reader can weigh it. A flag that
   recorded nothing would restore the status quo the check exists to end.
12. **A renamed config key is an error, not a silent no-op**: `require_checklist`
   was `require_note_checklist` while the check only read the note. The old name
   is gone, but a config that still sets it to `true` fails loudly rather than
   being ignored - dropping a gate someone deliberately switched on, without
   saying so, is the same "it is there and nobody looks at it" failure the check
   exists to end. Set to `false` it only warns, since nothing is being disabled
   behind the user's back.
13. **Append-only is judged per line, not per commit**: `append_only_files` asks
   whether a line the file used to hold is missing from it now, not whether some
   commit once removed one. The two come apart the moment someone tries to fix a
   violation: history is not to be rewritten, so the only repair available is to
   append the lines again - and a per-commit rule would go on failing after the
   repair, leaving amend-and-force-push as the only way out. That is the
   opposite of what a file kept for its history wants. A consequence worth
   stating: an edited line counts as removed, because its old text is gone.
14. **A ticket names its branch; ticket.sh does not name it twice**: branch
   naming used to be `{branch_prefix}<ticket-name>` and nothing else, so a
   branch created outside ticket.sh could only be worked around - `check`
   reported a permanent mismatch, `close` was limited to `--no-merge`. The
   `branch:` field puts the name in the one place both directions can read it,
   and every command routes through `ticket_branch_name()` rather than
   re-deriving it. `branch_prefix` keeps its meaning as the default, so a ticket
   without the field behaves exactly as before.
15. **`start` does not walk away from the only copy of a ticket**: it normally
   returns to the base branch first, which is wrong when the ticket was created
   and committed on the branch it names and the base branch has never seen it -
   the bot shape `branch:` exists for. Staying put there is narrow on purpose:
   all three of "this is the branch the ticket names", "the ticket is here" and
   "the base branch does not have it" must hold, or `start` would either stop
   returning to the base branch from any feature branch, or drop the
   fast-forward that makes a ticket read `doing` from either side.

15b. **The branch a ticket names is read where the edit is, not where we end
   up**: the sister case of 15, and the one 15 did not cover. When the base
   branch has the ticket too, `start` switches branches as usual - and the read
   that settled the branch name sat after that switch, so it saw the base
   branch's copy. A bot adopting a backlogged ticket can only write `branch:` on
   its own branch, so the field was discarded every time. The read moved ahead
   of the switch; the value found there wins. Nothing else about the path
   changed, which is what keeps the fast-forward in 15's last clause intact.

16. **A gate that can be skipped by calling it from somewhere else is not a
   gate**: `close --no-merge` skipped the checklist and append-only checks on
   the grounds that it runs after the merge, where nothing is measurable. That
   was true of the call site it was written for, and stopped being true when the
   same command started running before the PR existed. The condition is now
   about what can actually be measured - "are we off the ticket's base branch" -
   rather than about which command was typed. No opt-in flag: the failure this
   fixes was silent, and a flag would only move the silence to whoever forgets
   to pass it.

17. **A flag you must remember to pass is a defect, not an option**: `close` and
   `cancel` removed the worktree by default, and the help told coding agents
   they *must* pass `--keep-worktree` - so forgetting deleted the directory
   their shell was in, and every later command failed with an error naming no
   flag. The defaults are now the safe direction (keep; `--delete-worktree` to
   remove), because a left-behind worktree costs one `git worktree remove` while
   the other direction costs a debugging session. The old flag is kept as an
   inert, explicitly-named case - not folded into a catch-all, which is the bug
   below.
18. **Deprecated flags are named, never swallowed**: `start` used to accept every
   unknown flag silently so that a leftover `--no-push` would not break. That
   also let `--worktre` through, producing a branch with no worktree, no error,
   and a problem found much later. Each retired flag now gets its own no-op
   case and everything else is an `Unknown option` error, which keeps old
   invocations working without making typos indistinguishable from intent.
19. **A config setting is a default, so a flag has to be able to outrank it**:
   `worktree_mode: true` was read after `start` parsed its arguments and simply
   assigned `use_worktree=true`, which left no way to say "not this time". The
   repo could not have both "worktrees by default on people's machines" and "no
   worktree for the CI bot, which owns its whole checkout" from one
   `.ticket-config.yaml`. `--no-worktree` now exists, and the parser records
   *which way the flags asked* rather than only the resulting boolean, so the
   config can stay silent when the command line spoke. Both flags together is an
   error rather than last-one-wins: a caller assembling the command line from
   several places cannot see argument order, so a silent winner would be a
   coin toss.

20. **A run that ends must say why, even when nobody planned for it to end**:
   the script runs under `set -e`, so an unhandled failure ends it where it
   happens, and the `git` probes that ask whether a branch carries some path
   discard stderr because a miss is an ordinary answer for them. Put together,
   a probe against a branch that simply does not have the ticket ended `start`
   with exit 128 and not one word — the caller could not tell a bug here from
   its own misuse. The probe itself is fixed, but the shape generalises, so an
   EXIT trap now names the last failing command. Only the crash codes speak
   (126, 127, 128): every deliberate failure leaves with 1..6 and a signal with
   129 or above, so an ERR trap would have called every ordinary refusal a bug.
   The ERR trap only records (`set -E` carries it into functions); bash runs it
   inside a command substitution's subshell too, but a recording made there
   dies with the subshell, which is exactly why the many handled
   `$(... 2>/dev/null)` reads stay quiet. Note that `local x=$(...)` swallows
   the status in every bash from 3.2 to 5, while a bare `x=$(...)` does not —
   that is why only some of these reads were ever fatal.

21. **A fast-forward is only safe while the branch is the base plus the stamp**:
   `start` records the start time by committing it on the feature branch and
   fast-forwarding the base branch onto that commit — correct for a branch
   `start` created itself, which is the base plus that one commit. The resume
   path reaches branches `start` did not create, and fast-forwarding there
   carried the branch's own commits into the base branch: unreviewed work landed
   on `main` at `start` time, close's squash then had little left to squash, and
   `cancel` — whose whole point is not to merge — could not take it back. The
   guard asks what the branch *touches*, not how far ahead it is. Counting
   commits also catches the ticket's own bookkeeping, and a bot adopting a
   backlog ticket does exactly that (one commit writing `branch:` into it), so
   `ahead_count > 0` would have withheld the start time from the base branch in
   the one case design note 15b exists to serve — a fix trading one silent loss
   for another.

22. **A gate the project owns belongs in `close`, not in a Git hook**:
   `close` judged a ticket only by ticket.sh's own standards, so a project with
   a standard of its own had to run it somewhere else — a test suite step that
   `close` does not call, which is to say a check that is skipped exactly when
   someone is in a hurry. `.git/hooks` is not that place either: it is not in
   the repo, so every clone installs it separately; a `pre-commit` hook cannot
   tell close's commit from any other, so it has to work out for itself whether
   this run is the one that matters; and it never fires under `--dry-run`.
   Underneath all three, a hook guards *making a commit* and what wants guarding
   is *finishing a ticket*. `pre_close_command` is one shell line, run where the
   other gates run, with the ticket handed to it rather than left to be derived.
   It is not bypassed by `--force` for the same reason the checklist is not: the
   escape hatch belongs in the check, where the condition is written down.

23. **A temp file nobody else can name**: `yaml_parse` takes a file and the
   frontmatter is a string, and the three callers that bridged that each picked
   a fixed path under `/tmp`. Both halves of that are defects. Two `close` runs
   in parallel worktrees — the arrangement this script advertises, and which its
   own main-repo guard exists to protect — wrote and read the same file: in a
   hundred paired dry-runs, forty-eight read the other repo's ticket, and where
   the other ticket's `base_branch` named a branch that also exists locally, the
   run passed every preflight check and aimed the squash-merge at the wrong
   branch. Separately, a name anyone can predict is a name anyone can pre-create
   as a symlink, and `>|` follows it; the `rm -f` afterwards takes the symlink,
   not the file it clobbered. `mktemp` answers both at once — unpredictable,
   `O_EXCL`, and the platform's own private directory. The failure to make one
   has to stop the caller, because carrying on without a file you wrote is the
   whole bug. What is *not* the fix: dropping `yaml_parse` for a line matcher.
   `description: |` is read by yaml-sh as its folded content and by a line
   matcher as `|`, and the commit subject is where that would surface.

### Recent Enhancements

- **Smart branch handling**: Automatically handles existing branches and clean states
- **Dynamic command detection**: Shows actual invocation method in help messages
- **UTF-8 support**: Full Unicode support for international users
- **Done folder organization**: Automatic organization of completed tickets
- **Git history protection**: Prevents accidental commits of working files
- **Work notes separation**: Optional separate note files for debugging and investigation logs
- **Extra ticket files**: `ticket_files` lets a project declare any number of companion files `new` should create, not just `note.md`
- **Append-only files**: `append_only_files` makes `close` refuse when a file kept as a record has lost lines it used to hold
- **Per-ticket branch names**: `branch:` in the frontmatter (`new --branch`) lets a ticket adopt a branch whose name came from outside
- **No fixed temp paths**: frontmatter parsing goes through `mktemp`, so parallel closes cannot read each other's ticket and a predictable name cannot be pre-created as a symlink
- **Project's own check before close**: `pre_close_command` runs one shell line after the other gates and before the squash-merge; a non-zero exit stops the close and the command's own output is what you see
- **Gated `--no-merge`**: the checklist, append-only and `pre_close_command` gates apply to `close --no-merge` when it runs off the ticket's base branch, where they can be measured
- **Worktrees are kept by default**: `close` / `cancel` leave the worktree in place; `--delete-worktree` removes it, and `--keep-worktree` remains as a no-op
- **Unknown flags stop `start`**: retired flags are inert by name, everything else is an error
- **`start` from another ticket's worktree**: the ticket is read out of git when the cwd's tree has no copy of it, instead of the run ending on exit 128 with nothing printed
- **No silent stops**: an unplanned failure (exit 126/127/128) names the command that failed and where to report it
- **No accidental merge at `start`**: resuming a branch that carries work outside the ticket's own files leaves the base branch where it is, with a line saying why
- **`start --no-worktree`**: turns `worktree_mode: true` off for one call, for a caller that owns its whole checkout and works one ticket in it; both worktree flags together is an error
- **Worktree support**: Optional git worktree mode for parallel ticket work without branch switching
- **Checklist check**: `check` reports the checkboxes in both `ticket.md` and `note.md` by heading group, split per file; `check --require "<group>"` judges one group across both; `require_checklist: true` makes `close` refuse while any are unchecked; and `require_checklist_groups` (a list of heading names) makes `close` refuse when a named group is in neither file - counting unchecked boxes cannot catch that, since a section that is absent counts zero and reads as finished

## Troubleshooting

### Common Problems

1. **"Not in a git repository"**
   - Ensure you're in a git repo
   - Run `git init` if needed

2. **"Ticket system not initialized"**
   - Run `ticket.sh init`
   - Check for `.ticket-config.yaml` or `.ticket-config.yml`

3. **"Permission denied"**
   - Check file permissions
   - Ensure script is executable

4. **Test failures**
   - Check git configuration
   - Verify bash version
   - Review test output carefully

### Getting Help

- Check existing tickets for similar issues
- Review test cases for examples
- Submit detailed bug reports with:
  - Platform/OS version
  - Bash version
  - Complete error output
  - Steps to reproduce