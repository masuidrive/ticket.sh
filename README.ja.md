# ticket.sh - Gitベースチケット管理システム

Gitブランチとマークダウンファイルを使った軽量で堅牢なチケット管理システム。個人開発、小規模チーム、AIペアプログラミングに最適。

## 主な機能
- 🎯 **シンプルなワークフロー**: 作成、開始、作業、完了（またはキャンセル）
- 📝 **マークダウンチケット**: YAMLフロントマッター付きリッチフォーマット
- 🌿 **Git統合**: チケット毎の自動ブランチ管理
- 📁 **per-ticket ディレクトリ**: 各チケットが `tickets/<TICKETNAME>/` に本文・note・tests・tmp をまとめて置く
- 📁 **スマートな整理**: 自動 done フォルダ整理、タイムゾーン対応タイムスタンプ
- 🔧 **依存関係なし**: 純粋なBash + Git、どこでも動作
- 🚀 **AI対応**: 下流エージェントが解決済みパスをそのまま消費できる出力を start/restore が emit
- 🛡️ **堅牢性**: UTF-8対応、エラー回復、競合解決
- ♻️ **レガシー互換**: 旧版で作られたフラット形式チケットもすべてのコマンドで動く（自動移行はしない）

**言語版**: [English](README.md) | [日本語](README.ja.md)

## クイックスタート

### ダウンロード
```bash
curl -O https://raw.githubusercontent.com/masuidrive/ticket.sh/main/ticket.sh
chmod +x ticket.sh
```

**⚠️ Windows/VSCodeユーザー**: `/usr/bin/env: 'bash\r': No such file or directory` エラーが発生した場合:
```bash
# CRLF改行コードを修正（どちらか選択）:
dos2unix ticket.sh              # dos2unixがインストール済みの場合
sed -i 's/\r$//' ticket.sh      # sedを使用
```
この問題は`selfupdate`コマンドによる新しいダウンロードでは自動的に防止されます。

### コーディングエージェント向け

Claude CodeやGemini CLIのようなコーディングエージェントでは、下記のような会話で操作。

```
`./ticket.sh init`を実行してチケット管理をインストール
CLAUDE.mdにカスタムプロンプトを追記
```

```
認証システムの実装チケットを切って
```

```
そのチケットを開始して
```

```
チケット閉じて
```

```
そのチケットはもう不要なのでキャンセルして
```

```
残ってるチケットは何？
```

### CLI使用法
```bash
# プロジェクトで初期化
./ticket.sh init

# チケット作成
./ticket.sh new implement-auth

# 作業開始
./ticket.sh start 241229-123456-implement-auth

# 作業完了
./ticket.sh close

# 不要になった場合はキャンセル
./ticket.sh cancel
```

## インストール

### オプション1: ダウンロード
```bash
curl -O https://raw.githubusercontent.com/masuidrive/ticket.sh/main/ticket.sh
chmod +x ticket.sh
```

### オプション2: ソースからビルド
```bash
git clone https://github.com/masuidrive/ticket.sh.git
cd ticket.sh
bash ./build.sh
cp ticket.sh /usr/local/bin/
```

## 基本的な使い方

1. **初期化**: `./ticket.sh init`
2. **チケット作成**: `./ticket.sh new feature-name`
3. **作業開始**: `./ticket.sh start <ticket-name>`
4. **チケット完了**: `./ticket.sh close`（または `./ticket.sh cancel` でキャンセル）

`start` は開始時刻を feature branch にコミットし、base branch をそのコミットへ
fast-forward します。そのため `list` はどちらのブランチから実行しても `doing` と表示します。
base branch が先に進んでいる場合は fast-forward を行わず、その旨を表示して開始時刻は
feature branch 側に残ります。

## チケットのレイアウト

各チケットは **per-ticket ディレクトリ** に置かれます：

```
tickets/
  <TICKETNAME>/
    ticket.md   # チケット本体（YAML frontmatter + Markdown）
    note.md     # 作業ノート／ログ
    ...         # config の ticket_files に挙げた追加ファイル（progress.md など）
    tmp/        # ticket-local 一時 helper（start/restore で自動作成、tickets/.gitignore で git 除外）
  done/
    <TICKETNAME>/   # close/cancel されたチケット — ディレクトリごと移動
```

チケット作業中は `start` がリポジトリ直下に固定パスの symlink を 3 本張り、
下流エージェントも含めて常に同じ場所からアクティブチケットに到達できます：

