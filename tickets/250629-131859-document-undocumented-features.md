---
priority: 1
tags: ["documentation", "spec"]
description: "仕様書に記載されていない実装済み機能のドキュメント化"
created_at: "2025-06-29T13:18:59Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# 仕様書に記載されていない機能のドキュメント化

テストスイートで発見された、spec.mdに記載されていない機能を正式にドキュメント化する。

## Tasks
- [ ] `close --force|-f` オプションをspec.mdに追加
- [ ] YAML破損時のグレースフルデグラデーション動作を文書化
- [ ] 複数の`--status`フラグの動作（最後のものが優先）を明記
- [ ] 実装の制限事項（スラグの最大長など）を追加

## Notes
これらの機能は既に実装・テストされているが、仕様書での文書化が不足している。
