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

#### ブランチ連携
- 作業は `feature/<チケット名>` ブランチで実施
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
./ticket.sh start [--worktree] [--copy-file <path>]... <ticket-name>  # チケット開始・ブランチ作成（--worktreeで別ディレクトリ、--copy-fileでworktree_copy_filesエントリ追加）
./ticket.sh restore                       # current-ticketリンク復元
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
description: ""
created_at: "2025-06-28 15:32:45 UTC"
started_at: null
closed_at: null
canceled_at: null
---

# チケットタイトル

チケットの詳細内容...
```

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
2. Gitブランチを `{branch_prefix}<basename>` として作成
3. その記録を feature branch に `[start] {branch}` としてコミットし、base branch をそのコミットへ fast-forward（後述の **開始時刻の記録** を参照）
4. アクティブチケット symlink 群を作成: `current-ticket/`（dir symlink、新形式のみ）、`current-ticket.md`、`current-note.md`。加えて `Active ticket paths:` ブロックを emit（下流エージェントが解決済みパスを消費できる）
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
- fast-forward は best-effort。base branch が先に進んでいたり、その作業ツリーに競合する変更があれば、その旨を報告して処理を続行する。`started_at` はいずれにせよ feature branch にコミットされている。
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
5. **Squash Merge**: featureブランチをターゲットブランチにsquash merge（チケットの `base_branch` フィールドが設定されていればそちらを優先、なければ `{default_branch}`）
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