| symlink                | 指し先                                  | 役割                                             |
|------------------------|----------------------------------------|--------------------------------------------------|
| `current-ticket/`      | `tickets/<TICKETNAME>/`                | dir symlink — per-ticket ディレクトリの root     |
| `current-ticket.md`    | `tickets/<TICKETNAME>/ticket.md`       | 互換 file symlink（旧ツール想定）                |
| `current-note.md`      | `tickets/<TICKETNAME>/note.md`         | 互換 file symlink                                |

`close` と `cancel` は `tickets/<TICKETNAME>/` を丸ごと
`tickets/done/<TICKETNAME>/` へ git-mv します（`cancel` はディレクトリ名に
`-CANCELED-` を挿入）。単一 commit で rename と `closed_at`／`cancelled_at`
追記が入ります。

**レガシー互換**: 旧版で作られたフラット形式チケット
(`tickets/<TICKETNAME>.md` + `tickets/<TICKETNAME>-note.md`) は
`list`／`start`／`close`／`cancel`／`restore`／`check` すべてで従来どおり
動作します。自動移行は行いません（好きなタイミングで手動変換してください）。

## 使用例

### 基本ワークフロー
```bash
# 現在の状態と ticket / note のチェックリストを確認
./ticket.sh check

# 見出し名で特定グループだけ判定する（どちらのファイルでも可、未記入があれば exit 1）
./ticket.sh check --require "Implementation log"

# ステータス別チケット一覧
./ticket.sh list --status todo
./ticket.sh list --status done --count 5

# プロンプトなしで強制完了
./ticket.sh close --force

# マージせずにチケットをキャンセル
./ticket.sh cancel

# 最新版にアップデート
./ticket.sh selfupdate
```

### 完了済みチケットの操作
```bash
# 最近の完了チケットを表示（新しい順）
./ticket.sh list --status done

# 完了済みチケットを参照用に復元
./ticket.sh restore 241229-123456-old-feature
```

## コマンド

### コアコマンド
- `init` - チケットシステムを初期化（冪等性、再実行安全）
- `new <slug> [--branch <name>]` - 新しいチケットを作成（`--branch` はこの ticket の feature branch 名を `{branch_prefix}<ticket-name>` の代わりに指定する）
- `list [--status todo|doing|done|canceled] [--count N]` - チケット一覧
- `start [--worktree] [--copy-file <path>]... <ticket>` - チケットの作業を開始（--worktree で別ディレクトリに worktree を作成、--copy-file で `worktree_copy_files` にワンショットで path 追加）
- `close [--no-push] [--force] [--no-delete-remote]` - チケットを完了
- `cancel [--force|-f]` - マージせずにチケットをキャンセル
- `restore` - アクティブチケット symlink 群 (`current-ticket/`, `current-ticket.md`, `current-note.md`) を現在ブランチ名から再構築

### ユーティリティコマンド
- `check` - 現在の状態を診断してガイダンスを提供（git repo・config・tickets/・アクティブチケット symlink・worktree 状態）
- `version` / `--version` - バージョン情報を表示
- `selfupdate` - GitHubから最新リリースにアップデート

### listコマンドの機能
- **ステータス絞り込み**: `--status todo|doing|done|canceled` でチケットステータス別表示
- **件数制限**: `--count N` で表示結果数を制限
- **完了チケット**: 完了日時順でソート（新しい順）
- **タイムゾーン表示**: 完了時刻をローカルタイムゾーンで表示
- **doneフォルダ**: 完了チケットを `tickets/done/` に自動整理

## 設定

`.ticket-config.yaml`を編集（これは作者が実際に使っている設定です）：

