# ticket.sh - Git-Based Ticket Management System

A lightweight, robust ticket management system that uses Git branches and markdown files. Perfect for solo developers, small teams, and AI pair programming.

## Key Features
- 🎯 **Simple workflow**: Create, start, work, close (or cancel)
- 📝 **Markdown tickets**: Rich formatting with YAML frontmatter
- 🌿 **Git integration**: Automatic branch management per ticket
- 📁 **Per-ticket directory**: Each ticket lives in `tickets/<TICKETNAME>/` with body, note, tests, and temp helpers colocated
- 📁 **Smart organization**: Auto-organized done folder, timezone-aware timestamps
- 🔧 **Zero dependencies**: Pure Bash + Git, works everywhere
- 🚀 **AI-friendly**: Designed for seamless AI assistant collaboration — start/restore emit resolved paths for downstream agents
- 🛡️ **Robust**: UTF-8 support, error recovery, conflict resolution
- ♻️ **Legacy compatible**: Flat single-file tickets from earlier ticket.sh versions keep working with every command

**Language versions**: [English](README.md) | [日本語](README.ja.md)

## Quick Start

### Download
```bash
curl -O https://raw.githubusercontent.com/masuidrive/ticket.sh/main/ticket.sh
chmod +x ticket.sh
```

**⚠️ Windows/VSCode Users**: If you encounter `/usr/bin/env: 'bash\r': No such file or directory` error:
```bash
# Fix CRLF line endings (choose one):
dos2unix ticket.sh              # If dos2unix is installed
sed -i 's/\r$//' ticket.sh      # Using sed
```
This issue is automatically prevented in new downloads via `selfupdate` command.

### For Coding Agents

With coding agents like Claude Code or Gemini CLI, you can operate with conversations like these:

```
Run `./ticket.sh init` to install ticket management
Add custom prompts to CLAUDE.md
```

```
Create a ticket for implementing authentication system
```

```
Start working on that ticket
```

```
Close the ticket
```

```
Cancel the ticket, it's no longer needed
```

```
What tickets are remaining?
```

### CLI Usage
```bash
# Initialize in your project
./ticket.sh init

# Create a ticket
./ticket.sh new implement-auth

# Start working
./ticket.sh start 241229-123456-implement-auth

# Complete work
./ticket.sh close

# Or cancel if no longer needed
./ticket.sh cancel
```

## Installation

### Option 1: Download
```bash
curl -O https://raw.githubusercontent.com/masuidrive/ticket.sh/main/ticket.sh
chmod +x ticket.sh
```

### Option 2: Build from Source
```bash
git clone https://github.com/masuidrive/ticket.sh.git
cd ticket.sh
bash ./build.sh
cp ticket.sh /usr/local/bin/
```

## Basic Usage

1. **Initialize**: `./ticket.sh init`
2. **Create ticket**: `./ticket.sh new feature-name`
3. **Start work**: `./ticket.sh start <ticket-name>`
4. **Close ticket**: `./ticket.sh close` (or `./ticket.sh cancel` to abandon)

`start` commits the start time on the feature branch and fast-forwards the base
branch onto that commit, so `list` reports the ticket as `doing` from either
branch. If the base branch has moved on, the fast-forward is skipped with a note
and the start time stays on the feature branch.

## Ticket Layout

Each ticket lives in its own **per-ticket directory**:

```
tickets/
  <TICKETNAME>/
    ticket.md   # ticket body (YAML frontmatter + Markdown)
    note.md     # working notes / log
    tmp/        # ticket-local temp helpers (auto-created on start/restore; git-ignored via tickets/.gitignore)
  done/
    <TICKETNAME>/   # closed / cancelled tickets — moved here as a whole directory
```

While a ticket is active, `start` creates three symlinks in the repo root so
you (and downstream agents) can always reach the active ticket at fixed paths:

| Symlink                | Points at                              | Purpose                                        |
|------------------------|----------------------------------------|------------------------------------------------|
| `current-ticket/`      | `tickets/<TICKETNAME>/`                | dir symlink — full per-ticket root             |
| `current-ticket.md`    | `tickets/<TICKETNAME>/ticket.md`       | compat file symlink (works with older tooling) |
| `current-note.md`      | `tickets/<TICKETNAME>/note.md`         | compat file symlink                            |

`close` and `cancel` move the whole `tickets/<TICKETNAME>/` directory into
`tickets/done/<TICKETNAME>/` (cancel prefixes the directory name with
`-CANCELED-`) in a single Git commit that also stamps `closed_at` /
`cancelled_at`.

