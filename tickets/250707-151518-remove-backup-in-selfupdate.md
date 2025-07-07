---
priority: 2
tags: []
description: "Remove backup file creation in ticket.sh selfupdate command"
created_at: "2025-07-07T15:15:18Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
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

- [ ] selfupdateコマンドの現在の実装を確認
- [ ] バックアップ作成部分を特定
- [ ] バックアップ作成ロジックを削除
- [ ] selfupdateコマンドのテスト
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing


## Notes

バックアップを残さないことで、ディレクトリがよりクリーンに保たれ、不要なファイルの蓄積を避けることができます。
