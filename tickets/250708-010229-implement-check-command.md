---
priority: 2
tags: []
description: "checkコマンドの実装：現在のディレクトリとgitの状態をチェックし、チケットファイルとブランチの整合性を確認"
created_at: "2025-07-08T01:02:29Z"
started_at: 2025-07-08T01:11:34Z # Do not modify manually
closed_at: 2025-07-08T01:47:16Z # Do not modify manually
---

# checkコマンドの実装

## 概要
checkコマンドを実装し、現在のディレクトリとgitの状態をチェックして、チケットファイルとブランチの整合性を確認する機能を追加する。

## 課題
現在のticket.shには、作業中のチケットとブランチの状態を確認するコマンドが存在しない。ユーザーが作業状態を把握しやすくするため、現在の状態を診断するcheckコマンドが必要。

## 要件

### 基本機能
1. 現在のディレクトリとgitリポジトリの状態をチェック
2. current-ticket.mdの存在とリンク先の整合性確認
3. ブランチ名とチケットファイル名の一致確認
4. 適切なメッセージを英語で表示

### 処理フロー
1. **current-ticket.mdが存在する場合**
   - リンク先のファイル名とブランチ名の一致確認
   - 不一致：エラーメッセージを表示して終了
   - 一致：正常状態を表示して終了

2. **current-ticket.mdが存在しない場合**
   - デフォルトブランチの場合：未処理チケットの確認方法を案内
   - featureブランチの場合：
     - 同名チケットでstarted_atがnull以外：restore処理実行
     - 同名チケットが見つからない：チケット状況エラー表示
   - その他のブランチの場合：デフォルトブランチへの移動を推奨

### メッセージ仕様
- 他のコマンドと同じ文体と構成で英語表示
- 明確で分かりやすい案内メッセージ
- 次に行うべきアクションを明示

## Tasks
- [x] checkコマンドの詳細仕様を定義
- [x] cmd_check関数を実装
- [x] メインコマンドディスパッチャーにcheck追加
- [x] ヘルプメッセージにcheck追加
- [x] 各種状態のメッセージテキストを作成
- [x] current-ticket.mdの整合性チェック機能実装
- [x] ブランチ名とチケットファイル名の照合機能実装
- [x] restore処理の統合
- [x] テスト実行と動作確認
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Get developer approval before closing

### メッセージ案

#### 1. current-ticket.mdが存在し、ブランチ名と一致する場合
```
✓ Current ticket is active and synchronized
Working on: [ticket-name]
Branch: [branch-name]
Continue working on this ticket.
```

#### 2. current-ticket.mdが存在するが、ブランチ名と不一致の場合
```
✗ Ticket file and branch mismatch detected
Current ticket file: [ticket-file]
Current branch: [branch-name]
Please run 'ticket.sh restore' to fix synchronization or switch to the correct branch.
```

#### 3. current-ticket.mdが存在しない、デフォルトブランチの場合
```
✓ No active ticket (on default branch)
You can view available tickets with: ticket.sh list
Create a new ticket with: ticket.sh new <name>
Start working on a ticket with: ticket.sh start <ticket-name>
```

#### 4. current-ticket.mdが存在しない、featureブランチで同名チケットが存在し復元可能な場合
```
✓ Found matching ticket for current branch
Restored ticket link: [ticket-name]
Continue working on this ticket.
```

#### 5. current-ticket.mdが存在しない、featureブランチで同名チケットが見つからない場合
```
✗ No ticket found for current feature branch
Current branch: [branch-name]
Expected ticket file: [expected-ticket-file]

Possible solutions:
1. Create new ticket: ticket.sh new <name>
2. Check if ticket file exists in another branch (git branch -a)
3. Switch to default branch: git checkout [default-branch]
```

#### 6. current-ticket.mdが存在しない、その他のブランチの場合
```
⚠ You are on an unknown branch
Current branch: [branch-name]
Recommended: Switch to default branch with 'git checkout [default-branch]'
Then use 'ticket.sh list' to see available tickets.
```

### エラーメッセージ詳細
- **チケット状況エラー**：featureブランチに対応するチケットファイルが見つからない場合
  - 対応策1：`ticket.sh new`で新しくチケットを作成
  - 対応策2：別ブランチにチケットファイルがcommitされていないか確認
  - 対応策3：デフォルトブランチに戻る

## Notes
- ticket.sh restore と同じ処理を部分的に利用
- 既存のヘルパー関数（check_git_repo, get_current_branch等）を活用
- エラーハンドリングを適切に実装
- ユーザビリティを重視したメッセージ設計
- すべてのケースを網羅した診断機能