**Legacy compatibility.** Flat-file tickets produced by earlier versions
(`tickets/<TICKETNAME>.md` + `tickets/<TICKETNAME>-note.md`) continue to work
with every command — `list`, `start`, `close`, `cancel`, `restore`, `check`.
They are never auto-migrated to the new layout; convert on your own schedule.

## Usage Examples

### Basic Workflow
```bash
# Check current state
./ticket.sh check

# List tickets by status  
./ticket.sh list --status todo
./ticket.sh list --status done --count 5

# Force close without prompts
./ticket.sh close --force

# Cancel a ticket without merging
./ticket.sh cancel

# Update to latest version
./ticket.sh selfupdate
```

### Working with Done Tickets
```bash
# View recent completions (sorted newest first)
./ticket.sh list --status done

# Restore a completed ticket for reference
./ticket.sh restore 241229-123456-old-feature
```

## Commands

### Core Commands
- `init` - Initialize ticket system (idempotent, safe to re-run)
- `new <slug> [--epic <epic-slug>] [--created-at <YYMMDD-hhmmss>]` - Create new ticket (`--created-at` overrides the auto-generated timestamp; the value is used verbatim as the filename prefix and as `created_at` in UTC)
- `list [--status todo|doing|done|canceled] [--count N]` - List tickets
- `start [--worktree] [--copy-file <path>]... <ticket>` - Start working on ticket (--worktree creates a separate worktree; --copy-file appends paths to `worktree_copy_files` at invocation time)
- `close [--no-push] [--force] [--no-delete-remote] [--dry-run|-n] [--keep-worktree]` - Complete ticket
- `cancel [--force|-f] [--keep-worktree]` - Cancel ticket without merging
- `restore` - Rebuild the active-ticket symlinks (`current-ticket/`, `current-ticket.md`, `current-note.md`) from the current branch name

### Utility Commands
- `check` - Diagnose current state and provide guidance (checks git repo, config, tickets dir, active-ticket symlinks, worktree state)
- `version` / `--version` - Show version information
- `selfupdate` - Update to latest release from GitHub (checks GitHub releases, downloads new version, preserves config, fixes CRLF line endings)

### List Command Features
- **Status filtering**: `--status todo|doing|done|canceled` to filter by ticket status
- **Count limiting**: `--count N` to limit number of results displayed
- **Done tickets**: Sorted by completion date (newest first)
- **Timezone display**: Completion times shown in local timezone
- **Done folder**: Completed tickets automatically organized in `tickets/done/`

### List Command Output Format

```
Ticket Name                    Status   Created              Started              Closed
------------------------------ -------- -------------------- -------------------- --------------------
241229-123456-implement-auth   todo     2024-12-29 12:34:56  -                    -
241228-091530-fix-login-bug    doing    2024-12-28 09:15:30  2024-12-29 10:00:00  -
241227-183022-add-user-profile done     2024-12-27 18:30:22  2024-12-28 09:00:00  2024-12-29 14:30:00
```

### Close Command Options

| Option | Description |
|--------|-------------|
| `--no-push` | Skip pushing changes to remote repository |
| `--force` | Close without prompts (useful for CI/CD) |
| `--no-delete-remote` | Keep remote feature branch after closing |
| `--dry-run` \| `-n` | Show what would be done without making changes |
| `--keep-worktree` | Preserve worktree after closing (for --worktree mode) |
| `--no-merge` | Skip the squash-merge: assume the ticket's changes are already on the base branch (e.g. after a GitHub PR merge). Only set `closed_at`, move the ticket/note to `done/`, commit and push. Requires `<ticket-name>` as a positional argument. |
| `--closed-at <ISO8601-UTC>` | (with `--no-merge`) Set `closed_at` to an explicit ISO8601 UTC value, e.g. `2026-05-29T12:17:36Z`. Defaults to the current UTC time. |

### Finalizing a merged PR (`close --no-merge`)

When a PR is merged on GitHub, the ticket's changes are already on the base branch, so a squash-merge would fail. Use `--no-merge` to finalize the ticket in place:

```bash
ticket.sh close --no-merge [--closed-at <ISO8601-UTC>] [--no-push] <ticket-name>
```

This runs on the base branch (not the feature branch), takes the ticket name as an explicit argument (it does not rely on the active-ticket symlinks or the current branch), and is idempotent — re-running on an already-finalized ticket exits 0 without changes. Typical use is a GitHub Actions `pull_request: [closed]` trigger that passes `--closed-at "${{ github.event.pull_request.merged_at }}"` so `closed_at` records the actual merge time.

## Ticket File Format

Each ticket is a Markdown file with YAML frontmatter containing metadata:

