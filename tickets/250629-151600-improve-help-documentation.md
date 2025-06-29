---
priority: 2
tags: ["documentation", "help", "workflow"]
description: "ヘルプメッセージの改善とワークフロー説明の更新"
created_at: "2025-06-29T15:16:00Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# ヘルプメッセージの改善

ticket.shのヘルプメッセージを改善し、実際の使用方法をより明確にする。

## 背景

現在のヘルプメッセージは基本的な情報は提供しているが、以下の点で改善が必要：
- Markdown形式になっていない部分がある
- closeコマンドの重要な注意事項が記載されていない
- チケット内容の確認やチェックリストの処理について言及がない

## Tasks

- [ ] ヘルプメッセージ全体をMarkdown形式に統一
- [ ] WORKFLOWセクションにcloseコマンドの注意事項を追加
  - [ ] closeはユーザーの確認を取ってから実行すること
  - [ ] close前にチケット内容を確認すること
  - [ ] チェックリストがある場合は完了状態を確認してチェックすること
- [ ] 他の場所で指示されたワークフローがある場合はそちらを優先する旨を追記
- [ ] 実装後、`./ticket.sh help`で表示確認
- [ ] テストが壊れていないことを確認

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
