---
priority: 1
tags: ["bug-fix", "core", "conflict-handling"]
description: "closeコマンドでマージコンフリクト発生時の復旧フロー改善"
created_at: "2025-06-29T14:50:56Z"
started_at: 2025-06-29T14:51:58Z # Do not modify manually
closed_at: 2025-06-29T15:00:02Z # Do not modify manually
---

# closeコマンドのマージコンフリクト対応改善

`ticket.sh close`実行時にマージコンフリクトが発生すると、closed_atが設定済みのため再実行できない問題を修正する。

## 問題点

現在の実装では：
1. `closed_at`をチケットファイルに設定
2. featureブランチにコミット
3. defaultブランチにチェックアウト
4. マージでコンフリクト発生 → エラー

この状態で再度`close`を実行すると「既にクローズ済み」エラーが発生。

## 解決策

トランザクション的なアプローチを採用：
1. defaultブランチにチェックアウト
2. マージを試行
3. **マージが成功した場合のみ**`closed_at`を更新
4. 最終的なコミットを作成

## Tasks
- [x] closeコマンドの処理順序を変更
- [x] closed_at更新をマージ成功後に移動
- [x] エラーハンドリングの改善
- [x] テストケースの追加
- [x] 既存テストが壊れていないかrun-all-on-dockerで確認

## 実装詳細

### 新しいフロー
1. 事前チェック（clean working dir、ブランチ確認等）
2. defaultブランチにチェックアウト
3. `git merge --squash`を実行
4. マージ成功時：
   - featureブランチに戻る
   - `closed_at`を更新してコミット
   - defaultブランチに戻る
   - マージコミットを作成
5. エラー時は適切なメッセージを表示

### メリット
- コンフリクト時にチケットが中途半端な状態にならない
- 再実行が可能
- より直感的なエラーリカバリー

## Notes
- 後方互換性を維持（既存の動作に影響なし）
- エラーメッセージはコンフリクト解決方法を含める