```yaml
---
# Priority level (1-5, higher = more urgent)
priority: 2

# Base branch for creating feature branch
base_branch: "default"

# Human-readable description
description: ""

# Timestamps (UTC)
created_at: "2025-06-28T15:32:45Z"
started_at: null
closed_at: null
canceled_at: null
---
# Markdown body content starts here
# Describe the ticket details, tasks, acceptance criteria, etc.
```

### Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `priority` | integer | Priority level (1-5, higher = more urgent) |
| `base_branch` | string | Base branch for creating the feature branch (`default` uses config default) |
| `description` | string | Human-readable description of the ticket |
| `created_at` | timestamp | ISO 8601 UTC timestamp when ticket was created |
| `started_at` | timestamp | ISO 8601 UTC timestamp when work started (null until started) |
| `closed_at` | timestamp | ISO 8601 UTC timestamp when ticket was closed (null until closed) |
| `canceled_at` | timestamp | ISO 8601 UTC timestamp when ticket was canceled (null unless canceled) |

### Ticket Status

Tickets transition through these states:
- **todo**: `started_at` is null (not yet started)
- **doing**: `started_at` is set, `closed_at` and `canceled_at` are null (in progress)
- **done**: `closed_at` is set (completed successfully)
- **canceled**: `canceled_at` is set (abandoned without merging)

## Configuration

