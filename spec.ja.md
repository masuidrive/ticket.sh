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

#### per-ticket ディレクトリレイアウト

各チケットは `tickets/` 配下の自分専用ディレクトリに置く：

```
tickets/
  <TICKETNAME>/
    ticket.md   # チケット本体（YAML frontmatter + Markdown）
    note.md     # 作業ノート／ログ
    tmp/        # ticket-local 一時 helper（start/restore で自動作成、tickets/.gitignore で git 除外）
  done/
    <TICKETNAME>/   # close/cancel されたチケット — ディレクトリごと移動
```

- メタ情報は `ticket.md` の YAML frontmatter に格納。
- チケット詳細・タスク・受け入れ条件は `ticket.md` の Markdown 本文に書く。
- `note.md` は同一ディレクトリの自由記述ログ（進捗、デバッグ、調査ノート）。初期内容は config の `note_content` テンプレートから生成される。
- `tmp/` は `start` / `restore` で自動的に作成され、その中身は `<tickets_dir>/.gitignore`（`init` が生成）で git 除外される。ticket-local な scratch ファイル、agent の作業用 script、コミットしたくない一時 helper の置き場に使う。
- `close` / `cancel` は `tickets/<TICKETNAME>/` を `tickets/done/<TICKETNAME>/` へディレクトリごと移動（`cancel` はディレクトリ名に `-CANCELED-` を挿入）。この rename と `closed_at`／`cancelled_at` 追記は単一 Git commit にまとまる。

**レガシー互換**: 旧版で作られたフラット形式チケット
(`tickets/<TICKETNAME>.md` + `tickets/<TICKETNAME>-note.md`) はすべての
コマンドで従来どおり動作する。自動移行は行わない。

#### 最小YAML構成
```yaml
priority: 2
base_branch: default  # start/close時のベースブランチを上書き（default: configのdefault_branchを使用）
description: ""
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null  # Do not modify manually
```

#### 状態管理
- **todo**: `started_at` が null
- **doing**: `started_at` 設定済み かつ `closed_at` が null かつ `canceled_at` が null
- **done**: `closed_at` 設定済み
- **canceled**: `canceled_at` 設定済み

**状態は YAML frontmatter だけに置く。** ticket.sh は状態記録用のサイドカーファイル
（`tickets/.state.json` 等）を持たないし、今後も追加しない。この種のファイルは gitignore
される前提になるため、clone をまたいで残らず、共同作業者にも worktree にも CI にも届かない。
それでいて frontmatter が既に記録している内容を二重に持つことになり、両者がずれたときに
どちらが正しいか決める手段がない。チケットについて知る価値のあることは、チケットと一緒に
コミットする。

`start` が `started_at` を feature branch のコミットとして記録し、base branch をそこへ
fast-forward するのはこのためである。二つ目の真実を作らずに、どちらのブランチから見ても
`doing` と読めるようにしている。

**feature branch にしか記録が無い場合。** fast-forward はスキップされることがあり
（`start` を参照）、その場合 `started_at` は feature branch にしか載らない。そのため
base branch 上で `todo` と判定されたチケットは、そのチケットの branch（`branch:` があれば
その値、無ければ `{branch_prefix}<name>`）を確認してから判断する。そのブランチが存在し、そちらの ticket ファイルに `started_at` があれば `doing` と
して扱い、`list` は `started_at_only_on: <branch>` を出力して、時刻がどこにあるか、そして
base branch 側のファイルはまだ `null` であることを示す。この fallback が読むのはブランチで
あって傍らに置いた state ファイルではないので、真実が git の中だけにある構造は保たれる。

#### ブランチ連携
- 作業は `feature/<チケット名>` ブランチ、または frontmatter の `branch:` が指すブランチで実施
- `start` はリポジトリ直下に 3 本の symlink を作成してアクティブチケットを指す：
  - `current-ticket/` → `tickets/<TICKETNAME>/`（dir symlink）
  - `current-ticket.md` → `tickets/<TICKETNAME>/ticket.md`（互換 file symlink）
  - `current-note.md` → `tickets/<TICKETNAME>/note.md`（互換 file symlink）
- レガシーフラット形式チケットの場合、file symlink 2 本のみ作成（指すべき per-ticket ディレクトリが無いため）。

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

