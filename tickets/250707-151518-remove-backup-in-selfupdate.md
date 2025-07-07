---
priority: 2
tags: []
description: "Remove backup file creation in ticket.sh selfupdate command"
created_at: "2025-07-07T15:15:18Z"
started_at: 2025-07-07T15:15:42Z # Do not modify manually
closed_at: 2025-07-07T15:35:23Z # Do not modify manually
---

# Remove Backup in Selfupdate Command

現在の `ticket.sh selfupdate` コマンドは更新時にバックアップファイルを作成していますが、これを削除してクリーンに更新するようにします。

## 現在の動作

selfupdateコマンドは更新前に `ticket.sh.backup` のようなバックアップファイルを作成している可能性があります。

## 要求される変更

- selfupdate実行時にバックアップファイルを作成しない
- 既存のバックアップファイルがあれば削除（オプション）
- よりクリーンな更新プロセスの実装

## Tasks

- [x] selfupdateコマンドの現在の実装を確認
- [x] バックアップ作成部分を特定
- [x] バックアップ作成ロジックを削除
- [x] selfupdateコマンドのテスト
- [x] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing


## Notes

バックアップを残さないことで、ディレクトリがよりクリーンに保たれ、不要なファイルの蓄積を避けることができます。

### 実装内容

**削除したコード（src/ticket.sh の cmd_selfupdate 関数内）:**

1. **バックアップ作成ロジック**: 
   - `cp "$script_path" "${script_path}.backup"` を削除

2. **バックアップ保存メッセージ**:
   - `echo "Backup saved to: ${script_path}.backup"` を削除

**変更後の動作:**
- selfupdate実行時にバックアップファイル（.backup）を作成しない
- 更新完了メッセージがより簡潔になった
- ディレクトリがクリーンに保たれる

**テスト結果:**
- 全テストスイート合格（27/27 yaml-sh tests）
- 既存機能に影響なし
- コマンドヘルプでselfupdateコマンドが正常に表示される
