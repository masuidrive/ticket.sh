---
priority: 3
tags: ["testing", "performance", "scalability"]
description: "大規模環境でのパフォーマンスを検証するテストケースの追加"
created_at: "2025-06-29T13:21:46Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# 大規模環境でのパフォーマンステスト追加

多数のチケットが存在する環境でのパフォーマンスを検証するテストを追加する。

## Tasks
- [ ] test-performance.sh ファイルを作成
- [ ] 100個以上のチケットを生成するセットアップ
- [ ] listコマンドのパフォーマンス測定
- [ ] 大きなチケットファイル（10MB以上）での動作確認
- [ ] 深いディレクトリ構造での動作検証
- [ ] パフォーマンスのベンチマーク基準値の設定

## Notes
実際の長期運用を想定し、チケットが蓄積された状態でも快適に動作することを確認する。
