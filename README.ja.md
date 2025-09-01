# ticket.sh - Gitベースチケット管理システム

Gitブランチとマークダウンファイルを使った軽量で堅牢なチケット管理システム。個人開発、小規模チーム、AIペアプログラミングに最適。

## 主な機能
- 🎯 **シンプルなワークフロー**: 作成、開始、作業、完了
- 📝 **マークダウンチケット**: YAMLフロントマッター付きリッチフォーマット
- 🌿 **Git統合**: チケット毎の自動ブランチ管理
- 📁 **スマートな整理**: 自動doneフォルダ整理、タイムゾーン対応タイムスタンプ
- 🔧 **依存関係なし**: 純粋なBash + Git、どこでも動作
- 🚀 **AI対応**: シームレスなAIアシスタント連携を想定した設計
- 🛡️ **堅牢性**: UTF-8対応、エラー回復、競合解決
- 📓 **作業ノート分離**: デバッグ・調査ログ用の別ファイル（オプション）

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
4. **チケット完了**: `./ticket.sh close`

## 使用例

### 基本ワークフロー
```bash
# 現在の状態を確認
./ticket.sh check

# ステータス別チケット一覧
./ticket.sh list --status todo
./ticket.sh list --status done --count 5

# プロンプトなしで強制完了
./ticket.sh close --force

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
- `new <slug>` - 新しいチケットを作成
- `list [--status todo|doing|done] [--count N]` - チケット一覧
- `start <ticket> [--no-push]` - チケットの作業を開始
- `close [--no-push] [--force] [--no-delete-remote]` - チケットを完了
- `restore` - current-ticket.mdシンボリックリンクを復元

### ユーティリティコマンド
- `check` - 現在の状態を診断してガイダンスを提供
- `version` / `--version` - バージョン情報を表示
- `selfupdate` - GitHubから最新リリースにアップデート

### listコマンドの機能
- **ステータス絞り込み**: `--status todo|doing|done` でチケットステータス別表示
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

# Automatically push changes to remote repository during close command
# Set to false if you want to manually control when to push
auto_push: true

# Automatically delete remote feature branch after closing ticket
# Set to false if you want to keep remote branches for history
delete_remote_on_close: true

# Success messages (leave empty to disable)
# Message displayed after starting work on a ticket
start_success_message: |
  Please review the ticket content in `current-ticket.md` and make any necessary adjustments before you begin work.
  Run ticket.sh list to view all todo tickets. For any related tasks that have already been prioritized, list them under the `## Notes` section.

# Message displayed after closing a ticket
close_success_message: |
  I've closed the ticket—please perform a backlog refinement.
  Run ticket.sh list to view all todo tickets; if you find any with overlapping content, review the corresponding `tickets/*.md` files.
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

### 設定オーバーライド

メイン設定ファイルを変更せずにローカル設定をカスタマイズするには、`.ticket-config.override.yaml` を作成します：

```yaml
# メイン設定から特定の値をオーバーライド
tickets_dir: "my-custom-tickets"
auto_push: false
start_success_message: |
  この環境用のカスタムメッセージ
```

**仕組み:**
- オーバーライドファイルはオプション - なくても正常に動作
- `.ticket-config.override.yaml` の値がメイン設定より優先される
- 既存の値をオーバーライドしたり、新しい設定フィールドを追加可能
- 自動的に `.gitignore` に追加される（リポジトリにコミットされない）
- ローカル開発、異なるチームメンバー、環境固有の設定に便利

**一般的な使用例:**
- **開発者固有の設定**: 異なるブランチプレフィックス、ディレクトリ、メッセージ
- **環境固有の設定**: テスト環境での自動プッシュを無効化
- **チームのカスタマイズ**: 異なるチームメンバーがパーソナライズされたワークフローを持てる

## 高度な機能

### スマートなブランチ処理
- **既存ブランチ**: 失敗する代わりに自動的にチェックアウトして復元
- **クリーンブランチ**: 変更がない場合はデフォルトブランチから新ブランチを作成
- **競合検出**: クローズ時のマージ競合処理のガイダンス提供

### 自動整理
- **doneフォルダ**: 完了チケットを自動的に `tickets/done/` に移動
- **リモートクリーンアップ**: リモートfeatureブランチの自動削除オプション
- **Git履歴**: `current-ticket.md` の誤コミット防止

### 作業ノート分離（オプション）
- **別ノートファイル**: デバッグログや調査詳細を `*-note.md` ファイルに分離
- **クリーンなチケット**: メインのチケットファイルは要件に集中し簡潔に
- **自動管理**: ノートファイルの作成、移動、リンクを自動化
- **後方互換性**: configで `note_content` が定義された場合のみ有効

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