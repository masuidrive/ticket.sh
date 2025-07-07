---
priority: 2
tags: []
description: "Improve init command to be idempotent - check and create only missing components"
created_at: "2025-07-07T15:05:48Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# Improve Init Command Idempotency

現在のinitコマンドは設定ファイルとticketsディレクトリが両方存在すると「既に初期化済み」として処理を終了してしまいます。

これを改善して、個別のコンポーネントごとにチェックし、不足分だけを作成するようにします。これにより、新機能（例：tickets/README.md）が追加された場合でも、既存環境で取得できるようになります。

## 現在の問題

- 既存のディレクトリでinitを実行すると、新しく追加されたコンポーネント（tickets/README.md等）がスキップされる
- 「既に初期化済み」メッセージで処理が終了してしまう

## 解決策

個別ファイル/ディレクトリごとに存在チェックを行い：
- 存在する場合：「already exists」メッセージで スキップ
- 存在しない場合：新規作成

## Tasks

- [x] 現在のinit実装を分析
- [x] 個別コンポーネントチェックロジックに変更
- [ ] 各コンポーネントの個別チェック実装
- [ ] 適切なメッセージ表示の実装
- [ ] テストして動作確認
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Get developer approval before closing


## Notes

Additional notes or requirements.
