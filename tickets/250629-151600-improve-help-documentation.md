---
priority: 2
tags: ["documentation", "help", "workflow"]
description: "ヘルプメッセージの改善とワークフロー説明の更新"
created_at: "2025-06-29T15:16:00Z"
started_at: 2025-06-29T16:07:17Z # Do not modify manually
closed_at: 2025-06-29T16:24:52Z # Do not modify manually
---

# ヘルプメッセージの改善

ticket.shのヘルプメッセージを改善し、実際の使用方法をより明確にする。

## 背景

現在のヘルプメッセージは基本的な情報は提供しているが、以下の点で改善が必要：
- Markdown形式になっていない部分がある
- closeコマンドの重要な注意事項が記載されていない
- チケット内容の確認やチェックリストの処理について言及がない

## Tasks

- [x] ヘルプメッセージ全体をMarkdown形式に統一
- [x] WORKFLOWセクションにcloseコマンドの注意事項を追加
  - [x] closeはユーザーの確認を取ってから実行すること
  - [x] close前にチケット内容を確認すること
  - [x] チェックリストがある場合は完了状態を確認してチェックすること
- [x] 他の場所で指示されたワークフローがある場合はそちらを優先する旨を追記
- [x] 実装後、`./ticket.sh help`で表示確認
- [x] テストが壊れていないことを確認

## 詳細仕様

### WORKFLOWセクションの更新内容

```markdown
## WORKFLOW

1. Create ticket: `./ticket.sh new feature-name`
2. Edit ticket content and description
3. Start work: `./ticket.sh start 241225-143502-feature-name`
   - Check available tickets: `./ticket.sh list`
   - Or browse tickets directory directly
4. Develop on feature branch (current-ticket.md shows active ticket)
5. Before closing:
   - Review ticket content and description
   - Check all tasks in checklist are completed (mark with [x])
   - Get user confirmation before proceeding
6. Complete: `./ticket.sh close`

**Note**: If specific workflow instructions are provided elsewhere (e.g., in project documentation or CLAUDE.md), those take precedence over this general workflow.
```

### 注意事項

- 既存の動的な設定値読み込み機能は維持する
- Markdown形式にする際、CLIでの表示が崩れないよう注意
- バックティックは適切にエスケープする

## Notes

この変更により、AIアシスタントや開発者がより適切にticket.shを使用できるようになる。特にcloseコマンドの実行前の確認プロセスが明確になることで、不完全な状態でのチケットクローズを防げる。

---

## 追加実装：ビルドファイルへの編集禁止警告

### 概要
`./ticket.sh`はソースファイルからビルドされたファイルであり、直接編集してはいけないことを明示的に警告するヘッダーを追加した。

### 実装内容
build.shを修正して、生成されるticket.shの先頭に以下の警告コメントを追加：

```bash
#!/usr/bin/env bash

# IMPORTANT NOTE: This file is generated from source files. DO NOT EDIT DIRECTLY!
# To make changes, edit the source files in src/ directory and run ./build.sh
# Source file: src/ticket.sh
```

### 変更ファイル
- `build.sh`: 警告ヘッダーの追加処理を実装

この警告により、開発者やAIアシスタントが誤ってビルドファイルを直接編集することを防げる。
