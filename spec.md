**IMPORTANT**: When updating this file, also update spec.md files in other languages

- [English ver.](spec.md)
- [Japanese ver.](spec.ja.md)

---
# Ticket Management System Specification: ticket.sh

## 🎯 Purpose

A self-contained ticket management system using a single shell script + files + Git

- **Coding Agent Progress Management**: Primary purpose is managing Coding Agent work progress
- **Fully Self-Contained**: No external services or databases required
- **Git Flow Compliant**: Based on develop, feature/* branch structure
- **Simple Operations**: Ticket management with Markdown + YAML Front Matter

---

## 🚀 System Overview

### Ticket Management Mechanism

#### Ticket Name
- Ticket name format: `YYMMDD-hhmmss-<slug>`
- Used as base for filenames and branch names

#### File-Based Management
- Complete ticket in single file: `tickets/<ticket-name>.md`
- Metadata stored in YAML Front Matter section
- Ticket details written in Markdown body section

#### Minimal YAML Configuration
```yaml
priority: 2
description: ""
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
```

#### State Management
- **todo**: `started_at` is null
- **doing**: `started_at` is set and `closed_at` is null
- **done**: `closed_at` is set

#### Branch Integration
- Work performed on `feature/<ticket-name>` branches
- Current work ticket visualization via current-ticket.md

---

## 📖 Usage

### Initialize
```bash
./ticket.sh init
```
Generates required directories, configuration files, and .gitignore entries

### Create Ticket
```bash
./ticket.sh new <slug>
```
Creates empty ticket file, then edit to add title, description, and details

### Start Work
```bash
# Execute from default_branch
./ticket.sh start <ticket-file>
```
- Switches to corresponding feature branch
- Creates symlink to current-ticket.md
- Reference current-ticket.md while developing

### Restore Link
```bash
./ticket.sh restore
```
Auto-restores from branch name when current-ticket.md is lost after clone/pull

### Complete Work
```bash
./ticket.sh close <ticket-file>
```
- Squashes commits for organization
- Merges to default_branch
- Updates ticket status to completed

### List View
```bash
./ticket.sh list [--status todo|doing|done]
```
Displays ticket status list (default: todo+doing)

---

## 📁 Directory Structure

```
project-root/
├── tickets/                    # All ticket files (configurable)
│   └── 240628-153245-foo.md
├── current-ticket.md           # Symlink to working ticket (.gitignore'd)
├── ticket.sh                   # Main script
├── .ticket-config.yml          # Configuration file
└── .gitignore                  # Contains current-ticket.md
```

---

## ⚙️ Configuration File

### `.ticket-config.yml`
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

### Default Settings
```yaml
tickets_dir: "tickets"
default_branch: "develop"
branch_prefix: "feature/"
repository: "origin"
auto_push: true
default_content: |
  # Ticket Overview
  
  Write the overview and tasks for this ticket here.
  
  ## Tasks
  - [ ] Task 1
  - [ ] Task 2
  
  ## Notes
  Additional notes or requirements.
```

---

## 🧭 Command List

```bash
./ticket.sh init                          # Initialize
./ticket.sh new <slug>                    # Create ticket (slug: lowercase, numbers, hyphens only)
./ticket.sh list [--status todo|doing|done] [--count N]  # List tickets
./ticket.sh start <ticket-name> [--no-push]  # Start ticket/create branch
./ticket.sh restore                       # Restore current-ticket link
./ticket.sh close [--no-push] [--force|-f]  # Complete ticket/merge process
```

---

## 📝 Ticket File Structure

### Filename Format (Fixed)
```
YYMMDD-hhmmss-<slug>.md
Example: 240628-153245-create-post-handler.md
```

### YAML Front Matter
```yaml
---
priority: 2
tags: []
description: ""
created_at: "2025-06-28 15:32:45 UTC"
started_at: null
closed_at: null
---

# Ticket Title

Ticket details...
```

### State Determination Logic
- **todo**: `started_at` is null
- **doing**: `started_at` is set and `closed_at` is null  
- **done**: `closed_at` is set

---

## 🛠️ Detailed Command Specifications

### Common Error Cases
All commands perform these prerequisite checks:

**Required Conditions:**
- `.git` directory exists: 
  ```
  Error: Not in a git repository
  This directory is not a git repository. Please:
  1. Navigate to your project root directory, or
  2. Initialize a new git repository with 'git init'
  ```
- `.ticket-config.yml` exists: 
  ```
  Error: Ticket system not initialized
  Configuration file '.ticket-config.yml' not found. Please:
  1. Run 'ticket.sh init' to initialize the ticket system, or
  2. Navigate to the project root directory where the config exists
  ```

---

### `init`
Performs system initialization:

1. Creates `.ticket-config.yml` with default values (if not exists)
2. Creates `{tickets_dir}/` directory
3. Creates `.gitignore` file (if not exists) and adds `current-ticket.md` (with duplicate check)

**Note**: This command only skips configuration file existence check

**Error Cases:**
- Not a git repository: 
  ```
  Error: Not in a git repository
  This directory is not a git repository. Please:
  1. Navigate to your project root directory, or
  2. Initialize a new git repository with 'git init'
  ```
- No directory creation permission: 
  ```
  Error: Permission denied
  Cannot create directory '{tickets_dir}'. Please:
  1. Check file permissions in current directory, or
  2. Run with appropriate permissions (sudo if needed), or
  3. Choose a different location for tickets_dir in config
  ```

### `new <slug>`
Creates a new ticket:

- **slug constraints**: Only lowercase letters, numbers, hyphens (-) allowed
- Filename: `{tickets_dir}/YYMMDD-hhmmss-<slug>.md`
- Auto-inserts initial YAML Front Matter values
- Sets current time (ISO 8601 UTC) to `created_at`
- Inserts `default_content` from config to Markdown body
- Displays edit prompt message on completion

**Example:**
```bash
./ticket.sh new implement-auth
# Output: Created ticket file: tickets/240628-153245-implement-auth.md
#         Please edit the file to add title, description and details.
```

**Error Cases:**
- File already exists: 
  ```
  Error: Ticket already exists
  File '{filename}' already exists. Please:
  1. Use a different slug name, or
  2. Edit the existing ticket, or
  3. Remove the existing file if it's no longer needed
  ```
- No file creation permission: 
  ```
  Error: Permission denied
  Cannot create file '{filename}'. Please:
  1. Check write permissions in tickets directory, or
  2. Run with appropriate permissions, or
  3. Verify tickets directory exists and is writable
  ```
- Invalid slug: 
  ```
  Error: Invalid slug format
  Slug '{slug}' contains invalid characters. Please:
  1. Use only lowercase letters (a-z)
  2. Use only numbers (0-9)  
  3. Use only hyphens (-) for separation
  Example: 'implement-user-auth' or 'fix-bug-123'
  ```

**Generated Example:**
```yaml
---
priority: 2
tags: []
description: ""  # single line
created_at: "2025-06-28T15:32:45Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Ticket Overview

Write the overview and tasks for this ticket here.

## Tasks
- [ ] Task 1
- [ ] Task 2

## Notes
Additional notes or requirements.
```

### `list [--status todo|doing|done] [--count N]`
Displays ticket list:

- **Default**: Shows only `todo` and `doing` without `--status` specification
- **Default count**: `--count 20` (configurable)
- **Sort order**: Evaluated by `status` → `priority`
- State auto-determined from datetime fields

**Display Format:**
```yaml
📋 Ticket List
---------------------------
- status: doing
  ticket_name: 240628-153221-create-post-handler
  description: User authentication POST handler
  priority: 1
  created_at: 2025-06-27T10:30:00Z
  started_at: 2025-06-28T02:22:32Z

- status: todo
  ticket_name: 240628-153223-create-database-schema
  description: Initial table structure
  priority: 2
  created_at: 2025-06-27T09:00:00Z
```

**Error Cases:**
- Tickets directory doesn't exist: 
  ```
  Error: Tickets directory not found
  Directory '{tickets_dir}' does not exist. Please:
  1. Run 'ticket.sh init' to create required directories, or
  2. Check if you're in the correct project directory, or
  3. Verify tickets_dir setting in .ticket-config.yml
  ```
- Invalid status specification: 
  ```
  Error: Invalid status
  Status '{status}' is not valid. Please use one of:
  - todo (for unstarted tickets)
  - doing (for in-progress tickets)  
  - done (for completed tickets)
  ```
- Invalid count value: 
  ```
  Error: Invalid count value
  Count '{count}' is not a valid number. Please:
  1. Use a positive integer (e.g., --count 10)
  2. Or omit --count to use default (20)
  ```

### `start <ticket-name> [--no-push]`
Starts ticket work:

1. Sets current time to specified ticket's `started_at`
2. Creates Git branch as `{branch_prefix}<basename>`
3. Creates symlink to `current-ticket.md`
4. **Push control**: Executes `git push -u {repository} <branch>` only when `auto_push: true` and `--no-push` not specified
5. Displays executed Git commands and output in detail

**File Specification Flexibility:**
```bash
# All specify the same ticket
./ticket.sh start tickets/240628-153245-foo.md  # Full path
./ticket.sh start 240628-153245-foo.md         # Filename
./ticket.sh start 240628-153245-foo            # Ticket name
```

**Branch Name Example:**
- File: `240628-153245-create-api.md`
- Branch: `feature/240628-153245-create-api`

**Example Output (auto_push: true):**
```bash
$ ./ticket.sh start 240628-153245-implement-auth

# run command
git checkout -b feature/240628-153245-implement-auth
Switched to a new branch 'feature/240628-153245-implement-auth'

# run command
git push -u origin feature/240628-153245-implement-auth
Total 0 (delta 0), reused 0 (delta 0), pack-reused 0
To github.com:user/repo.git
 * [new branch]      feature/240628-153245-implement-auth -> feature/240628-153245-implement-auth
Branch 'feature/240628-153245-implement-auth' set up to track remote branch 'feature/240628-153245-implement-auth' from 'origin'.

Started ticket: 240628-153245-implement-auth
Current ticket linked: current-ticket.md -> tickets/240628-153245-implement-auth.md
```

**Example Output (auto_push: false or --no-push):**
```bash
$ ./ticket.sh start 240628-153245-implement-auth --no-push

# run command
git checkout -b feature/240628-153245-implement-auth
Switched to a new branch 'feature/240628-153245-implement-auth'

Started ticket: 240628-153245-implement-auth
Current ticket linked: current-ticket.md -> tickets/240628-153245-implement-auth.md
Note: Branch not pushed to remote. Use 'git push -u origin feature/240628-153245-implement-auth' when ready.
```

**Error Cases:**
- Ticket file doesn't exist: 
  ```
  Error: Ticket not found
  Ticket '{filename}' does not exist. Please:
  1. Check the ticket name spelling
  2. Run 'ticket.sh list' to see available tickets
  3. Use 'ticket.sh new <slug>' to create a new ticket
  ```
- Ticket already started: 
  ```
  Error: Ticket already started
  Ticket has already been started (started_at is set). Please:
  1. Continue working on the existing branch
  2. Use 'ticket.sh restore' to restore current-ticket.md link
  3. Or close the current ticket first if starting over
  ```
- Branch already exists: 
  ```
  Error: Branch already exists
  Branch '{branch_name}' already exists. Please:
  1. Switch to existing branch: git checkout {branch_name}
  2. Or delete existing branch if no longer needed
  3. Use 'ticket.sh restore' to restore ticket link
  ```
- Git working directory is dirty: 
  ```
  Error: Uncommitted changes
  Working directory has uncommitted changes. Please:
  1. Commit your changes: git add . && git commit -m "message"
  2. Or stash changes: git stash
  3. Then retry the ticket operation
  ```
- Executed from non-default_branch: 
  ```
  Error: Wrong branch
  Must be on '{default_branch}' branch to start new ticket. Please:
  1. Switch to {default_branch}: git checkout {default_branch}
  2. Or complete current ticket with 'ticket.sh close'
  3. Then retry starting the new ticket
  ```

### `restore`
Restores current-ticket link:

- Searches for corresponding ticket file from current Git branch
- Deletes existing `current-ticket.md` and creates new symlink
- Cannot execute from non-`{branch_prefix}*` branches

**Error Cases:**
```
Error: Not on a feature branch
Current branch '{current_branch}' is not a feature branch. Please:
1. Switch to a feature branch (feature/*)
2. Or start a new ticket: ticket.sh start <ticket-name>
3. Feature branches should start with '{branch_prefix}'
```

```
Error: No matching ticket found
No ticket file found for branch '{branch_name}'. Please:
1. Check if ticket file exists in {tickets_dir}/
2. Ensure branch name matches ticket name format
3. Or start a new ticket if this is a new feature
```

```
Error: Cannot create symlink
Permission denied creating symlink. Please:
1. Check write permissions in current directory
2. Ensure no file named 'current-ticket.md' exists
3. Run with appropriate permissions if needed
```

### `close [--no-push]`
Completes ticket and merge process:

**Execution Flow:**
1. **Update ticket**: Sets current time to `closed_at` of ticket referenced by current-ticket.md
2. **Commit**: Commits with `"Close ticket"` message
3. **Push (conditional)**: Pushes feature branch only when `auto_push: true` and `--no-push` not specified
4. **Squash Merge**: Squash merges feature branch to `{default_branch}`
5. **Push (conditional)**: Pushes `{default_branch}` only when `auto_push: true` and `--no-push` not specified
6. Displays executed Git commands and output in detail

**Git Operation Details:**
```bash
# 1. Update ticket
update_yaml_field "$ticket_file" "closed_at" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# 2. Commit
git add "$ticket_file"
git commit -m "Close ticket"

# 3. Push (conditional)
if [[ $auto_push == true && $no_push != true ]]; then
    git push {repository} current-branch
fi

# 4. squash merge
git checkout {default_branch}
git merge --squash current-branch
git commit -m "[ticket-name] description\n\n$(cat ticket-file)"

# 5. Push (conditional)
if [[ $auto_push == true && $no_push != true ]]; then
    git push {repository} {default_branch}
fi
```

**Example Output (auto_push: true):**
```bash
$ ./ticket.sh close

# run command
git add tickets/240628-153245-implement-auth.md

# run command
git commit -m "Close ticket"
[feature/240628-153245-implement-auth 1a2b3c4] Close ticket
 1 file changed, 1 insertion(+), 1 deletion(-)

# run command
git push origin feature/240628-153245-implement-auth
Total 3 (delta 1), reused 0 (delta 0), pack-reused 0
To github.com:user/repo.git
   abc123..1a2b3c4  feature/240628-153245-implement-auth -> feature/240628-153245-implement-auth

# run command
git checkout develop
Switched to branch 'develop'
Your branch is up to date with 'origin/develop'.

# run command
git merge --squash feature/240628-153245-implement-auth
Updating abc123..1a2b3c4
Fast-forward
Squash commit -- not updating HEAD

# run command
git commit -m "[240628-153245-implement-auth] User authentication implementation

<ticket file content here>"
[develop 5d6e7f8] [240628-153245-implement-auth] User authentication implementation
 3 files changed, 45 insertions(+), 2 deletions(-)

# run command
git push origin develop
Total 4 (delta 2), reused 0 (delta 0), pack-reused 0
To github.com:user/repo.git
   abc123..5d6e7f8  develop -> develop

Ticket completed: 240628-153245-implement-auth
Merged to develop branch
```

**Example Output (auto_push: false or --no-push):**
```bash
$ ./ticket.sh close --no-push

# run command
git add tickets/240628-153245-implement-auth.md

# run command
git commit -m "Close ticket"
[feature/240628-153245-implement-auth 1a2b3c4] Close ticket
 1 file changed, 1 insertion(+), 1 deletion(-)

# run command
git checkout develop
Switched to branch 'develop'
Your branch is up to date with 'origin/develop'.

# run command
git merge --squash feature/240628-153245-implement-auth
Updating abc123..1a2b3c4
Fast-forward
Squash commit -- not updating HEAD

# run command
git commit -m "[240628-153245-implement-auth] User authentication implementation

<ticket file content here>"
[develop 5d6e7f8] [240628-153245-implement-auth] User authentication implementation
 3 files changed, 45 insertions(+), 2 deletions(-)

Ticket completed: 240628-153245-implement-auth
Merged to develop branch
Note: Changes not pushed to remote. Use 'git push origin develop' and 'git push origin feature/240628-153245-implement-auth' when ready.
```

**Error Cases:**
- current-ticket.md doesn't exist: 
  ```
  Error: No current ticket
  No current ticket found (current-ticket.md missing). Please:
  1. Start a ticket: ticket.sh start <ticket-name>
  2. Or restore link: ticket.sh restore (if on feature branch)
  3. Or switch to a feature branch first
  ```
- current-ticket.md is invalid link: 
  ```
  Error: Invalid current ticket
  Current ticket file not found or corrupted. Please:
  1. Use 'ticket.sh restore' to fix the link
  2. Or start a new ticket: ticket.sh start <ticket-name>
  3. Check if ticket file was moved or deleted
  ```
- Executed from non-feature branch: 
  ```
  Error: Not on a feature branch
  Must be on a feature branch to close ticket. Please:
  1. Switch to feature branch: git checkout feature/<ticket-name>
  2. Or check current branch: git branch
  3. Feature branches start with '{branch_prefix}'
  ```
- Ticket not started: 
  ```
  Error: Ticket not started
  Ticket has no start time (started_at is null). Please:
  1. Start the ticket first: ticket.sh start <ticket-name>
  2. Or check if you're on the correct ticket
  ```
- Ticket already completed: 
  ```
  Error: Ticket already completed
  Ticket is already closed (closed_at is set). Please:
  1. Check ticket status: ticket.sh list
  2. Start a new ticket if needed
  3. Or reopen by manually editing the ticket file
  ```
- Git working directory is dirty: 
  ```
  Error: Uncommitted changes
  Working directory has uncommitted changes. Please:
  1. Commit your changes: git add . && git commit -m "message"
  2. Review changes: git status
  3. Then retry closing the ticket
  ```
- Push failed: 
  ```
  Error: Push failed
  Failed to push to '{repository}'. Please:
  1. Check network connection
  2. Verify repository permissions
  3. Try manual push: git push {repository} <branch>
  4. Check if remote repository exists
  ```

**Merge Commit Message Format:**
```
[240628-153245-create-post-handler] User authentication POST handler

---
priority: 2
tags: []
description: "User authentication POST handler"
created_at: "2025-06-28T15:32:45Z"
started_at: "2025-06-28T16:15:30Z"
closed_at: "2025-06-28T18:45:20Z"
---

# Create POST handler for user authentication

Implementation details...
```

---

## ✅ Expected Operation Flow

1. **Initialize**: `./ticket.sh init`
2. **Create ticket**: `./ticket.sh new implement-auth`
3. **Start work**: `./ticket.sh start 240628-153245-implement-auth`
4. **Development work**: Commit and push with regular Git operations
5. **Complete process**: `./ticket.sh close`
6. **Result**: Organized merge commit added to develop branch

---

## 🤖 Help for Coding Agents

Execute `./ticket.sh` without arguments to display usage information:

```
Ticket Management System for Coding Agents

OVERVIEW:
This is a self-contained ticket management system using shell script + files + Git.
Each ticket is a single Markdown file with YAML frontmatter metadata.

USAGE:
  ./ticket.sh init                     Initialize system (create config, directories, .gitignore)
  ./ticket.sh new <slug>               Create new ticket file (slug: lowercase, numbers, hyphens only)
  ./ticket.sh list [--status STATUS] [--count N]  List tickets (default: todo + doing, count: 20)
  ./ticket.sh start <ticket-name> [--no-push]     Start working on ticket (creates feature branch)
  ./ticket.sh restore                  Restore current-ticket.md symlink from branch name
  ./ticket.sh close [--no-push]       Complete current ticket (squash merge to default branch)

TICKET NAMING:
- Format: YYMMDD-hhmmss-<slug>
- Example: 241225-143502-implement-user-auth
- Generated automatically when creating tickets

TICKET STATUS:
- todo: not started (started_at: null)
- doing: in progress (started_at set, closed_at: null)
- done: completed (closed_at set)

CONFIGURATION:
- Config file: .ticket-config.yml (in project root)
- Initialize with: ./ticket.sh init
- Edit to customize directories, branches, and templates

PUSH CONTROL:
- Set auto_push: false in config to disable automatic pushing
- Use --no-push flag to override auto_push: true for single command
- Git commands and outputs are displayed for transparency

WORKFLOW:
1. Create ticket: ./ticket.sh new feature-name
2. Edit ticket content and description
3. Start work: ./ticket.sh start 241225-143502-feature-name
4. Develop on feature branch (current-ticket.md shows active ticket)
5. Complete: ./ticket.sh close

TROUBLESHOOTING:
- Run from project root (where .git and .ticket-config.yml exist)
- Use 'restore' if current-ticket.md is missing after clone/pull
- Check 'list' to see available tickets and their status
- Ensure Git working directory is clean before start/close

Note: current-ticket.md is git-ignored and needs 'restore' after clone/pull.
```