---
priority: 2
tags: ["feature", "organization", "workflow"]
description: "完了したチケットをdoneフォルダに移動する機能の実装"
created_at: "2025-06-29T15:23:44Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# 完了チケットのdoneフォルダ整理機能

完了したチケットを`tickets/done/`フォルダに移動することで、アクティブなチケットと完了済みチケットを視覚的に区別できるようにする。

## 背景

現在、すべてのチケットが`tickets/`フォルダに混在しており、ファイル名だけでは完了状態が判別できない。フォルダ構造で整理することで：
- ファイル一覧で状態が一目瞭然
- アクティブなチケットの把握が容易
- 将来的に`doing/`フォルダなどの拡張も可能

## Tasks

- [ ] `close`コマンドで`tickets/done/`フォルダへの移動処理を追加
- [ ] `tickets/done/`フォルダが存在しない場合は自動作成
- [ ] `git mv`を使用してGit履歴を保持
- [ ] `list`コマンドを更新して`done/`フォルダ内も検索対象に
- [ ] 既存の完了済みチケットの移行スクリプトを作成（オプション）
- [ ] テストケースの追加
- [ ] ドキュメント（spec.md、spec.ja.md）の更新
- [ ] run-all-on-docker.shでテスト確認

## 技術仕様

### フォルダ構造
```
tickets/
├── 250629-132020-add-unicode-tests.md     # 未着手
├── 250629-151600-improve-help.md          # 作業中
└── done/
    ├── 250629-131859-document-features.md # 完了
    └── 250629-145056-fix-close.md        # 完了
```

### closeコマンドの変更点
1. チケットのclosed_atを更新後、コミット
2. defaultブランチでマージ完了後
3. `git mv tickets/xxx.md tickets/done/xxx.md`を実行
4. 移動をコミット（メッセージ: "Move completed ticket to done folder"）

### listコマンドの変更点
- `tickets/*.md`に加えて`tickets/done/*.md`も検索
- パスは表示せず、チケット名のみ表示（現状維持）

## 考慮事項

- **後方互換性**: 既存のワークフローに影響を与えない
- **エラーハンドリング**: doneフォルダ作成失敗時の処理
- **権限**: フォルダ作成・ファイル移動の権限確認
- **シンボリックリンク**: current-ticket.mdは移動しない（完了時に削除される）

## 移行オプション

既存の完了済みチケットを移行する場合：
```bash
# 移行スクリプト例
for file in tickets/*.md; do
  if grep -q "closed_at: null" "$file"; then
    continue
  fi
  git mv "$file" "tickets/done/"
done
git commit -m "Organize completed tickets into done folder"
```

## Notes

この機能により、チケット管理がより直感的になり、特に多数のチケットがある場合の視認性が大幅に向上する。将来的には`doing/`フォルダなども追加して、カンバンボードのような構造も実現可能。
