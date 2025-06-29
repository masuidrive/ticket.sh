---
priority: 2
tags: ["testing", "network", "error-handling"]
description: "ネットワーク関連のエラー処理をテストするケースの追加"
created_at: "2025-06-29T13:19:40Z"
started_at: 2025-06-29T14:17:49Z # Do not modify manually
closed_at: 2025-06-29T14:40:16Z # Do not modify manually
---

# Git操作失敗時のコンテキストに応じたエラーメッセージ改善

Git操作が失敗した際に、実行中の操作（start, close等）に応じた適切なエラーメッセージと対処法を表示する。

## Tasks
- [x] エラーメッセージ仕様の定義
- [x] `start`コマンドのエラーメッセージ実装
- [x] `close`コマンドのエラーメッセージ実装
- [x] run-all-on-docker.shで既存テストが壊れていないか確認

## エラーメッセージ仕様

### エラーメッセージの基本方針

1. **エラータイトル**: 何が失敗したかを簡潔に示す
2. **詳細説明**: なぜ失敗したか、現在の状況を説明
3. **対処法リスト**: 番号付きで具体的なアクションを提示
4. **コマンド例**: 実行可能なコマンドを含める

### `start` コマンドのエラーメッセージ

#### 1. ブランチ作成失敗 (git checkout -b)
```
Error: Failed to create feature branch
Could not create branch '{branch_prefix}{ticket_name}'. Please:
1. Check if the branch already exists: git branch -a | grep {ticket_name}
2. If it exists, switch to it: git checkout {branch_prefix}{ticket_name}
3. Or delete the old branch: git branch -D {branch_prefix}{ticket_name}
4. Check current branch status: git status
```

#### 2. プッシュ失敗 (git push -u)
```
Warning: Failed to push branch to remote
The feature branch was created locally but could not be pushed.
The ticket has been started successfully. To push later:
  git push -u {repository} {branch_prefix}{ticket_name}

Possible reasons:
1. Network connection issues
2. Authentication problems
3. Remote repository permissions
```

### `close` コマンドのエラーメッセージ

#### 1. ファイルステージング失敗 (git add)
```
Error: Failed to stage ticket file
Could not add the ticket file for commit. Please:
1. Check file permissions: ls -la {ticket_file}
2. Ensure the file exists and is not corrupted
3. Try manually: git add {ticket_file}
4. Check git status: git status
```

#### 2. コミット失敗 (git commit)
```
Error: Failed to commit ticket changes
Could not commit the closed ticket. Please:
1. Check if there are changes to commit: git status
2. Ensure you have configured git user: git config user.name
3. Try committing manually: git commit -m "Close ticket"
4. Check for pre-commit hooks that may be failing
```

#### 3. featureブランチプッシュ失敗 (git push)
```
Warning: Failed to push feature branch
The feature branch changes could not be pushed, but close process will continue.
You can push the feature branch later:
  git push {repository} {current_branch}
```

#### 4. ブランチ切り替え失敗 (git checkout)
```
Error: Failed to switch to {default_branch} branch
Could not checkout the {default_branch} branch. Please:
1. Check if you have uncommitted changes: git status
2. Stash or commit any changes: git stash
3. Try manually: git checkout {default_branch}
4. Ensure the {default_branch} branch exists: git branch
```

#### 5. マージ失敗 (git merge --squash)
```
Error: Failed to merge ticket changes
Could not merge the feature branch. Please:
1. Check for merge conflicts: git status
2. Ensure you're on the correct branch: git branch
3. Try merging manually: git merge --squash {current_branch}
4. Check if the feature branch has commits: git log {current_branch}
```

#### 6. マージコミット失敗 (git commit -F)
```
Error: Failed to create merge commit
Could not commit the merged changes. Please:
1. Check staged changes: git status
2. Ensure there are changes to commit
3. Try committing manually with a simple message
4. Check for commit hooks that may be blocking
```

#### 7. mainブランチプッシュ失敗 (git push)
```
Error: Push failed
Failed to push to '{repository}'. Please:
1. Check network connection
2. Verify repository permissions
3. Try manual push: git push {repository} {default_branch}
4. Check if remote repository exists
```

### 実装上の注意点

- `{variable}` の部分は実際の値に置換する
- エラーメッセージは標準エラー出力（>&2）に出力
- 警告（Warning）の場合は処理を継続
- エラー（Error）の場合は処理を中断（return 1）
