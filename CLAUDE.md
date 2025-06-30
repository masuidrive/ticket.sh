# 書き換えていいソースコード
- src/、yaml-sh/、lib/のソースコードのみ書き換えてください
- project rootの`ticket.sh`は、`build.sh`から生成されるので直接書き換えないようにしてください

# Ticket Management Instructions

Use `./ticket.sh` for ticket management. When receiving requests from users,
create tickets and perform work within tickets. Even small user requests
should be documented in `current-ticket.md` while progressing.

## Create New Ticket

1. Create ticket: `./ticket.sh new feature-name`
2. Edit ticket content and description in the generated file

## Start Working on Ticket

1. Check available tickets: `./ticket.sh list` or browse tickets directory
2. Start work: `./ticket.sh start 241225-143502-feature-name`
3. Develop on feature branch (current-ticket.md shows active ticket)

## Ticket Closing

1. Before closing:
 - Review ticket content and description
 - Check all tasks in checklist are completed (mark with `[x]`)
 - Get user approval before proceeding
2. Complete: `./ticket.sh close`
