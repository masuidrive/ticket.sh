---
priority: 3
tags: ["testing", "filesystem", "permissions"]
description: "ファイルシステム権限に関するエラー処理のテストケース追加"
created_at: "2025-06-29T13:22:27Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# ファイル権限エラーのテストケース追加

ファイルシステムの権限に関連するエラーケースを網羅的にテストする。

## Tasks
- [ ] 読み取り専用ディレクトリでのinitコマンドのテスト
- [ ] 書き込み権限のないtickets/ディレクトリでのnewコマンドのテスト
- [ ] シンボリックリンク作成権限がない場合のstartコマンドのテスト
- [ ] ディスクフル状態のシミュレーション
- [ ] 権限エラー時の適切なエラーメッセージの確認

## Notes
異なるOS環境でのファイル権限の扱いの違いも考慮する必要がある。特にWindowsとUnix系OSの違いに注意。