# worktree使用（別ディレクトリを作成）
./ticket.sh start --worktree <ticket-file>
```
- 対応する feature ブランチに移動（`--worktree` 指定時は worktree を作成）
- アクティブチケット symlink 群（`current-ticket/`、`current-ticket.md`、`current-note.md`）を作成
- `Active ticket paths:` ブロックを emit（layout・ticket・note・新形式なら ticket_dir/tmp_dir・すべての symlink 対応）— 下流エージェントが出力だけで解決可能
- 作業中は `current-ticket/ticket.md`・`current-ticket/note.md`（または互換 `current-ticket.md`／`current-note.md`）を参照して開発
- `--worktree` 使用時: 別作業ディレクトリを作成し、メインリポジトリはデフォルトブランチのまま

### リンク復元
```bash
./ticket.sh restore
```
現在の feature ブランチ名からアクティブチケット symlink 群（`current-ticket/`、`current-ticket.md`、`current-note.md`）を再構築する — clone／pull／手動ブランチ切り替え後に有用。`start` と同じ `Active ticket paths:` ブロックも emit する。

### 作業完了
```bash
./ticket.sh close [--no-push] [--force|-f]
```
- コミットを squash して整理
- default_branch にマージ
- チケット状態を完了に更新（同一 commit で `closed_at` を stamp）
- `tickets/<TICKETNAME>/` ディレクトリを `tickets/done/<TICKETNAME>/` へ丸ごと移動（レガシーフラット形式チケットの場合は `.md` と、存在すれば `-note.md` を移動）
- すべてのアクティブチケット symlink を削除

### 作業キャンセル
```bash
./ticket.sh cancel [--force|-f]
```
- マージせずにチケットをキャンセル
- `canceled_at` タイムスタンプを設定し、description に `[CANCELED]` プレフィックスを追加
- チケットディレクトリを `tickets/done/<YYMMDD-hhmmss>-CANCELED-<slug>/` へ移動（レガシー形式は `.md` ファイル名を `-CANCELED-` プレフィックスで rename）
- デフォルトブランチに切り替え（feature ブランチは保持）
- すべてのアクティブチケット symlink を削除

### 一覧表示
```bash
./ticket.sh list [--status todo|doing|done|canceled] [--count N]
```
チケット状況を一覧表示（デフォルトはtodo+doing、canceledは除外）

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
  worktree: /path/to/project.worktrees/240628-153245-implement-auth  # worktree使用時に表示

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
├── tickets/                             # 全チケットディレクトリ（設定可能）
│   ├── 240628-153245-foo/               # アクティブ／todo per-ticket ディレクトリ
│   │   ├── ticket.md                    #   チケット本体
│   │   ├── note.md                      #   作業ノート／ログ
│   │   └── tmp/                         #   ticket-local 一時 helper（自動作成、git 除外）
│   └── done/                            # 完了／キャンセル済みチケット（自動作成）
│       └── 240627-142030-bar/           #   ディレクトリごと移動
│           ├── ticket.md
│           └── note.md
├── current-ticket/                      # アクティブチケット dir symlink (.gitignore 対象)
├── current-ticket.md                    # 互換 file symlink → current-ticket/ticket.md (.gitignore 対象)
├── current-note.md                      # 互換 file symlink → current-ticket/note.md (.gitignore 対象)
├── ticket.sh                            # メインスクリプト
├── .ticket-config.yaml                  # 設定ファイル
└── .gitignore                           # current-ticket, current-ticket.md, current-note.md を含む
```

**レガシー互換**: 旧版のフラット形式 (`tickets/<TICKETNAME>.md` +
`tickets/<TICKETNAME>-note.md`) は `list`／`start`／`close`／`cancel`／
`restore`／`check` すべてで従来どおり認識される。両レイアウトは
`tickets/` 内で同居してよい。

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
auto_push: true          # close で push する

# ticket.sh 自身が作るコミット（start の開始時刻記録など）で Git hook を
# スキップする（--no-verify）。既定では hook を実行する。
no_verify: false

# ticket の Tasks か note のチェックリストに未記入が残っている間は close を止める。
# 既定は false。既存の ticket / note には未記入が大量に残っているので、既定で
# 有効にすると全員が突然 close できなくなる。
require_checklist: false

# 「無ければならない見出し」の一覧。require_checklist は未記入を数えるので、節ごと
# 無いと数える対象がゼロになり「全部片付いた」と区別がつかない。ここに挙げた見出しが
# どちらのファイルにも無ければ close を止め、その下に未記入が残っている場合も止める。
# 既定は空。require_checklist とは独立。
# require_checklist_groups:
#   - "Required Probes"

# new が ticket dir に作る、note.md 以外の追加ファイル。各要素は ticket dir 相対の
# path と、その初期内容 content。content では note_content と同じく
# $$TICKET_NAME$$ / $$NOTE_PATH$$ が置換される。既存ファイルは上書きしない。
# note.md の要素を書いた場合は note_content より優先される。
# ticket_files:
#   - path: progress.md
#     content: |
#       # Progress: $$TICKET_NAME$$

# ticket dir の中で「追記しかしてはいけない」ファイル。かつてそのファイルにあった行が
# 今そこに無ければ close が止まる。plain check は同じ内容を表示するだけで落ちない。
# --force では迂回できない。既定は空。
# append_only_files:
#   - progress.md

# Worktreeモード（オプション）
# worktree_mode: false    # trueの場合、startは常にworktreeを作成
# worktree_dir: ""        # カスタムworktreeベースディレクトリ

