# AI Coding Helper Scripts

AIアシスタントを使用したコーディングワークフローを強化するシェルスクリプトツール集です。

## プロジェクト

### 🎫 ticket-sh
Gitベースのチケット管理システムで、コーディングタスクを整理し、AIコーディングアシスタントのためのコンテキストを維持します。自動的にフィーチャーブランチを作成し、YAMLフロントマター付きのMarkdownファイルで作業進捗を追跡します。

詳細は [ticket-sh/README.md](ticket-sh/README.md) を参照してください。

### 📄 yaml-sh
Bash 3.2+用の軽量YAMLパーサーで、外部依存関係なしにシェルスクリプトからYAML設定ファイルを読み込み、解析できます。複数行文字列、リスト、コメントを含む基本的なYAML構文をサポートしています。

詳細は [yaml-sh/README.md](yaml-sh/README.md) を参照してください。

## 動作要件

- Bash 3.2以上
- Git（ticket-sh用）
- 基本的なUnixツール（awk、sed、grep）

## ライセンス

MITライセンス