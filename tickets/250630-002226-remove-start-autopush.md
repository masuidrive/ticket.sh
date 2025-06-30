---
priority: 2
tags: []
description: "startコマンドでの自動プッシュを削除"
created_at: "2025-06-30T00:22:26Z"
started_at: 2025-06-30T00:23:01Z # Do not modify manually
closed_at: 2025-06-30T00:50:02Z # Do not modify manually
---

# startコマンドでの自動プッシュを削除

`ticket.sh start`コマンドで自動的にリモートブランチを作成するのを廃止し、GitHubのUIに不要なブランチが表示されないようにする。

## 背景

現在の動作では`auto_push: true`の場合、startコマンドで以下が実行される：
- featureブランチ作成後、即座に`git push -u origin feature/...`
- これによりGitHubに「Compare & pull request」ボタンが表示される
- squashマージ後もブランチが残り、手動削除が必要

## Tasks
- [x] startコマンドからauto_pushによるプッシュ処理を削除
- [x] --no-pushフラグの説明を更新（startでは不要になるため）
- [x] ヘルプメッセージの更新
- [x] テストケースの修正
- [x] 全テストが通ることを確認

## Notes
- closeコマンドでのauto_pushは維持（完成したコードをリモートに送る必要があるため）
- 必要に応じて手動で`git push -u origin feature/...`できることをドキュメントに記載