Edit `.ticket-config.yaml` (this is the author's actual production configuration):

```yaml
# Ticket system configuration

# Directory settings
tickets_dir: "tickets"

# Git settings
default_branch: "main"
branch_prefix: "feature/"
repository: "origin"

# Automatically push changes to remote repository during start and close
# Set to false if you want to manually control when to push
auto_push: true

# Skip Git hooks (--no-verify) on commits ticket.sh makes itself, such as the
# start-time stamp. Hooks run by default.
no_verify: false

# Automatically delete remote feature branch after closing ticket
# Set to false if you want to keep remote branches for history
delete_remote_on_close: true

# Worktree mode: create a separate git worktree for each ticket
# When true, 'start' always creates a worktree (same as --worktree flag)
# worktree_mode: false
# worktree_dir: ""  # Custom worktree base directory (default: ../<project>.worktrees/)

# Files copied from the main repo into a freshly-created worktree.
# Consulted only when 'start' actually creates a worktree. Existing files in
# the target are never overwritten; missing sources warn and continue.
# Assumes the listed files are gitignored (secrets stay local per user).
# One-shot entries can be added via --copy-file <path> (repeatable) on the
# command line.
# worktree_copy_files:
#   - .env
worktree_copy_files: []

# Success messages (leave empty to disable)
# Message displayed after starting work on a ticket
start_success_message: |
  Please review the ticket content in `current-ticket/ticket.md` and make any necessary adjustments before you begin work.
  Run ticket.sh list to view all todo tickets. For any related tasks that have already been prioritized, list them under the `## Notes` section.

# Message displayed after closing a ticket
close_success_message: |
  I've closed the ticket—please perform a backlog refinement.
  Run ticket.sh list to view all todo tickets; if you find any with overlapping content, review the corresponding ticket files.
  If you spot tasks that are already complete, update their tickets as needed.

# Note template (optional - if not defined, no note file will be created)
# Use this for debugging logs, investigation details, etc.
note_content: |
  # Work Notes for $$TICKET_NAME$$
  
  ## Implementation Details
  
  ...

  ## Task 1
  
  ...

# Ticket template
default_content: |
  # Ticket Overview

  {{Write the overview and tasks for this ticket here.}}

  ## Prerequisite

  {{List any prerequisites or dependencies for this ticket.}}


  ## Tasks

  **Note: After completing each task, you must run ./bin/test.sh and ensure all tests pass. No exceptions are allowed.**

  {{Organize tasks into phases based on logical groupings or concerns. Create one or more phases as appropriate.}}

  ### Phase 1: {{Phase name describing the concern/focus}}

  - [ ] {{Task 1}}
  - [ ] {{Task 2}}
  ...

  ### Phase 2: {{Phase name describing the concern/focus}}

  - [ ] {{Task 1}}
  - [ ] {{Task 2}}
  ...

  ### Phase N: {{Additional phases as needed}}

  ### Final Phase: Quality Assurance
  - [ ] Run unit tests (./bin/test.sh) and pass all tests (No exceptions)
  - [ ] Run integration tests (./bin/test-integration.sh) and pass all tests (No exceptions)
  - [ ] Run code review (./bin/code-review.sh)
  - [ ] Review and address all reviewer feedback
  - [ ] Update documentation and this ticket

  ## Acceptance Criteria

  {{Define the acceptance criteria for this ticket.}}


  ## Test Cases

  {{List test cases to verify the ticket's functionality.}}


  ## Parent ticket

  {{If this ticket is a sub-ticket, link to the parent ticket here.}}


  ## Child tickets

  {{If this ticket has child tickets, list them here.}}

  ## Review

  Please list here in full any remarks received from reviewers.
  Any corrections should also be added to the Tasks section at the top.


  ## Notes

  {{Additional notes or requirements.}}
```

## Advanced Features

### Smart Branch Handling
- **Existing branches**: Automatically checkout and restore instead of failing
- **Clean branches**: Create new branches from default branch when no changes exist
- **Conflict detection**: Provides guidance for handling merge conflicts during close

### Automatic Organization
- **Done folder**: Completed tickets moved to `tickets/done/<TICKETNAME>/` automatically (whole directory rename)
- **Remote cleanup**: Optional automatic deletion of remote feature branches

### Working Notes (Colocated)
- **`note.md` inside the per-ticket directory**: Debugging logs, investigation details, and progress notes live next to the ticket body — one directory, one work unit.
- **Configurable template**: `note_content` in config seeds a fresh `note.md` when a ticket is created.
- **Automatic management**: The note file moves with the ticket directory on close/cancel; the compat `current-note.md` symlink is created/removed automatically.
- **Git-ignored active symlinks**: `init` adds `current-ticket`, `current-ticket.md`, and `current-note.md` to `.gitignore` so they never get committed by accident.

### Worktree Support (Optional)
- **Parallel work**: Use `--worktree` flag with `start` to create a separate git worktree per ticket
- **Independent directories**: Each ticket gets its own working directory, no need to stash/commit when switching
- **Automatic cleanup**: `close` and `cancel` commands automatically remove the worktree
- **Config mode**: Set `worktree_mode: true` in config to always use worktrees
- **Custom directory**: Set `worktree_dir` in config to customize worktree location (default: `../<project>.worktrees/`)
- **Safe from any branch / any worktree**: `start --worktree` never modifies the caller's `HEAD` or working tree.
  It operates on the main repository via `git -C <main_repo> worktree add`, so it works correctly when:
  - You are on a feature branch with uncommitted changes (no stash, no checkout)
  - You are already inside another worktree (e.g. a previous ticket's worktree)
  - Multiple AI agents (Claude Code, etc.) are running in parallel from different worktrees
- **Populate worktree extras**: Set `worktree_copy_files: [".env"]` (or any list of repo-relative paths) in config to copy those files from the main repo into a freshly-created worktree. Existing files in the target are never overwritten; missing sources warn and continue. One-shot additions: `start --worktree --copy-file <path>` (repeatable). Intended for gitignored helpers like `.env` — the assumption is those files are gitignored, so each collaborator's own `.env` is copied into their own worktree and secrets stay local.

### Check Command Diagnostics

The `check` command verifies the following:

| Check | Description |
|-------|-------------|
| Git repository | Verifies current directory is a Git repository |
| Config file | Checks for `.ticket-config.yaml` or `.ticket-config.yml` |
| Tickets directory | Ensures `tickets/` directory exists |
| Current ticket | Validates the active-ticket symlinks (`current-ticket/`, `current-ticket.md`, `current-note.md`) |
| Working directory | Reports uncommitted changes |
| Worktree state | Shows active worktree if in use |
| Branch alignment | Verifies current branch matches expected state |

### Error Recovery
- **Check command**: Diagnose issues and get guidance on next steps
- **Restore command**: Rebuild symlinks and recover from interrupted operations  
- **Conflict resolution**: Resume operations after resolving merge conflicts

### Robustness Features
- **UTF-8 support**: Full Unicode support for all content and filenames
- **Permission resilience**: Graceful handling of file system permission issues
- **Network tolerance**: Operations continue locally even if remote push fails
- **Cross-platform**: Works on macOS, Linux, and other Unix-like systems

## Requirements

- Bash 3.2+
- Git
- Basic Unix tools

### Selfupdate Command

The `selfupdate` command:
- Fetches the latest release from GitHub
- Downloads the new `ticket.sh` file
- Preserves your existing configuration
- Automatically fixes CRLF line ending issues
- Maintains executable permissions

```
# Check for updates
./ticket.sh selfupdate

# With verbose output
./ticket.sh selfupdate --verbose
```

## For Developers

See [DEV.md](DEV.md) for:
- Architecture details
- Building from source
- Testing instructions
- Contributing guidelines

## License

MIT License - see LICENSE file
