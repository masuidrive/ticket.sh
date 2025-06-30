# ticket.sh - Git-Based Ticket Management System

A lightweight ticket management system that uses Git and markdown files. Perfect for solo developers and AI pair programming.

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

## Commands

- `init` - Initialize ticket system
- `new <slug>` - Create new ticket
- `list [--status todo|doing|done]` - List tickets
- `start <ticket> [--no-push]` - Start working on ticket
- `close [--no-push] [--force] [--no-delete-remote]` - Complete ticket
- `restore` - Restore current-ticket.md symlink

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

