# ticket.sh - Git-Based Ticket Management System

A lightweight, robust ticket management system that uses Git branches and markdown files. Perfect for solo developers, small teams, and AI pair programming.

## Key Features
- 🎯 **Simple workflow**: Create, start, work, close
- 📝 **Markdown tickets**: Rich formatting with YAML frontmatter
- 🌿 **Git integration**: Automatic branch management per ticket
- 📁 **Smart organization**: Auto-organized done folder, timezone-aware timestamps
- 🔧 **Zero dependencies**: Pure Bash + Git, works everywhere
- 🚀 **AI-friendly**: Designed for seamless AI assistant collaboration
- 🛡️ **Robust**: UTF-8 support, error recovery, conflict resolution
- 📓 **Work notes separation**: Optional separate note files for debugging/investigation logs

**Language versions**: [English](README.md) | [日本語](README.ja.md)

## Quick Start

### Download
```bash
curl -O https://raw.githubusercontent.com/masuidrive/ticket.sh/main/ticket.sh
chmod +x ticket.sh
```

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
4. **Close ticket**: `./ticket.sh close`

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
- `new <slug>` - Create new ticket
- `list [--status todo|doing|done] [--count N]` - List tickets
- `start <ticket> [--no-push]` - Start working on ticket
- `close [--no-push] [--force] [--no-delete-remote]` - Complete ticket
- `restore` - Restore current-ticket.md symlink

### Utility Commands
- `check` - Diagnose current state and provide guidance
- `version` / `--version` - Show version information
- `selfupdate` - Update to latest release from GitHub

### List Command Features
- **Status filtering**: `--status todo|doing|done` to filter by ticket status
- **Count limiting**: `--count N` to limit number of results displayed
- **Done tickets**: Sorted by completion date (newest first)
- **Timezone display**: Completion times shown in local timezone
- **Done folder**: Completed tickets automatically organized in `tickets/done/`

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

# Automatically push changes to remote repository during close command
# Set to false if you want to manually control when to push
auto_push: true

# Automatically delete remote feature branch after closing ticket
# Set to false if you want to keep remote branches for history
delete_remote_on_close: true

# Success messages (leave empty to disable)
# Message displayed after starting work on a ticket
start_success_message: |
  Please review the ticket content in `current-ticket.md` and make any necessary adjustments before you begin work.
  Run ticket.sh list to view all todo tickets. For any related tasks that have already been prioritized, list them under the `## Notes` section.

# Message displayed after closing a ticket
close_success_message: |
  I've closed the ticket—please perform a backlog refinement.
  Run ticket.sh list to view all todo tickets; if you find any with overlapping content, review the corresponding `tickets/*.md` files.
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
- **Done folder**: Completed tickets moved to `tickets/done/` automatically
- **Remote cleanup**: Optional automatic deletion of remote feature branches

### Work Notes Separation (Optional)
- **Separate note files**: Keep debugging logs and investigation details in separate `*-note.md` files
- **Clean tickets**: Main ticket files stay concise and focused on requirements
- **Automatic management**: Note files are created, moved, and linked automatically
- **Backward compatible**: Only enabled when `note_content` is defined in config
- **Git history**: Prevents accidental commits of `current-ticket.md`

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

## For Developers

See [DEV.md](DEV.md) for:
- Architecture details
- Building from source
- Testing instructions
- Contributing guidelines

## License

MIT License - see LICENSE file
