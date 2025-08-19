**重要**: このファイルを更新した場合、他言語のspec.mdファイルも変更すること

- [English ver.](spec.md)
- [Japanese ver.](spec.ja.md)

---
# チケット管理システム仕様書：ticket.sh

## 🎯 目的

1つのシェルスクリプトとファイル+Gitで完結するチケット管理システム

- **Coding Agent進行管理**: Coding Agentの作業進行管理が主目的
- **完全セルフコンテインド**: 外部サービスやデータベース不要
- **Git Flow準拠**: develop, feature/* ブランチを基本とする構成
- **シンプルな運用**: Markdown + YAML Front Matter でチケット管理

---

## 📋 システム要件

- **Bash**: バージョン3.2以上（5.1+でテスト済み）
- **Git**: 最近のバージョン
- **標準UNIXコマンド**: ls, ln, sed, grep など
- **文字エンコーディング**: UTF-8サポート必須
  - ticket.shは自動的にUTF-8ロケールを設定 (LANG=C.UTF-8, LC_ALL=C.UTF-8)
  - チケットのタイトル、説明、内容でUTF-8をサポート
  - ロケール非依存の動作を保証

---

## 🚀 システム概要

### チケット管理の仕組み

#### チケット名
- チケット名は `YYMMDD-hhmmss-<slug>` 形式
- これがファイル名のベースおよびブランチ名に使用される

#### ファイルベース管理
- `tickets/<チケット名>.md` の1ファイルでチケットが完結
- オプション: `tickets/<チケット名>-note.md` 作業ノートファイル（`note_content`設定時）
- YAML Front Matter部分にメタ情報を格納
- Markdownボディ部分にチケット詳細を記述

#### 最小YAML構成
```yaml
priority: 2
description: ""
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
```

#### 状態管理
- **todo**: `started_at` が null
- **doing**: `started_at` 設定済み かつ `closed_at` が null
- **done**: `closed_at` 設定済み

#### ブランチ連携
- 作業は `feature/チケット名` ブランチで実施
- current-ticket.md による現在作業チケットの可視化
- current-note.md による作業ノートの可視化（note_content設定時）

---

## 📖 使用方法

### 初期化
```bash
./ticket.sh init
```
必要なディレクトリ、設定ファイル、.gitignoreエントリを生成

### チケット作成
```bash
./ticket.sh new <slug>
```
空のチケットファイルを作成後、エディタでタイトル・description・詳細内容を記入

### 作業開始
```bash
# default_branchから実行
./ticket.sh start <ticket-file>
```
- 対応するfeatureブランチに移動
- current-ticket.md にsymlinkを作成
- current-note.md にsymlinkを作成（ノートファイル存在時）
- 作業中は current-ticket.md と current-note.md を参照して開発

### リンク復元
```bash
./ticket.sh restore
```
clone/pull後など、current-ticket.mdが失われた際にブランチ名から自動復元

### 作業完了
```bash
./ticket.sh close [--no-push] [--force|-f]
```
- コミットをsquashして整理
- default_branchにマージ
- チケット状態を完了に更新
- チケットファイルを `tickets/done/` フォルダに移動

### 一覧表示
```bash
./ticket.sh list [--status todo|doing|done] [--count N]
```
チケット状況を一覧表示（デフォルトはtodo+doing）

**出力フォーマット:**
```
📋 Ticket List
---------------------------
- status: doing
  ticket_path: tickets/240628-153245-implement-auth.md
  description: ユーザー認証の実装
  priority: 1
  created_at: 2025-06-28T15:32:45Z
  started_at: 2025-06-28T16:15:30Z

- status: todo
  ticket_path: tickets/240628-162130-add-tests.md
  description: 認証モジュールのユニットテストを追加
  priority: 2
  created_at: 2025-06-28T16:21:30Z

- status: done
  ticket_path: tickets/done/240627-142030-setup-project.md
  description: プロジェクトの初期設定
  priority: 1
  created_at: 2025-06-27T14:20:30Z
  started_at: 2025-06-27T14:25:00Z
  closed_at: 2025-06-27T15:45:20Z
```

**注意**: 
- `ticket_path` はプロジェクトルートからの相対パスを表示
- `closed_at` はdoneチケットのみ表示
- 完了したチケットは `tickets/done/` フォルダに移動されます

---

## 📁 ディレクトリ構成

```
project-root/
├── tickets/                    # 全チケットファイル（設定可能）
│   ├── 240628-153245-foo.md    # アクティブ/todoチケット
│   └── done/                   # 完了済みチケット（自動作成）
│       └── 240627-142030-bar.md
├── current-ticket.md           # 作業中チケットへのsymlink (.gitignore対象)
├── ticket.sh                   # メインスクリプト
├── .ticket-config.yaml         # 設定ファイル
└── .gitignore                  # current-ticket.md を含む
```

---

## ⚙️ 設定ファイル

### `.ticket-config.yaml`
```yaml
# ディレクトリ設定
tickets_dir: "tickets"

# Git設定
default_branch: "develop" 
branch_prefix: "feature/"
repository: "origin"
auto_push: true

# チケットテンプレート
default_content: |
  # Ticket Overview
  
  Write the overview and tasks for this ticket here.
  
  ## Tasks
  - [ ] Task 1
  - [ ] Task 2
  
  ## Notes
  Additional notes or requirements.
```

### デフォルト設定
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

## 🧭 コマンド一覧

```bash
./ticket.sh init                          # 初期化
./ticket.sh new <slug>                    # チケット作成 (slug: lowercase, numbers, hyphens only)
./ticket.sh list [--status todo|doing|done] [--count N]  # チケット一覧
./ticket.sh start <ticket-name> [--no-push]  # チケット開始・ブランチ作成
./ticket.sh restore                       # current-ticketリンク復元
./ticket.sh close [--no-push] [--force|-f]  # チケット完了・マージ処理
```

---

## 📝 チケットファイル構造

### ファイル名形式（固定）
```
YYMMDD-hhmmss-<slug>.md
例: 240628-153245-create-post-handler.md
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

# チケットタイトル

チケットの詳細内容...
```

### 状態判定ロジック
- **todo**: `started_at` が null
- **doing**: `started_at` が設定済み かつ `closed_at` が null  
- **done**: `closed_at` が設定済み

---

## 🛠️ コマンド詳細仕様

### 共通エラーケース
全コマンドで以下の前提条件チェックを実行：

**必須条件:**
- `.git` ディレクトリの存在: 
  ```
  Error: Not in a git repository
  This directory is not a git repository. Please:
  1. Navigate to your project root directory, or
  2. Initialize a new git repository with 'git init'
  ```
- 設定ファイルの存在: 
  ```
  Error: Ticket system not initialized
  Configuration file not found. Please:
  1. Run 'ticket.sh init' to initialize the ticket system, or
  2. Navigate to the project root directory where the config exists
  ```

---

### `init`
システムの初期化を実行：

1. `.ticket-config.yaml` をデフォルト値で作成（存在しない場合）
2. `{tickets_dir}/` ディレクトリを作成
3. `.gitignore` ファイルを作成（存在しない場合）し、`current-ticket.md` を追加（重複チェック）

**注意**: このコマンドのみ設定ファイルの存在チェックをスキップ

**エラーケース:**
- Git リポジトリではない場合: 
  ```
  Error: Not in a git repository
  This directory is not a git repository. Please:
  1. Navigate to your project root directory, or
  2. Initialize a new git repository with 'git init'
  ```
- ディレクトリ作成権限がない場合: 
  ```
  Error: Permission denied
  Cannot create directory '{tickets_dir}'. Please:
  1. Check file permissions in current directory, or
  2. Run with appropriate permissions (sudo if needed), or
  3. Choose a different location for tickets_dir in config
  ```

### `new <slug>`
新しいチケットを作成：

- **slug制約**: 英小文字、数字、ハイフン(-) のみ使用可能
- ファイル名: `{tickets_dir}/YYMMDD-hhmmss-<slug>.md`
- YAML Front Matter の初期値を自動挿入
- `created_at` に現在時刻（ISO 8601 UTC）を設定
- 設定ファイルの `default_content` をMarkdownボディに挿入
- 完了時に編集を促すメッセージを表示

**実行例:**
```bash
./ticket.sh new implement-auth
# 出力: Created ticket file: tickets/240628-153245-implement-auth.md
#       Please edit the file to add title, description and details.
```

**エラーケース:**
- 同名ファイルが既に存在: 
  ```
  Error: Ticket already exists
  File '{filename}' already exists. Please:
  1. Use a different slug name, or
  2. Edit the existing ticket, or
  3. Remove the existing file if it's no longer needed
  ```
- ファイル作成権限がない: 
  ```
  Error: Permission denied
  Cannot create file '{filename}'. Please:
  1. Check write permissions in tickets directory, or
  2. Run with appropriate permissions, or
  3. Verify tickets directory exists and is writable
  ```
- slugが無効: 
  ```
  Error: Invalid slug format
  Slug '{slug}' contains invalid characters. Please:
  1. Use only lowercase letters (a-z)
  2. Use only numbers (0-9)  
  3. Use only hyphens (-) for separation
  Example: 'implement-user-auth' or 'fix-bug-123'
  ```

**生成例:**
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
チケット一覧を表示：

- **デフォルト**: `--status` 指定なしで `todo` と `doing` のみ表示
- **デフォルト件数**: `--count 20` （変更可能）
- **ソート順**: `status` → `priority` の順で評価
- 状態は日時フィールドから自動判定
- **複数の --status フラグ**: 複数の `--status` フラグが指定された場合、最後のものが優先される

**表示形式:**
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

**エラーケース:**
- チケットディレクトリが存在しない: 
  ```
  Error: Tickets directory not found
  Directory '{tickets_dir}' does not exist. Please:
  1. Run 'ticket.sh init' to create required directories, or
  2. Check if you're in the correct project directory, or
  3. 設定ファイルでtickets_dir設定を確認
  ```
- 無効なステータス指定: 
  ```
  Error: Invalid status
  Status '{status}' is not valid. Please use one of:
  - todo (for unstarted tickets)
  - doing (for in-progress tickets)  
  - done (for completed tickets)
  ```
- 無効なcount値: 
  ```
  Error: Invalid count value
  Count '{count}' is not a valid number. Please:
  1. Use a positive integer (e.g., --count 10)
  2. Or omit --count to use default (20)
  ```

### `start <ticket-name> [--no-push]`
チケット作業を開始：

1. 指定チケットの `started_at` に現在時刻を設定
2. Gitブランチを `{branch_prefix}<basename>` として作成
3. `current-ticket.md` にsymlinkを作成
4. **Push制御**: `auto_push: true` かつ `--no-push` 未指定時のみ `git push -u {repository} <branch>` を実行
5. 実行したGitコマンドと出力を詳細表示

**ファイル指定の柔軟性:**
```bash
# すべて同じチケットを指定
./ticket.sh start tickets/240628-153245-foo.md  # フルパス
./ticket.sh start 240628-153245-foo.md         # ファイル名
./ticket.sh start 240628-153245-foo            # チケット名
```

**ブランチ名例:**
- ファイル: `240628-153245-create-api.md`
- ブランチ: `feature/240628-153245-create-api`

**実行例出力 (auto_push: true):**
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

**実行例出力 (auto_push: false or --no-push):**
```bash
$ ./ticket.sh start 240628-153245-implement-auth --no-push

# run command
git checkout -b feature/240628-153245-implement-auth
Switched to a new branch 'feature/240628-153245-implement-auth'

Started ticket: 240628-153245-implement-auth
Current ticket linked: current-ticket.md -> tickets/240628-153245-implement-auth.md
Note: Branch not pushed to remote. Use 'git push -u origin feature/240628-153245-implement-auth' when ready.
```

**エラーケース:**
- チケットファイルが存在しない: 
  ```
  Error: Ticket not found
  Ticket '{filename}' does not exist. Please:
  1. Check the ticket name spelling
  2. Run 'ticket.sh list' to see available tickets
  3. Use 'ticket.sh new <slug>' to create a new ticket
  ```
- チケットが既に開始済み: 
  ```
  Error: Ticket already started
  Ticket has already been started (started_at is set). Please:
  1. Continue working on the existing branch
  2. Use 'ticket.sh restore' to restore current-ticket.md link
  3. Or close the current ticket first if starting over
  ```
- ブランチが既に存在: 
  ```
  Error: Branch already exists
  Branch '{branch_name}' already exists. Please:
  1. Switch to existing branch: git checkout {branch_name}
  2. Or delete existing branch if no longer needed
  3. Use 'ticket.sh restore' to restore ticket link
  ```
- Git作業ディレクトリが汚い: 
  ```
  Error: Uncommitted changes
  Working directory has uncommitted changes. Please:
  1. Commit your changes: git add . && git commit -m "message"
  2. Or stash changes: git stash
  3. Then retry the ticket operation
  ```
- default_branch以外から実行: 
  ```
  Error: Wrong branch
  Must be on '{default_branch}' branch to start new ticket. Please:
  1. Switch to {default_branch}: git checkout {default_branch}
  2. Or complete current ticket with 'ticket.sh close'
  3. Then retry starting the new ticket
  ```

### `restore`
current-ticketリンクを復元：

- 現在のGitブランチから対応するチケットファイルを探索
- 既存の `current-ticket.md` は削除してから新しいsymlinkを作成
- `{branch_prefix}*` ブランチ以外からは実行不可

**エラーケース:**
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

### `close [--no-push] [--force|-f]`
チケット完了とマージ処理：

**オプション:**
- `--no-push`: 自動プッシュを無効化（`auto_push: true` の場合でも）
- `--force` / `-f`: コミットされていない変更を無視して強制的にクローズ

**実行フロー:**
1. **作業ディレクトリチェック**: `--force` 未指定時のみ、コミットされていない変更がないか確認
2. **チケット更新**: current-ticket.md の参照先チケットの `closed_at` に現在時刻を設定
3. **コミット**: `"Close ticket"` メッセージでコミット
4. **Push (条件付き)**: `auto_push: true` かつ `--no-push` 未指定時のみ featureブランチをpush
5. **Squash Merge**: featureブランチを `{default_branch}` にsquash merge
6. **Push (条件付き)**: `auto_push: true` かつ `--no-push` 未指定時のみ `{default_branch}` をpush
7. 実行したGitコマンドと出力を詳細表示

**Git操作詳細:**
```bash
# 1. チケット更新
update_yaml_field "$ticket_file" "closed_at" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# 2. コミット
git add "$ticket_file"
git commit -m "Close ticket"

# 3. Push (条件付き)
if [[ $auto_push == true && $no_push != true ]]; then
    git push {repository} current-branch
fi

# 4. squash merge
git checkout {default_branch}
git merge --squash current-branch
git commit -m "[ticket-name] description\n\n$(cat ticket-file)"

# 5. Push (条件付き)
if [[ $auto_push == true && $no_push != true ]]; then
    git push {repository} {default_branch}
fi
```

**実行例出力 (auto_push: true):**
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

**実行例出力 (auto_push: false or --no-push):**
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

**エラーケース:**
- current-ticket.mdが存在しない: 
  ```
  Error: No current ticket
  No current ticket found (current-ticket.md missing). Please:
  1. Start a ticket: ticket.sh start <ticket-name>
  2. Or restore link: ticket.sh restore (if on feature branch)
  3. Or switch to a feature branch first
  ```
- current-ticket.mdが無効なリンク: 
  ```
  Error: Invalid current ticket
  Current ticket file not found or corrupted. Please:
  1. Use 'ticket.sh restore' to fix the link
  2. Or start a new ticket: ticket.sh start <ticket-name>
  3. Check if ticket file was moved or deleted
  ```
- featureブランチ以外から実行: 
  ```
  Error: Not on a feature branch
  Must be on a feature branch to close ticket. Please:
  1. Switch to feature branch: git checkout feature/<ticket-name>
  2. Or check current branch: git branch
  3. Feature branches start with '{branch_prefix}'
  ```
- チケットが未開始: 
  ```
  Error: Ticket not started
  Ticket has no start time (started_at is null). Please:
  1. Start the ticket first: ticket.sh start <ticket-name>
  2. Or check if you're on the correct ticket
  ```
- チケットが既に完了済み: 
  ```
  Error: Ticket already completed
  Ticket is already closed (closed_at is set). Please:
  1. Check ticket status: ticket.sh list
  2. Start a new ticket if needed
  3. Or reopen by manually editing the ticket file
  ```
- Git作業ディレクトリが汚い: 
  ```
  Error: Uncommitted changes
  Working directory has uncommitted changes. Please:
  1. Commit your changes: git add . && git commit -m "message"
  2. Or stash changes: git stash
  3. Then retry the ticket operation
  
  To ignore uncommitted changes and force close, use:
    ticket.sh close --force (or -f)
  
  Or handle the changes:
    1. Commit your changes: git add . && git commit -m "message"
    2. Stash changes: git stash
    3. Discard changes: git checkout -- .
  ```
- Push失敗: 
  ```
  Error: Push failed
  Failed to push to '{repository}'. Please:
  1. Check network connection
  2. Verify repository permissions
  3. Try manual push: git push {repository} <branch>
  4. Check if remote repository exists
  ```

**マージコミットメッセージ形式:**
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

## ✅ 期待される運用フロー

1. **初期化**: `./ticket.sh init`
2. **チケット作成**: `./ticket.sh new implement-auth`
3. **作業開始**: `./ticket.sh start 240628-153245-implement-auth`
4. **開発作業**: 通常のGit操作でコミット・プッシュ
5. **完了処理**: `./ticket.sh close`
6. **結果**: developブランチに整理されたマージコミットが追加される

---

## 🤖 Coding Agent向けヘルプ

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
  ./ticket.sh close [--no-push] [--force|-f]  Complete current ticket (squash merge to default branch)

TICKET NAMING:
- Format: YYMMDD-hhmmss-<slug>
- Example: 241225-143502-implement-user-auth
- Generated automatically when creating tickets

TICKET STATUS:
- todo: not started (started_at: null)
- doing: in progress (started_at set, closed_at: null)
- done: completed (closed_at set)

CONFIGURATION:
- Config file: .ticket-config.yaml または .ticket-config.yml (プロジェクトルート内)
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
- プロジェクトルートから実行 (.git と設定ファイルが存在する場所)
- Use 'restore' if current-ticket.md is missing after clone/pull
- Check 'list' to see available tickets and their status
- Ensure Git working directory is clean before start/close

Note: current-ticket.md is git-ignored and needs 'restore' after clone/pull.
```

---

## 🛡️ エラーハンドリングと耐障害性

### YAMLパース動作

システムはYAMLフロントマターの処理において耐障害性を重視した設計：

- **グレースフルデグラデーション**: 破損または無効なYAMLファイルを適切に処理
- **部分的パース**: パーサーは不正なYAMLからも可能な限りデータを抽出
- **サイレントスキップ**: `list` コマンドはパースできないチケットを静かにスキップ
- **厳密な検証なし**: システムは厳密なYAML準拠よりも動作継続を優先

**処理されるシナリオの例:**
- 閉じられていない引用符やブラケット
- 無効なインデント
- 終了デリミタ（`---`）の欠落
- 非標準的なデータ型
- 破損したフロントマター構造

**注意**: システムは破損したYAMLでも動作を継続しますが、予期しない結果を生む可能性があります。チケットファイルが適切にフォーマットされていることを常に確認してください。

---

## 🔒 実装上の制限事項

### スラグの制約
- **形式**: 小文字(a-z)、数字(0-9)、ハイフン(-)のみ使用可能
- **パターン**: `^[a-z0-9-]+$` に一致する必要がある
- **長さ**: 明示的な最大長の制限なし（100文字までテスト済み）

### YAMLパーサーの制限
- ネストされたオブジェクトや複雑なデータ構造はサポートなし
- YAMLアンカー、エイリアス、タグはサポートなし
- フラットな構造のみサポート
- 複数行文字列の処理に制限あり

### 操作上の制約
- gitリポジトリのルートから実行する必要がある
- start/closeには作業ディレクトリがクリーンである必要がある（`--force` 使用時を除く）
- 既に開始されたチケットは開始できない
- 未開始のチケットはクローズできない
- current-ticketシンボリックリンクはclone/pull後に手動での復元が必要

### プラットフォーム要件
- Bash 3.2以上
- UTF-8ロケールサポート（自動設定）
- 標準UNIXコマンド: git, awk, sed, grep, ln, date, mktemp

### 制限が設けられていない項目
- チケット数
- チケットファイルサイズ
- 説明文やコンテンツの長さ
- ファイルパスやブランチ名の長さ