# start が worktree を作成した直後に main repo からコピーするファイル群。
# target 側に同名ファイルがあれば skip、source に無ければ warn のみ。
# gitignore 前提(各人の秘密は各人の worktree にコピーされるだけで拡散しない)。
# CLI からは --copy-file <path>(反復可)でワンショット追加。
worktree_copy_files: []
# 例:
# worktree_copy_files:
#   - .env

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
no_verify: false
require_checklist: false
require_checklist_groups: []
ticket_files: []
append_only_files: []
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
./ticket.sh new <slug> [--branch <name>]  # チケット作成 (slug: lowercase, numbers, hyphens only); --branch overrides the feature branch name
./ticket.sh list [--status todo|doing|done] [--count N]  # チケット一覧
./ticket.sh start [--worktree] [--copy-file <path>]... <ticket-name>  # チケット開始・ブランチ作成（--worktreeで別ディレクトリ、--copy-fileでworktree_copy_filesエントリ追加）
./ticket.sh restore                       # current-ticketリンク復元
./ticket.sh check [--require "<group name>"]  # 同期状態 + ticket/note のチェックリスト（--require は1グループだけ判定）
./ticket.sh close [--no-push] [--force|-f]  # チケット完了・マージ処理
./ticket.sh cancel [--force|-f]           # マージせずにチケットをキャンセル
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
base_branch: default  # start/close時のベースブランチを上書き（default: configのdefault_branchを使用）
branch: agent/issue-12  # 任意。この ticket の feature branch 名を上書きする
description: ""
created_at: "2025-06-28 15:32:45 UTC"
started_at: null
closed_at: null
canceled_at: null
---

# チケットタイトル

