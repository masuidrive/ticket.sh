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
- Worktree mode: creates directory at `../<project>.worktrees/<ticket-name>/`
- Worktree mode: after the worktree is ready and symlinks/`tmp/` are set up, `copy_worktree_files()` runs against the effective `worktree_copy_files` list (config entries + `--copy-file <path>` CLI extras). Each entry: skip if the target exists, warn if the source is missing, otherwise `cp -p`. Silently no-op when the resolved list is empty (default), so the feature is off unless deliberately configured.

#### `cmd_close_no_merge()`
- Finalizes without a squash-merge: sets `closed_at`, `git mv`s the ticket into `done/`, commits and pushes on the current branch.
- Applies the checklist and append-only gates **when the current branch is not the ticket's base branch** (`base_branch` frontmatter, falling back to `default_branch`), and skips them when it is. The original skip was reasoning about where the command runs, not about the command: the same call now also happens before the PR exists, on the ticket's own branch, because a workflow token cannot push to a protected default branch and the move into `done/` has to ride in on the PR. Skipping there let a gate that refuses `--force` be walked around by changing the call site, with no output. On the base branch the merge has already happened, so refusing would strand the ticket outside `done/`.
- Honours `--dry-run`, which `cmd_close` used to accept and drop on the floor for this path.

#### `close_ticket()`
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
- **Worktree tests**: Test worktree creation, close, cancel, resume, and config mode
- **Checklist tests** (`test-checklist.sh`): `require_checklist`, `require_checklist_groups`, `check --require`, and the Markdown scanner's edge cases
- **ticket_files tests** (`test-ticket-files.sh`): file creation, placeholder substitution, the `note.md` override, path escapes, and the `Active ticket paths:` lines
- **append-only tests** (`test-append-only.sh`): the refusal, the message, `--force`/`--dry-run`, and that appending the lines again clears the gate without rewriting history
- **Branch override tests** (`test-branch-override.sh`): `new --branch` validation, the full lifecycle (start/check/restore/close/list) on a ticket whose branch is named in its frontmatter, and the case where the ticket exists only on that branch

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
- **Gated `--no-merge`**: the checklist and append-only gates apply to `close --no-merge` when it runs off the ticket's base branch, where they can be measured
- **Worktrees are kept by default**: `close` / `cancel` leave the worktree in place; `--delete-worktree` removes it, and `--keep-worktree` remains as a no-op
- **Unknown flags stop `start`**: retired flags are inert by name, everything else is an error
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