```yaml
# Ticket system configuration

# Directory settings
tickets_dir: "tickets"

# Git settings
default_branch: "main"
branch_prefix: "feature/"
repository: "origin"

# close で remote に push する
# 手動で push を制御したい場合は false にする
auto_push: true

# ticket.sh 自身が作るコミット（start の開始時刻記録など）で Git hook を
# スキップする（--no-verify）。既定では hook を実行する。
no_verify: false

# Automatically delete remote feature branch after closing ticket
# Set to false if you want to keep remote branches for history
delete_remote_on_close: true

# ticket の Tasks か note のチェックリストに未記入が残っている間は close を止める。
# 2つのファイルを両方読み、分けて報告する。チェックボックスは直近の heading ごとに
# グループ化される。'- [x]' は済み、'- [ ]' は未記入、
# '- [-] ... - skip: <理由>' はこの ticket には該当しない項目。
# 既定は false（既存の ticket / note には未記入が大量に残っているため）。
require_checklist: false

# 「無ければならない見出し」の一覧。require_checklist は未記入のチェックボックスを
# 数えるので、節が丸ごとファイルに無いと数える対象がゼロになり、「全部片付いた」と
# 区別がつかない。ここに見出し名を挙げると、ticket 本文にも note にもその見出しが
# 無い場合（見出しはあるが下にチェックボックスが1つも無い場合も同じ）に close を
# 止める。テンプレートより前に作られた ticket、手で書いた ticket、別テンプレートから
# 移ってきた ticket を捕まえるのがこれ。挙げたグループに未記入が残っている場合も
# 止める。既定は空で、require_checklist とは独立（この一覧自体が opt-in）。
# require_checklist_groups:
#   - "Required Probes"

# new が ticket dir に作る、note.md 以外の追加ファイル。各要素は ticket dir 相対の
# path（サブディレクトリ可）と、その初期内容 content。content では note_content と
# 同じく $$TICKET_NAME$$ / $$NOTE_PATH$$ が置換される。既存ファイルは上書きしない。
# note.md の要素は note_content より優先される。flat（旧形式）の ticket には作らない。
# 実在するものは start / restore の "Active ticket paths:" に 1 行ずつ出る。
# ticket_files:
#   - path: progress.md
#     content: |
#       # Progress: $$TICKET_NAME$$
#
#       経緯は追記のみ。現在値は $$NOTE_PATH$$ に置く。

# ticket dir の中で「追記しかしてはいけない」ファイル（ticket dir 相対の path）。
# かつてそのファイルにあった行が今そこに無ければ close が止まり、消した commit を
# 名指しする。直し方はその行を新しい commit で追記し直すこと（履歴は書き換えない）。
# plain check は同じ内容を表示するだけで落ちない。--force では迂回できない。既定は空。
# append_only_files:
#   - progress.md

# Worktree mode: create a separate git worktree for each ticket
# When true, 'start' always creates a worktree (same as --worktree flag)
# worktree_mode: false
# worktree_dir: ""  # Custom worktree base directory (default: ../<project>.worktrees/)

# 新しく作成された worktree に main repo からコピーするファイル群。
# 'start' が実際に worktree を作った場合にのみ参照される。target 側に
# 同名ファイルが既にあれば skip(絶対に上書きしない)、source 側になければ
# warn のみで続行。gitignore されたファイル前提(各人の秘密は各人の
# worktree にコピーされるだけで拡散しない)。CLI からは
# --copy-file <path>(反復可)で追加できる。
# worktree_copy_files:
#   - .env
worktree_copy_files: []

# Success messages (leave empty to disable)
# Message displayed after starting work on a ticket
start_success_message: |
  Please review the ticket content in `current-ticket/ticket.md` and make any necessary adjustments before you begin work.
  Run ticket.sh list to view all todo tickets. For any related tasks that have already been prioritized, list them under the `## Notes` section.

# Message displayed after closing a ticket
close_success_message: |
  I've closed the ticket—please perform a backlog refinement.
  Run ticket.sh list to view all todo tickets; if you find any with overlapping content, review the corresponding ticket files.
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

## 高度な機能

### スマートなブランチ処理
- **既存ブランチ**: 失敗する代わりに自動的にチェックアウトして復元
- **クリーンブランチ**: 変更がない場合はデフォルトブランチから新ブランチを作成
- **競合検出**: クローズ時のマージ競合処理のガイダンス提供
- **チケットごとの branch 名**: frontmatter の `branch:`（`new --branch <name>` で設定）があれば、`{branch_prefix}<ticket-name>` ではなくその branch を使う。`start` は既にあれば checkout、無ければ作成し、`check` / `restore` / `list` / `close` / `cancel` もすべてその branch と ticket を対応付ける。branch 名の由来が外にあるケース — issue 番号から `agent/issue-12` を組み立て、ticket ができる前に checkout してしまう CI bot など — を、コマンドを迂回せずに通常どおり扱うためのもの。
- **ticket がその branch 上にしか無い場合**: 現在の branch が ticket の名指す branch で、ticket がそこにあり、base branch にはその copy が無いとき、`start` はその場に留まる — base に切り替えて ticket を見失う代わりに、`started_at` を入れてその branch に commit する。base への fast-forward は理由（進める先の ticket がそこに無い）を 1 行出して skip し、`list` は branch から開始時刻を読むので ticket は `doing` のまま表示される。

### 自動整理
- **doneフォルダ**: 完了チケットを自動的に `tickets/done/<TICKETNAME>/` にディレクトリごと移動
- **リモートクリーンアップ**: リモートfeatureブランチの自動削除オプション

