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

**言語版**: [English](README.md) | [日本語](README.ja.md)

## クイックスタート

```bash
# ビルド済みスクリプトをダウンロード
curl -O https://raw.githubusercontent.com/masuidrive/ticket.sh/main/ticket.sh
chmod +x ticket.sh

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

`.ticket-config.yaml`を編集：

```yaml
tickets_dir: "tickets"
default_branch: "develop"
branch_prefix: "feature/"
auto_push: true

# リモートブランチ自動削除設定
# 有効にすると、チケットクローズ時に自動的にリモートのfeatureブランチを削除します。
# これによりGitHubの「Compare & pull request」バナーが表示されなくなります。
# 履歴として残したい場合はfalseに設定してください。
delete_remote_on_close: true  # デフォルト: true

# 成功メッセージ
start_success_message: |
  Please review the ticket content in `current-ticket.md` and make any
  necessary adjustments before beginning work.

close_success_message: |
  # デフォルトは空
```

## 高度な機能

### スマートなブランチ処理
- **既存ブランチ**: 失敗する代わりに自動的にチェックアウトして復元
- **クリーンブランチ**: 変更がない場合はデフォルトブランチから新ブランチを作成
- **競合検出**: クローズ時のマージ競合処理のガイダンス提供

### 自動整理
- **doneフォルダ**: 完了チケットを自動的に `tickets/done/` に移動
- **リモートクリーンアップ**: リモートfeatureブランチの自動削除オプション
- **Git履歴**: `current-ticket.md` の誤コミット防止

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