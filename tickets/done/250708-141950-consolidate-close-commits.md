---
priority: 2
tags: ["enhancement", "git", "close"]
description: "Consolidate ticket close commits - merge 'Move completed ticket to done folder' with main ticket commit"
created_at: "2025-07-08T14:19:50Z"
started_at: 2025-07-08T14:25:52Z # Do not modify manually
closed_at: 2025-07-08T14:29:37Z # Do not modify manually
---

# Consolidate Close Commits

## 概要
closeコマンド実行時に生成される2つのコミット（メインのticket commit + "Move completed ticket to done folder"）を1つのコミットに統合して、履歴をクリーンに保つ。

## 問題の詳細

### 現在の動作
closeコマンド実行時に以下の2つのコミットが作成される：

1. **メインコミット**: チケット内容全体を含む詳細なコミット
   ```
   [250708-133610-fix-ci-yaml-sh-test-permissions] Fix CI yaml-sh test execution
   
   チケット内容全体（YAML frontmatter + markdown本文）
   ```

2. **done移動コミット**: シンプルなファイル移動コミット
   ```
   Move completed ticket to done folder
   ```

### 問題点
- **履歴の冗長性**: 論理的に1つの作業が2つのコミットに分かれる
- **Git履歴の可読性**: 関連する変更が分離されている
- **チケット完了の原子性**: 1つの操作が複数のコミットに分かれている

## 要件

### 修正方針
1. **コミット統合**: done folder移動をメインコミットに含める
2. **Git操作最適化**: squash mergeの後にファイル移動を追加
3. **履歴の保持**: チケット内容の詳細な記録は維持

### 具体的な実装
**現在の処理順序**:
```bash
1. git merge --squash feature-branch
2. git commit -F - (チケット内容でコミット)
3. git mv ticket.md done/ticket.md
4. git commit -m "Move completed ticket to done folder"
```

**変更後の処理順序**:
```bash
1. git merge --squash feature-branch
2. git mv ticket.md done/ticket.md
3. git add done/ticket.md
4. git commit -F - (チケット内容でコミット、done移動も含む)
```

## Tasks
- [ ] closeコマンドの現在の処理順序を確認
- [ ] squash merge後のファイル移動タイミングを変更
- [ ] done folder移動をメインコミットに統合
- [ ] コミットメッセージの調整（必要に応じて）
- [ ] エラーハンドリングの確認
- [ ] テストで動作確認
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing

## 実装詳細

### 修正対象
**ファイル**: `src/ticket.sh` の `cmd_close()` 関数

### 変更箇所
```bash
# 現在: squash merge → commit → mv → commit
git merge --squash $current_branch
echo -e "$commit_msg" | git commit -F -

# done folder移動
git mv "$ticket_file" "$new_ticket_path"
git commit -m "Move completed ticket to done folder"

# 変更後: squash merge → mv → commit (統合)
git merge --squash $current_branch

# done folder移動を先に実行
git mv "$ticket_file" "$new_ticket_path"

# 統合コミット
echo -e "$commit_msg" | git commit -F -
```

## Notes
- この変更により、チケット完了が1つのatomicな操作になる
- Git履歴がよりクリーンになり、チケット完了の追跡が容易
- done folder移動も含めてチケット内容と一緒に記録される
- エラーハンドリングは引き続き重要（ファイル移動失敗時の対応等）
