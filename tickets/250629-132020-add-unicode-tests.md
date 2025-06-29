---
priority: 2
tags: ["testing", "i18n", "unicode"]
description: "UTF-8およびUnicode文字の処理を検証するテストケースの追加"
created_at: "2025-06-29T13:20:20Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# UTF-8/Unicode処理のテストケース追加

仕様書で言及されているUTF-8サポートを検証するテストケースを追加する。

## Tasks
- [ ] test-unicode.sh ファイルを作成
- [ ] チケットタイトルでの日本語・絵文字のテスト
- [ ] チケット本文での多言語文字のテスト
- [ ] ブランチ名での非ASCII文字の扱いを検証
- [ ] コミットメッセージでのUnicode文字のテスト
- [ ] 異なるロケール設定での動作確認

## Notes
spec.mdではLANG=C.UTF-8とLC_ALL=C.UTF-8の自動設定が明記されているため、その動作も検証する。