チケットの詳細内容...
```

**`branch`** は明示的に指定したときだけ書かれる（`new --branch <name>`、または
手書き）。この行が無い ticket は従来どおり `{branch_prefix}<ticket-name>` を使う。
設定されている場合、`start` はその branch が既にあれば checkout し、無ければ作る。
`check` / `restore` / `list` / `close` / `cancel` はいずれもその branch と ticket を
対応付ける。`branch_prefix` の意味は変わらない（`branch:` が無いときの既定）。

これは、branch 名の由来が外にあるケース — issue 番号から `agent/issue-12` を組み立て、
ticket が存在する前に checkout してしまう CI bot など — を、コマンドを迂回せずに
通常どおり扱うためのもの。

### 状態判定ロジック
- **todo**: `started_at` が null
- **doing**: `started_at` が設定済み かつ `closed_at` が null かつ `canceled_at` が null
- **done**: `closed_at` が設定済み
- **canceled**: `canceled_at` が設定済み

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
3. `.gitignore` ファイルを作成（存在しない場合）し、`current-ticket.md`、`current-note.md`、`current-ticket`（per-ticket レイアウトの dir symlink）を追加（重複チェック）

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

### `new <slug> [--branch <name>]`
新しいチケットを作成：

- **slug制約**: 英小文字、数字、ハイフン(-) のみ使用可能
- ファイル名: `{tickets_dir}/YYMMDD-hhmmss-<slug>.md`
- YAML Front Matter の初期値を自動挿入
- `created_at` に現在時刻（ISO 8601 UTC）を設定
- 設定ファイルの `default_content` をMarkdownボディに挿入
- config の `ticket_files` に挙げたファイルを ticket dir に作成（後述）
- 完了時に編集を促すメッセージを表示

**`--branch <name>`** は frontmatter に `branch: <name>` を書き込み、この ticket の
feature branch を `{branch_prefix}<ticket-name>` ではなくその名前にする。名前は
`git check-ref-format --branch` で検証し、加えて `-` 始まりと `@{` を含むものを拒否する
（後者は git が拒否せず解決してしまうため）。不正な名前は何も作る前に拒否する。

**追加ファイル（`ticket_files`）**

`note_content` が作れる付属ファイルは `note.md` ただ 1 つ。2 つめ — note とは別に
持つ経緯ログなど — が欲しいプロジェクトは `ticket_files` に宣言する:

```yaml
ticket_files:
  - path: progress.md
    content: |
      # Progress: $$TICKET_NAME$$

      経緯は追記のみ。現在値は $$NOTE_PATH$$ に置く。
  - path: docs/design.md
    content: |
      # Design: $$TICKET_NAME$$
```

- `path` は ticket dir 相対。サブディレクトリは必要に応じて作る。ticket dir の外に
  出るもの（絶対パス、`..` を含むもの）は警告して skip する。
- `content` では `note_content` と同じ `$$TICKET_NAME$$` / `$$NOTE_PATH$$` が置換される。
- 既存ファイルは上書きしない。
- `note.md` の要素は `note_content` より優先され、note と同じ経路で 1 回だけ書かれる。
- flat（旧レイアウト）の ticket には作らない。置く先のディレクトリが無いため。
- `start` / `restore` は実在するファイルを `Active ticket paths:` に 1 行ずつ出すので、
  そのブロックだけ読んだ agent もファイルの所在が分かる。

`ticket_files` が未定義なら `new` の挙動は従来と完全に同じ。

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
base_branch: default  # start/close時のベースブランチを上書き（default: configのdefault_branchを使用）
description: ""  # single line
created_at: "2025-06-28T15:32:45Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null  # Do not modify manually
---

# Ticket Overview

Write the overview and tasks for this ticket here.

## Tasks
- [ ] Task 1
- [ ] Task 2

## Notes
Additional notes or requirements.
```

### `list [--status todo|doing|done|canceled] [--count N]`
チケット一覧を表示：

- **デフォルト**: `--status` 指定なしで `todo` と `doing` のみ表示（canceledは除外）
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
  - canceled (for canceled tickets)
  ```
- 無効なcount値: 
  ```
  Error: Invalid count value
  Count '{count}' is not a valid number. Please:
  1. Use a positive integer (e.g., --count 10)
  2. Or omit --count to use default (20)
  ```

### `start [--worktree] [--copy-file <path>]... <ticket-name>`
チケット作業を開始：

1. 指定チケットの `started_at` に現在時刻を設定
2. Gitブランチを `{branch_prefix}<basename>` として作成。frontmatter に `branch:` があればその branch を使う。いずれの場合も、既に存在する branch は作り直さず checkout する（後述の **再開**）。これが、他者が先に作った branch をそのまま引き受けられる理由
3. その記録を feature branch に `[start] {branch}` としてコミットし、base branch をそのコミットへ fast-forward（後述の **開始時刻の記録** を参照）
4. アクティブチケット symlink 群を作成: `current-ticket/`（dir symlink、新形式のみ）、`current-ticket.md`、`current-note.md`。加えて `Active ticket paths:` ブロックを emit（下流エージェントが解決済みパスを消費できる。実在する `ticket_files` のエントリも 1 行ずつ出る）
5. 実行したGitコマンドと出力を詳細表示

**オプション:**
- `--worktree`: ブランチ切り替えの代わりに別のgit worktreeを作成。メインリポジトリはデフォルトブランチのまま。worktreeは `../<プロジェクト名>.worktrees/<チケット名>/`（またはconfigの`worktree_dir`）に作成
- `--copy-file <path>` (反復可): その呼び出し限定で `worktree_copy_files` に path を追加。worktree が実際に作成された場合のみ参照される。

**開始時刻の記録:**

この処理が無いと `started_at` は feature branch のワーキングツリーにしか存在せず、base
branch から `list` してもチケットは `todo` のままに見える。これは worktree モード固有の
問題ではなく、in-place モードでも base branch に戻れば同じことが起きる。

- 記録は feature branch にコミットし、そのコミットへ **base branch** を fast-forward する。base branch はチケットに `base_branch` があればそれ、無ければ `default_branch`。
- base branch に直接書くのではなく「feature branch でコミットして fast-forward」する形にしているのは `close` を壊さないため。merge base が一緒に進むので、close の差分プリフライトは base 側の ticket file 変更を検出せず、squash merge も上書き対象のローカル変更を見つけない。
- fast-forward の方法は worktree モードかどうかではなく、**base branch がどこかにチェックアウトされているか**で決まる。チェックアウト済みならその作業ツリーで `merge --ff-only`、どこにも無ければ `fetch . <feature>:<base>`。両者は排他。
- `new` が作ったチケットは untracked（`new` はコミットしない）。そのままでは fast-forward を妨げるため、事前に base branch 側の作業ツリーから取り除く。ただし `start` が読んだ時点と同じ内容である場合に限る（＝失われるものが無いことを確認してから消す）。
- fast-forward は best-effort。base branch が先に進んでいたり、その作業ツリーに競合する変更があれば、その旨を報告して処理を続行する。`started_at` はいずれにせよ feature branch にコミットされている。`list` は feature branch を読みにいく（後述）ので、fast-forward の失敗で失われるのは base branch 側の ticket ファイルの内容であって、チケットの見え方ではない。なお base branch に追い越された fast-forward は retry しても成功しない。feature branch は base branch の新しい commit を含まないため、そもそも fast-forward ではなくなっているからである。
- **push は一切行わない。** `start` は作業の開始を宣言するものであって base branch を publish する操作ではない。そこに未 push の commit があれば巻き込んで出てしまう（複数 worktree が base を共有する repo では他人の commit を含みうる）。base branch がリモートに出るのは `close` のとき。
- このコミットでは Git hook が実行される。config の `no_verify: true` でスキップできる。
- 開始済みチケットの resume では再記録は行わない。

**Worktreeモード:**
- configで `worktree_mode: true` を設定すると常時有効化
- worktreeモード使用時、`close`と`cancel`コマンドがworktreeを自動検出・削除
- `list`コマンドがアクティブなチケットのworktreeパスを表示

**Worktree へのファイルコピー (`worktree_copy_files`):**
- `start` が worktree を実際に作成した場合にのみ参照される。
- 各エントリは main repo ワーキングツリー相対の path。
- source が無い → stderr に warn、続行。
- target に同名ファイルが既にある → skip(絶対に上書きしない)。
- 上記以外 → `cp -p` でコピーし、stdout に 1 行ログを出す。
- gitignore されたファイル前提(各人自身の `.env` が各人の worktree にコピーされるだけで secret は拡散しない)。
- CLI からは `--copy-file <path>` (反復可) で config を触らずにワンショット追加できる。

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

**実行例出力:**
```bash
$ ./ticket.sh start 240628-153245-implement-auth

# run command
git checkout -b feature/240628-153245-implement-auth
Switched to a new branch 'feature/240628-153245-implement-auth'

# run command
git -C "." commit -m "[start] feature/240628-153245-implement-auth" -- "tickets/240628-153245-implement-auth/ticket.md" "tickets/240628-153245-implement-auth/note.md"
[feature/240628-153245-implement-auth 059de0d] [start] feature/240628-153245-implement-auth

Recorded start time on 'main'.
Started ticket: 240628-153245-implement-auth
Current ticket linked: current-ticket.md -> tickets/240628-153245-implement-auth/ticket.md
Note: Branch created locally. Use 'git push -u origin feature/240628-153245-implement-auth' when ready to share.
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
- branch の解決は 2 段階: まず `{branch_prefix}` を剥がし、それに対応する ticket が無ければ、frontmatter の `branch:` がこの branch を名指ししている ticket を探す
- 既存の `current-ticket.md` は削除してから新しいsymlinkを作成
- `{branch_prefix}` も付かず、どの ticket の `branch:` にも名指しされていない branch からは実行不可

**エラーケース:**
```
Error: Not on a feature branch
Current branch '{current_branch}' is not a feature branch. Please:
1. Switch to a feature branch (feature/*)
2. Or set 'branch: {current_branch}' in the ticket's frontmatter to claim it
3. Or start a new ticket: ticket.sh start <ticket-name>
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

### `check [--require "<group name>"]`
チケットとブランチの同期状態を報告し、現在のブランチに対応する開始済みチケットが
あれば current-ticket リンクを復元する。あわせて ticket が持つ2つのファイルの
チェックリストの状態を報告する。

**チェックリスト**

ticket が持つ2つのファイルはどちらもチェックボックスを持ちうるが、それが埋まったかを
誰も見ていなかった。

| ファイル | チェックリスト |
|---|---|
| `ticket.md` | `## Tasks` のリスト。既定のテンプレートに最初から入っている |
| `note.md` | プロジェクトが note テンプレートに置いたもの |

両方の雛形を配っているのは ticket.sh なので、埋まったかを見られるのは ticket.sh だけ
である。

- **2つのファイルを両方読み、分けて扱う**。レポートはファイルごとに分かれ、同じ見出しが
  両方にあっても別グループのままになる。どちらのファイルを直せばよいかが出力から分かる。
- **ticket の YAML frontmatter は飛ばす**。飛ばさないと、複数行の `description` の中の
  `- [ ]` を拾ってしまう。note は frontmatter を持たないのでそのまま読む。stripper を
  通すと、1行目の水平線を frontmatter の開始と誤認する危険がある。
- **グループ**。チェックボックスは、その行より前にある最も近い heading（レベル不問）
  に属する。グループ名は heading の文字列そのものなので、ticket.sh はグループの
  意味を知らなくてよい。最初の heading より前にあるものは `(ungrouped)` に入る。
- **3 状態**

  | 記法 | 意味 | 判定 |
  |---|---|---|
  | `- [x] ...` | 済み | 通す |
  | `- [ ] ...` | 未記入 | 止める |
  | `- [-] ... - skip: <理由>` | この ticket には該当しない | 理由があれば通す |

  理由の無い `[-]` は未記入として扱う。理由が無ければ、作業を飛ばしたのと区別が
  つかないため。`skip:` の直前のダッシュは必須ではなく、大小文字も問わない。
  この語彙に無いマーカー（`[~]`、`[/]` など）は、意味を推測せず無視する。
- **skip は分子に数える**。件数は別に出す（`4 / 4  done (1 skipped)`）。
- **コードブロックの中は数えない**。フェンス（バッククォート／チルダ）と字下げの
  両方が対象。作業ログである note は、自分が配られたテンプレートをそのまま引用する
  ことが普通にある。ただし**リストの中の 4 カラム字下げはコードではなくリスト項目の
  継続**なので、ネストしたチェックボックスは数える。そうしないと、字下げするだけで
  項目が静かに検査対象から消えてしまう。
- Setext heading（`===` や `---` の下線）は heading として扱わない。note の水平線と
  区別がつかないため。

**オプション:**
- `--require "<group name>"`: そのグループだけを判定し、未記入があれば exit 1。
  「いまどの段階か」を知っているのは呼ぶ側なので、ticket.sh は文字列を照合するだけで
  よく、段階の概念を持たない。照合は heading の文字列だけで行い、ファイル名は指定
  できない。**どちらのファイルにあっても**判定され、両方にあれば合わせて判定する。
  呼ぶ側が指すのは段階であって、作者がどちらのファイルに置いたかではない。

**終了ステータス:**
- 素の `check` は、チェックリストが埋まっていなくても失敗しない。作業の途中では
  後段のグループが空なのが正常であり、そこで落とすと初日から必ず止まって、結局
  切られる。
- `check --require` は、指定グループに未記入があれば exit 1。
- `check --require` は、**その名前のグループが存在しない場合も exit 1**。通して
  しまうと、タイポした `--require` が「常に成功する no-op」になり、呼ぶ側は守って
  いるつもりで何も検査していない状態になる。
- `check --require` は、アクティブなチケットが無ければ exit 1（判定する note が無い）。

存在しないファイルは何も寄与しない。両方のファイルにチェックボックスが1つも無ければ、
チェックリストの出力は出ず、失敗もしない。

**出力例**

```
Checklist: 6 / 16
  ticket.md
    Tasks                 2 / 9
        - Task 1
        - Run tests before closing
  note.md
    Implementation log    4 / 4  done (1 skipped)
    Review                0 / 1
        - findings resolved
```

config に `require_checklist_groups` を書くと、`check` はそのグループの現状も表示する
（exit code は 0 のまま）:

```
Required groups
    Required Probes    missing  (close will refuse)
    Review             1 / 1  done
```

config に `append_only_files` を書くと、そこに挙げたファイルが「かつて持っていて今は
持っていない行」も報告する（exit code は 0 のまま）:

```
✗ Append-only file is missing lines it used to have: tickets/<name>/progress.md
    a1b2c3d  1 line(s) gone  progress: tidy up the false start
        - tried the obvious thing, it did not work
```

ここで見えることが、branch がまだ自分のもので追記できるうちに行を戻せる理由。
拒否するのは `close`。宣言したファイルがすべて無傷なら 1 行だけそう表示する。

**`check` が意図的にやらないこと**

呼ぶ側に残してある:

- **どの段階でどのグループを要求するか** — `--require` に文字列で渡す
- **チェックが古くなったかの判定**（テストは通ったが、その後コードを直した、など）
  — 何を「関係する変更」と見なすかがプロジェクトごとに違う
- **チェック項目の意味**

### `close [--no-push] [--force|-f]`
チケット完了とマージ処理：

**オプション:**
- `--no-push`: 自動プッシュを無効化（`auto_push: true` の場合でも）
- `--force` / `-f`: コミットされていない変更を無視して強制的にクローズ

**チェックリストの preflight:**

config で `require_checklist: true` にすると、ticket か note に未記入が残っている間は
close を止め、ファイルとグループごとに未記入項目を並べ、何も変更しない。既定は無効。
チェックリストの読み方は上の `check` を参照。

**必須グループ**（`require_checklist_groups`）

`require_checklist` は**未記入のチェックボックスを数える**ので、節が丸ごとファイルに
無いと数える対象がゼロになり、「全部片付いた」と区別がつかない。close は通り、しかも
**何も検査していないことが出力に一切現れない**。テンプレートより前に作られた ticket、
手で書いた ticket、別テンプレートから移ってきた ticket は、まさにこの状態にある。

`require_checklist_groups` は「無ければならない見出し」を宣言する:

```yaml
require_checklist_groups:
  - "Required Probes"
```

宣言した名前がどちらのファイルのどのグループにも一致しなければ close を止める。
**見出しはあるが下にチェックボックスが1つも無い場合も同じ扱い**で、読む側から見れば
「判定される中身が無い」という点で変わらないため。宣言したグループに未記入が残って
いる場合も止める。照合の仕方は `check --require` と同じ（heading の文字列だけ、
どちらのファイルでも可、両方にあれば合わせて判定）。

既定は空で、何も宣言しなければ close の挙動は従来と完全に同一。`require_checklist`
とは独立で、この一覧自体が opt-in なので、ファイル全体の gate を入れていない
プロジェクトでも宣言したグループだけは守られる。**欠落は未記入より先に報告する。**
「節がそもそも無い」の方が基本的な答えであり、先に未記入の一覧を見せられた人は、
それを埋め終えてから「必要だった節は最初から無かった」と告げられることになるため。

`check` は宣言グループの現状を表示するが、そこで失敗はしない。止めるのは close。

このキーは、検査対象が note だけだった頃は `require_note_checklist` という名前だった。
旧名は削除済み。ただし**黙って無視はしない**。旧名に `true` が残っている config は
エラーで止める。有効にしていた gate を無言で外すのは、このチェックが潰そうとしている
失敗そのものだから。`false` の場合は警告のみ。

`--force` では**迂回できない**。`--force` は Git の状態（ticket file が base branch
側でも動いていた、など）の話であり、このチェックの迂回路は `- [-] ... - skip: <理由>`
の側にある。そちらは理由が note に残り、読む側が妥当性を判断できる。何も記録せずに
通す抜け道を付ければ、チェックリストは元の状態 — 置いてあるが誰も見ない — に戻る。
`--dry-run` でもこのチェックは走る。

**追記のみのファイル**（`append_only_files`）

ticket が持つファイルの中には、「現在どうなっているか」ではなく「どう進んだか」の
記録であるものがある。経緯ログが価値を持つのは、誰も後から回り道を消して整えなかった
からで、それを強制する仕組みは無かった。プロジェクト側のテストスイートで検査することは
できるが、いちばん必要なのは human gate で止まってテストまで辿り着かない run の方
——常に必ず走るのは `close` である。

```yaml
append_only_files:
  - progress.md
```

path は ticket dir 相対。判定するのは「**かつてそのファイルにあった行が、今そこに無いか**」
であって、「どれかの commit が行を消したか」ではない。この 2 つは、違反を直そうとした
瞬間に食い違う。履歴は書き換えない前提なので、取れる修復は「行を再度追記する」だけ
——commit だけを見る規則では修復後も落ち続け、amend と force push しか出口が無くなる。
そこで、行がファイルに戻れば削除は許される。

したがって**行の変更も削除に数える**。変更前の文字列は失われているからで、これは意図した
読み方である。append-only とは「一度書いた行に後から手を入れない」ことであり、昨日の
エントリの typo 修正はまさにこれが捕まえるべき小さな書き換えで、訂正の記録の仕方は
「訂正したと書く新しい行」の方。

拒否のメッセージは、ファイル名、該当 commit、その commit の行のうち今も戻っていない数、
そしてその 1 行目を出す:

```
✗ Append-only file is missing lines it used to have: tickets/<name>/progress.md
    a1b2c3d  1 line(s) gone  progress: tidy up the false start
        - tried the obvious thing, it did not work
```

commit は `<base>..HEAD` から読む。`<base>` は ticket の `base_branch`（無ければ
`default_branch`）で、`<repository>/<base>` があればそれ、無ければ local の branch を使う。
CI では base branch が remote-tracking ref としてしか存在しないことが多く、ref が無いときに
黙って何もしない gate は gate が無いより悪いので、どちらも無ければその旨を出して skip する。

読むのは commit 済みの履歴だけ。未 commit の編集は commit 前に直せる、作者の手の内にある。
ファイルを持たない ticket は対象外——ファイルの存在を強制するのは別の規則で、別のキーが
必要になる。

`close --no-merge` はゲートしない。これは feature branch が別の場所で merge された**後**に
base branch 上で走るので、`<base>..HEAD` が空になり、測る対象の履歴が残っていない。
捕まえるなら手前——作業がまだ載っている feature branch 上で `check` が報告する。既定は空。チェックリストと同じ理由で `--force` では迂回できず、`--dry-run`
でも見える。plain `check` は同じ内容を表示して exit 0 のままなので、branch がまだ自分の
もので追記できるうちに気づける。

**実行フロー:**
1. **作業ディレクトリチェック**: `--force` 未指定時のみ、コミットされていない変更がないか確認
2. **チケット更新**: current-ticket.md の参照先チケットの `closed_at` に現在時刻を設定
3. **コミット**: `"Close ticket"` メッセージでコミット
4. **Push (条件付き)**: `auto_push: true` かつ `--no-push` 未指定時のみ featureブランチをpush
5. **Squash Merge**: featureブランチをターゲットブランチにsquash merge（チケットの `base_branch` フィールドが設定されていればそちらを優先、なければ `{default_branch}`）
6. **Push (条件付き)**: `auto_push: true` かつ `--no-push` 未指定時のみ `{default_branch}` をpush
7. 実行したGitコマンドと出力を詳細表示

**Squash コミットメッセージ:**

squash コミットはチケットを埋め込む。`tickets/done/` を開かずに `git blame` から
変更の理由に辿り着けるようにするため。内訳は次のとおり。

- **subject** — `[<ticket-name>] <description>`。`description` が空または空白のみの
  場合は `[<ticket-name>] Ticket completed`。description は1行に畳まれる（改行は
  スペースになり、前後の空白は落ちる）ため、YAML の block scalar でも subject が
  複数行に割れることはない。長さには手を入れない。意味を保って短くできるのは
  チケットの書き手だけだから。
- **body** — チケットの Markdown 本文、つまり閉じ `---` より後ろ。**YAML frontmatter は
  含まれない。** frontmatter はチケットを**編集する人**に向けて本スクリプトが書く
  メタデータ（`# Do not modify manually`）であって履歴の読み手向けではなく、外しても
  情報は失われない。同じコミットが frontmatter 込みの
  `tickets/done/<TICKETNAME>/ticket.md` を含んでおり、`closed_at` はコミットの
  author date と、`description` は subject と重複しているため。frontmatter の無い
  チケットは全文が入り、本文の無いチケットは subject だけのメッセージになる。

これを変える設定キーは無い。常にこの挙動。

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
# subject: description を1行に畳んだもの
# body: ticket の Markdown 本文。YAML frontmatter は入らない
git commit -m "[ticket-name] description\n\n$(markdown body of ticket-file)"

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

### `cancel [--force|-f]`
マージせずにチケットをキャンセル：

**オプション:**
- `--force` / `-f`: コミットされていない変更を無視して強制的にキャンセル

**実行フロー:**
1. **作業ディレクトリチェック**: `--force` 未指定時のみ、コミットされていない変更がないか確認
2. **チケット更新**: アクティブチケット（`current-ticket.md` symlink の参照先）の `canceled_at` に現在時刻を設定
3. **description更新**: `description` フィールドに `[CANCELED]` プレフィックスを追加
4. **リネーム**: per-ticket ディレクトリ形式チケットは、`tickets/<TICKETNAME>/` ディレクトリを丸ごと `-CANCELED-` 挿入で rename（例: `tickets/<YYMMDD-hhmmss>-CANCELED-<slug>/`）。レガシーフラット形式は `.md` ファイル（および `-note.md` があればそれも）を同様に rename。
5. **doneフォルダに移動**: rename 後のディレクトリ／ファイルを `tickets/done/` に移動
6. **コミット**: 変更をコミット
7. **ブランチ切り替え**: マージせずにデフォルトブランチにチェックアウト
8. **クリーンアップ**: すべてのアクティブチケット symlink（`current-ticket/`、`current-ticket.md`、`current-note.md`）を削除
9. featureブランチは保持（削除しない）

**実行例出力:**
```bash
$ ./ticket.sh cancel

Ticket canceled: 240628-153245-implement-auth
Switched to branch 'develop'
```

**エラーケース:**
- `close` コマンドと同様: アクティブチケット symlink（`current-ticket.md`）が有効なチケットを指している必要あり、feature ブランチ上で実行、チケットが開始済みである必要あり、作業ディレクトリがクリーンである必要あり（`--force` 使用時を除く）

---

**マージコミットメッセージ形式:**
```
[240628-153245-create-post-handler] User authentication POST handler

---
priority: 2
base_branch: default
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
  ./ticket.sh start <ticket-name>      Start working on ticket (creates feature branch)
  ./ticket.sh restore                  Rebuild active-ticket symlinks (current-ticket/, current-ticket.md, current-note.md) from branch name
  ./ticket.sh close [--no-push] [--force|-f]  Complete current ticket (squash merge to default branch)
  ./ticket.sh cancel [--force|-f]            Cancel current ticket without merging

TICKET NAMING:
- Format: YYMMDD-hhmmss-<slug>
- Example: 241225-143502-implement-user-auth
- Generated automatically when creating tickets

TICKET STATUS:
- todo: not started (started_at: null)
- doing: in progress (started_at set, closed_at: null, canceled_at: null)
- done: completed (closed_at set)
- canceled: canceled (canceled_at set)

CONFIGURATION:
- Config file: .ticket-config.yaml または .ticket-config.yml (プロジェクトルート内)
- Initialize with: ./ticket.sh init
- Edit to customize directories, branches, and templates

PUSH CONTROL:
- Set auto_push: false in config to disable automatic pushing
- Use --no-push flag to override auto_push: true for single command
- Git commands and outputs are displayed for transparency

WORKFLOW:
1. Create ticket: ./ticket.sh new feature-name (creates tickets/<TICKETNAME>/{ticket.md,note.md})
2. Edit ticket content in tickets/<TICKETNAME>/ticket.md
3. Start work: ./ticket.sh start 241225-143502-feature-name
4. Develop on feature branch (reference active ticket via current-ticket/ticket.md or compat current-ticket.md)
5. Complete: ./ticket.sh close (moves tickets/<TICKETNAME>/ to tickets/done/<TICKETNAME>/)

TROUBLESHOOTING:
- プロジェクトルートから実行 (.git と設定ファイルが存在する場所)
- Use 'restore' if the active-ticket symlinks are missing after clone/pull
- Check 'list' to see available tickets and their status
- Ensure Git working directory is clean before start/close

Note: current-ticket/, current-ticket.md, and current-note.md are git-ignored
and need 'restore' after clone/pull.
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