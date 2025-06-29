---
priority: 1
tags: ["documentation", "spec"]
description: "仕様書に記載されていない実装済み機能のドキュメント化"
created_at: "2025-06-29T13:18:59Z"
started_at: 2025-06-29T13:48:48Z # Do not modify manually
closed_at: 2025-06-29T14:16:19Z # Do not modify manually
---

# 仕様書に記載されていない機能のドキュメント化

テストスイートで発見された、spec.mdに記載されていない機能を正式にドキュメント化する。

## Tasks
- [x] `close --force|-f` オプションをspec.mdに追加
- [x] YAML破損時のグレースフルデグラデーション動作を文書化
- [x] 複数の`--status`フラグの動作（最後のものが優先）を明記
- [x] 実装の制限事項（スラグの最大長など）を追加
- [x] test/run-all-on-docker.shを全てパスすること
- [x] ヘルプのWORKFLOWセクションを改善（listでtodoを確認する手順を追加）
- [x] ヘルプメッセージを.ticket-config.yamlの設定値で動的に生成

## Notes
これらの機能は既に実装・テストされているが、仕様書での文書化が不足している。
