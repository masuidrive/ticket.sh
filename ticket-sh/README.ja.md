# ticket.sh - Gitベースチケット管理システム

シェルスクリプト、ファイル、Gitを使用した自己完結型のチケット管理システムです。コーディングタスクの管理に最適で、特にAIコーディングアシスタントとの作業に適しています。

**重要**: このファイルを更新した場合、他言語のREADME.mdファイルも変更すること

- [English ver.](README.md)
- [Japanese ver.](README.ja.md)

## 概要

ticket.shは以下の特徴を持つ軽量なチケット管理システムです：
- YAMLフロントマター付きのMarkdownファイルでチケットを管理
- Git Flow（develop/featureブランチ）と統合
- 外部サービスやデータベース不要
- 単一のポータブルなシェルスクリプトにコンパイル
- macOSとLinuxでBash 3.2以上で動作

## クイックスタート

```bash
# 単一ファイルの実行ファイルをビルド（プロジェクトルートから）
./build.sh

# プロジェクトで初期化
./ticket.sh init

# 新しいチケットを作成
./ticket.sh new implement-auth

# チケットの作業を開始
./ticket.sh start 241229-123456-implement-auth

# チケットを完了してマージ
./ticket.sh close
```

## インストール

### オプション1: ソースからビルド
```bash
git clone https://github.com/yourusername/yaml-sh.git
cd yaml-sh
./build.sh
cp ticket.sh /usr/local/bin/  # またはPATHの通った場所へ
```

### オプション2: ビルド済みスクリプトをダウンロード
```bash
curl -O https://raw.githubusercontent.com/yourusername/yaml-sh/main/ticket.sh
chmod +x ticket.sh
```

## ワークフロー

1. **初期化** - Gitリポジトリでチケットシステムを初期化：
   ```bash
   ticket.sh init
   ```

2. **作成** - 新しいチケットを作成：
   ```bash
   ticket.sh new implement-user-auth
   # 作成されるファイル: tickets/241229-123456-implement-user-auth.md
   ```

3. **編集** - チケットファイルを編集して説明とタスクを追加：
   ```bash
   vim tickets/241229-123456-implement-user-auth.md
   ```

4. **開始** - チケットの作業を開始：
   ```bash
   ticket.sh start 241229-123456-implement-user-auth
   # ブランチ作成: feature/241229-123456-implement-user-auth
   # シンボリックリンク作成: current-ticket.md -> tickets/241229-123456-implement-user-auth.md
   ```

5. **開発** - 通常通りコミットしながら機能を開発

6. **完了** - 作業が終わったらチケットをクローズ：
   ```bash
   ticket.sh close
   # developブランチへスカッシュマージ
   # チケットステータスを完了に更新
   ```

## コマンド

### `ticket.sh init`
リポジトリでチケットシステムを初期化
- `.ticket-config.yml` 設定ファイルを作成
- `tickets/` ディレクトリを作成
- `.gitignore` を更新

### `ticket.sh new <slug>`
新しいチケットファイルを作成
- `slug`: 小文字、数字、ハイフンのみ使用可能
- ファイル名生成: `YYMMDD-hhmmss-<slug>.md`

### `ticket.sh list [options]`
フィルタオプション付きでチケットを一覧表示
- `--status todo|doing|done`: ステータスでフィルタ
- `--count N`: 結果数を制限（デフォルト: 20）
- デフォルトでは `todo` と `doing` のチケットのみ表示

### `ticket.sh start <ticket-name> [--no-push]`
チケットの作業を開始
- フィーチャーブランチを作成
- チケットの `started_at` タイムスタンプを更新
- `current-ticket.md` シンボリックリンクを作成
- `--no-push` で自動プッシュをスキップ

### `ticket.sh restore`
`current-ticket.md` シンボリックリンクを復元
- clone/pull操作後に便利
- 現在のブランチから自動的にチケットを検出

### `ticket.sh close [--no-push]`
現在のチケットを完了
- チケットの `closed_at` タイムスタンプを更新
- developブランチへスカッシュマージ
- `current-ticket.md` シンボリックリンクを削除
- `--no-push` で自動プッシュをスキップ

## 設定

`.ticket-config.yml` を編集してカスタマイズ：

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

## チケット構造

各チケットはYAMLフロントマター付きのMarkdownファイル：

```markdown
---
priority: 2
tags: []
description: "簡潔な説明"
created_at: "2024-12-29T12:34:56Z"
started_at: null  # 手動で変更しないこと
closed_at: null   # 手動で変更しないこと
---

# チケットタイトル

詳細な説明と要件...

## タスク
- [ ] 実装タスク1
- [ ] 実装タスク2
- [ ] テスト作成
- [ ] ドキュメント更新
```

## ステータス管理

チケットステータスは自動的に決定：
- **todo**: `started_at` がnull
- **doing**: `started_at` が設定済み、`closed_at` がnull
- **done**: `closed_at` が設定済み

## Git統合

- Git Flow（develop → feature/* → develop）で動作
- すべてのGitコマンドは透明性のため表示
- 自動プッシュはグローバルまたはコマンドごとに無効化可能
- スカッシュマージでコミット履歴をクリーンに保持

## ソースからビルド

プロジェクト構造：
```
ticket-sh/
├── src/
│   └── ticket.sh      # メインスクリプト
├── lib/
│   ├── yaml-sh.sh     # YAMLパーサー
│   ├── yaml-frontmatter.sh
│   └── utils.sh
├── test/              # テストスイート
├── spec.md            # 英語仕様書
├── spec.ja.md         # 日本語仕様書
└── README.md          # このファイル
```

ビルド方法（プロジェクトルートから）：
```bash
./build.sh
# 作成されるファイル: ticket.sh（単一実行ファイル）
```

## テスト

テストスイートを実行：
```bash
cd ticket-sh/test
./test-final.sh      # コア機能テスト
./test-additional.sh # エッジケースとエラー条件
```

## ユースケース

- **個人開発**: 個人のタスクとTODOを追跡
- **AIペアプログラミング**: AIアシスタントにコンテキストを提供
- **小規模チーム**: イシュートラッカーの軽量な代替
- **フィーチャーブランチワークフロー**: 一貫したGitプラクティスを実施

## 動作要件

- Bash 3.2以上
- Git
- 基本的なUnixツール（awk、sed、grep）

## ライセンス

MITライセンス - 詳細はLICENSEファイルを参照