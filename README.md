# ticket.sh - Git-Based Ticket Management System

A self-contained ticket management system using shell script, files, and Git. Perfect for managing coding tasks, especially when working with AI coding assistants.

**IMPORTANT**: When updating this file, also update README.md files in other languages

- [English ver.](README.md)
- [Japanese ver.](README.ja.md)

## Overview

ticket.sh is a lightweight ticket management system that:
- Uses Markdown files with YAML frontmatter for tickets
- Integrates with Git Flow (develop/feature branches)
- Requires no external services or databases
- Compiles to a single portable shell script
- Works on macOS and Linux with Bash 3.2+

## Quick Start

```bash
# Build the single-file executable (from project root)
./build.sh

# Initialize in your project
./ticket.sh init

# Create a new ticket
./ticket.sh new implement-auth

# Start working on a ticket
./ticket.sh start 241229-123456-implement-auth

# Complete and merge the ticket
./ticket.sh close
```

## Installation

### Option 1: Download Pre-built Script
```bash
curl -O https://raw.githubusercontent.com/masuidrive/ticket.sh/main/ticket.sh
chmod +x ticket.sh
```

### Option 2: Build from Source
```bash
git clone https://github.com/masuidrive/ticket.sh.git
cd ticket.sh
./build.sh
cp ticket.sh /usr/local/bin/  # Or anywhere in your PATH
```

## Workflow

1. **Initialize** the ticket system in your Git repository:
   ```bash
   ticket.sh init
   ```

2. **Create** a new ticket:
   ```bash
   ticket.sh new implement-user-auth
   # Creates: tickets/241229-123456-implement-user-auth.md
   ```

3. **Edit** the ticket file to add description and tasks:
   ```bash
   vim tickets/241229-123456-implement-user-auth.md
   ```

4. **Start** working on the ticket:
   ```bash
   ticket.sh start 241229-123456-implement-user-auth
   # Creates branch: feature/241229-123456-implement-user-auth
   # Creates symlink: current-ticket.md -> tickets/241229-123456-implement-user-auth.md
   ```

5. **Develop** your feature with regular commits

6. **Close** the ticket when done:
   ```bash
   ticket.sh close
   # Squash merges to develop branch
   # Updates ticket status to completed
   # Moves ticket to tickets/done/ folder
   ```

## Commands

### `ticket.sh init`
Initializes the ticket system in your repository
- Creates `.ticket-config.yml` configuration file
- Creates `tickets/` directory
- Updates `.gitignore`

### `ticket.sh new <slug>`
Creates a new ticket file
- `slug`: lowercase letters, numbers, and hyphens only
- Generates filename: `YYMMDD-hhmmss-<slug>.md`

### `ticket.sh list [options]`
Lists tickets with filtering options
- `--status todo|doing|done`: Filter by status
- `--count N`: Limit number of results (default: 20)
- Default shows only `todo` and `doing` tickets
- Shows `ticket_path` (relative path from project root)
- Displays `closed_at` for done tickets

### `ticket.sh start <ticket-name> [--no-push]`
Starts work on a ticket
- Creates feature branch
- Updates ticket's `started_at` timestamp
- Creates `current-ticket.md` symlink
- Use `--no-push` to skip automatic push

### `ticket.sh restore`
Restores the `current-ticket.md` symlink
- Useful after clone/pull operations
- Automatically detects ticket from current branch

### `ticket.sh close [--no-push] [--force|-f]`
Completes the current ticket
- Updates ticket's `closed_at` timestamp
- Squash merges to develop branch
- Moves ticket file to `tickets/done/` folder
- Removes `current-ticket.md` symlink
- Use `--no-push` to skip automatic push
- Use `--force` or `-f` to bypass uncommitted changes check

## Testing

Run all tests:
```bash
# From project root
test/run-all.sh

# From test directory
cd test && ./run-all.sh

# Run tests in Docker environments (Ubuntu and Alpine)
test/run-all-on-docker.sh
```

## Configuration

Edit `.ticket-config.yml` to customize:

```yaml
# Directory settings
tickets_dir: "tickets"

# Git settings
default_branch: "develop"
branch_prefix: "feature/"
repository: "origin"
auto_push: true

# Ticket template
default_content: |
  # Ticket Overview
  
  Write the overview and tasks for this ticket here.
  
  ## Tasks
  - [ ] Task 1
  - [ ] Task 2
  
  ## Notes
  Additional notes or requirements.
```

## Ticket Structure

Each ticket is a Markdown file with YAML frontmatter:

```markdown
---
priority: 2
tags: []
description: "Brief description"
created_at: "2024-12-29T12:34:56Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Ticket Title

Detailed description and requirements...

## Tasks
- [ ] Implementation task 1
- [ ] Implementation task 2
- [ ] Write tests
- [ ] Update documentation
```

## Status Management

Ticket status is automatically determined:
- **todo**: `started_at` is null
- **doing**: `started_at` is set, `closed_at` is null
- **done**: `closed_at` is set

## Git Integration

- Works with Git Flow (develop → feature/* → develop)
- All Git commands are displayed for transparency
- Automatic push can be disabled globally or per-command
- Squash merge keeps commit history clean

## Building from Source

The project structure:
```
ticket-sh/
├── src/
│   └── ticket.sh      # Main script
├── lib/
│   ├── yaml-sh.sh     # YAML parser
│   ├── yaml-frontmatter.sh
│   └── utils.sh
├── test/              # Test suites
├── spec.md            # English specification
├── spec.ja.md         # Japanese specification
└── README.md          # This file
```

To build (from project root):
```bash
./build.sh
# Creates: ticket.sh (single executable file)
```

## Testing

Run the test suites:
```bash
cd ticket-sh/test
./test-final.sh      # Core functionality tests
./test-additional.sh # Edge cases and error conditions
```

## Use Cases

- **Solo Development**: Track personal tasks and TODOs
- **AI Pair Programming**: Provide context to AI assistants
- **Small Teams**: Lightweight alternative to issue trackers
- **Feature Branch Workflow**: Enforce consistent Git practices

## Requirements

- Bash 3.2 or higher
- Git
- Basic Unix tools (awk, sed, grep)

## License

MIT License - see LICENSE file for details

