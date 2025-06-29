# ticket.sh - Gitベースチケット管理システム

Gitとマークダウンファイルを使った軽量なチケット管理システム。個人開発やAIペアプログラミングに最適。

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
./build.sh
cp ticket.sh /usr/local/bin/
```

## 基本的な使い方

1. **初期化**: `./ticket.sh init`
2. **チケット作成**: `./ticket.sh new feature-name`
3. **作業開始**: `./ticket.sh start <ticket-name>`
4. **チケット完了**: `./ticket.sh close`

## コマンド

- `init` - チケットシステムを初期化
- `new <slug>` - 新しいチケットを作成
- `list [--status todo|doing|done]` - チケット一覧
- `start <ticket> [--no-push]` - チケットの作業を開始
- `close [--no-push] [--force]` - チケットを完了
- `restore` - current-ticket.mdシンボリックリンクを復元

## 設定

`.ticket-config.yml`を編集：

```yaml
tickets_dir: "tickets"
default_branch: "develop"
branch_prefix: "feature/"
auto_push: true
```

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