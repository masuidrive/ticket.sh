---
priority: 2
tags: []
description: "Update README and documentation to reflect recent features and improvements"
created_at: "2025-07-10T05:27:54Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Ticket Overview

Update documentation (README.md, README.ja.md, spec files) to reflect recent features and improvements implemented in recent tickets. Need to review completed tickets since last documentation update and incorporate new features.

## Features to Document

Need to review ALL completed tickets and identify features/changes that should be reflected in documentation:

### Step 1: Review All Done Tickets
- [ ] Review all tickets in `tickets/done/` folder
- [ ] Check ticket descriptions and implementations
- [ ] Identify user-facing features and changes
- [ ] Note any breaking changes or important updates
- [ ] Categorize changes (new features, improvements, bug fixes)

### Step 2: Recently Completed (Known)
1. **Dynamic command name in messages** (current ticket)
   - Messages now show actual invocation method (bash ./ticket.sh vs ./ticket.sh)
   - Supports bash, sh, zsh, and other shells
   
2. **Done tickets descending sort** (250710-001634)
   - `ticket.sh list --status done` now shows most recently closed first
   - Sort order descriptions added to list output

3. **Current-ticket.md git history cleanup** (250710-014953)
   - Automatic removal of current-ticket.md from git history during close
   - Prevents accidental commits when force-added

## Tasks

### Phase 1: Discovery and Analysis
- [ ] List all tickets in `tickets/done/` folder
- [ ] Read each completed ticket's description and implementation details
- [ ] Create comprehensive list of features/changes since last documentation update
- [ ] Identify which changes are user-facing vs internal improvements
- [ ] Check when README.md was last significantly updated

### Phase 2: Documentation Updates
- [ ] Review README.md current content and structure
- [ ] Update README.md with all identified features and improvements
- [ ] Review README.ja.md and update Japanese documentation to match
- [ ] Update command examples to use dynamic command format where appropriate
- [ ] Update feature lists and capabilities sections
- [ ] Check for any spec files that need updates

### Phase 3: Validation
- [ ] Verify all examples work as documented
- [ ] Ensure consistency between English and Japanese versions
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing

## Files to Update

- [ ] README.md
- [ ] README.ja.md  
- [ ] Any spec or documentation files in docs/ (if exists)
- [ ] Check for other documentation files in project root

## Notes

Focus on user-facing changes and improvements. Technical implementation details are already documented in ticket files and code comments.