### 作業ノート（同一ディレクトリに配置）
- **per-ticket ディレクトリの `note.md`**: デバッグログ・調査詳細・進捗ノートをチケット本文と同じディレクトリに置く — 1 ディレクトリ = 1 作業単位
- **テンプレート指定可**: config の `note_content` で新チケット作成時の `note.md` 初期内容を設定
- **自動管理**: close/cancel でチケットディレクトリと一緒に `note.md` も移動、互換 `current-note.md` symlink も自動で作成／削除
- **git-ignore 対象**: `init` が `current-ticket`, `current-ticket.md`, `current-note.md` を `.gitignore` に追加し、誤コミットを防ぐ

### 追加ファイル（`ticket_files`）
- **付属ファイルを 2 つ以上**: `note_content` が作れるのは `note.md` ただ 1 つ。`ticket_files` に `(path, content)` の組を列挙すると、`new` がそのすべてを ticket dir に作る。置換は `note_content` と同じ（`$$TICKET_NAME$$` / `$$NOTE_PATH$$`）。サブディレクトリは必要に応じて作成し、ticket dir の外に出る path は警告して skip。
- **上書きしない**: 既存ファイルはそのまま。`note.md` の要素は `note_content` より優先される。
- **在処が分かる**: 実在するファイルは `start` / `restore` の `Active ticket paths:` に出るので、そのブロックだけ読んだ agent もファイルの場所が分かる — 覚えるべき規則も、自分で作るべきファイルも無い。
- **新レイアウトのみ**: flat（旧形式）の ticket には置く先のディレクトリが無い。

### 追記のみのファイル（`append_only_files`）
- **記録として残すファイル向け**: 経緯ログが価値を持つのは、誰も後から回り道を消して整えなかったから。その path を `append_only_files` に挙げると、かつてそのファイルにあった行が今そこに無い間 `close` が止まり、ファイル名・消した commit・その行を名指しする。
- **履歴を書き換えずに直せる**: 判定するのは「行が**今**ファイルにあるか」であって「どれかの commit が消したか」ではないので、新しい commit で追記し直せば解消する。行の**変更**も削除に数える（変更前の文字列は失われているため）。
- **表示だけでなく拒否する**: `--force` では迂回できず（修復の方が記録を読める形で残るため）、`--dry-run` でも見える。plain `check` は同じ内容を表示して exit 0 のままなので、branch がまだ自分のもので追記できるうちに気づける。
- **opt-in で範囲は狭い**: 既定は空。ファイルを持たない ticket は対象外。

### Worktreeサポート（オプション）
- **並行作業**: `start`に`--worktree`フラグを付けてチケット毎に別のgit worktreeを作成
- **独立ディレクトリ**: 各チケットが独自の作業ディレクトリを持ち、切り替え時のstash/commit不要
- **自動クリーンアップ**: `close`と`cancel`コマンドがworktreeを自動削除
- **設定モード**: configで`worktree_mode: true`を設定すると常にworktreeを使用
- **カスタムディレクトリ**: configで`worktree_dir`を設定してworktreeの場所をカスタマイズ（デフォルト: `../<プロジェクト名>.worktrees/`）
- **worktree 用ファイルコピー**: config の `worktree_copy_files: [".env"]` (任意の repo 相対 path のリスト)を指定すると、start が worktree を作った直後に main repo からその path 群を worktree へコピー。target 側に既にあれば上書きせず skip、source に無ければ warn のみで続行。ワンショットは `start --worktree --copy-file <path>` (反復可)。gitignore された `.env` 等を新 worktree でも即座に使うことを想定 — gitignore 前提なので、共有 config に入っていても各人自身の `.env` が各人の worktree にコピーされるだけで secret は拡散しない。

### エラー回復
- **checkコマンド**: 問題を診断して次のステップのガイダンス提供
- **restoreコマンド**: シンボリックリンクの再構築と中断操作からの回復
- **競合解決**: マージ競合解決後の操作再開

### 堅牢性機能
- **UTF-8対応**: すべてのコンテンツとファイル名でUnicode完全対応
- **権限耐性**: ファイルシステム権限問題の優雅な処理
- **ネットワーク耐性**: リモートプッシュが失敗してもローカル操作は継続
- **クロスプラットフォーム**: macOS、Linux、その他Unix系システムで動作

## 動作要件

- Bash 3.2+
- Git
- 基本的なUnixツール

## 開発者向け

詳細は[DEV.md](DEV.md)を参照：
- アーキテクチャの詳細
- ソースからのビルド
- テスト手順
- コントリビューションガイドライン

## ライセンス

MITライセンス - LICENSEファイルを参照