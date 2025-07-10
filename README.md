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

**Language versions**: [English](README.md) | [日本語](README.ja.md)

## Quick Start

```bash
# Download pre-built script
curl -O https://raw.githubusercontent.com/masuidrive/ticket.sh/main/ticket.sh
chmod +x ticket.sh

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
./build.sh
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

Edit `.ticket-config.yml`:

```yaml
tickets_dir: "tickets"
default_branch: "develop"
branch_prefix: "feature/"
auto_push: true

# Remote branch cleanup settings
# When enabled, automatically deletes the remote feature branch after closing a ticket.
# This prevents GitHub's "Compare & pull request" banner from appearing for already-merged branches.
# Set to false if you want to keep remote branches for historical reference.
delete_remote_on_close: true  # Default: true

# Success messages
start_success_message: |
  Please review the ticket content in `current-ticket.md` and make any
  necessary adjustments before beginning work.

close_success_message: |
  # Empty by default
```

## Advanced Features

### Smart Branch Handling
- **Existing branches**: Automatically checkout and restore instead of failing
- **Clean branches**: Create new branches from default branch when no changes exist
- **Conflict detection**: Provides guidance for handling merge conflicts during close

### Automatic Organization
- **Done folder**: Completed tickets moved to `tickets/done/` automatically
- **Remote cleanup**: Optional automatic deletion of remote feature branches
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

# New change on main
