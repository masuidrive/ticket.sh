---
priority: 1
tags: ["bug", "testing", "list-command"]
description: "テストスイートで失敗している3つのテストケースを修正"
created_at: "2025-06-29T16:23:27Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# テストスイートの失敗を修正

現在、テストスイートで3つのテストが失敗している。これらの失敗を調査し、修正する。

## 背景

Docker環境（Ubuntu 22.04、Alpine Linux）およびローカル環境でのテスト実行時に、以下の3つのテストが一貫して失敗している：

1. **list count parameter** - `--count`パラメータが正しく動作していない
2. **priority sorting in list** - listコマンドでの優先度ソートが期待通りに動作していない可能性
3. **Close updates ticket** - チケットクローズ時の更新確認テストが失敗

## Tasks

### 1. list count parameterの修正
- [ ] `test-additional.sh`のテスト5を調査
- [ ] listコマンドの`--count`オプションの実装を確認
- [ ] カウント制限が正しく適用されるよう修正
- [ ] テストが成功することを確認

### 2. priority sortingの修正
- [ ] `test-additional.sh`のテスト11を調査
- [ ] listコマンドの優先度ソートロジックを確認
- [ ] 優先度順（高い順）でソートされるよう修正
- [ ] テストが成功することを確認

### 3. Close updates ticketの修正
- [ ] `test-final.sh`の該当テストを調査
- [ ] closeコマンドでチケットのメタデータ更新を確認
- [ ] `closed_at`フィールドが正しく更新されることを確認
- [ ] テストが成功することを確認

## 詳細情報

### テスト失敗の詳細

1. **list count parameter**
   ```
   5. Testing list count parameter...
     ✗ Count parameter not working
       Details: Got: 1=0, 3=0, 10=0
   ```

2. **priority sorting**
   ```
   11. Testing priority sorting in list...
     ✗ Priority sorting may be incorrect
       Details: First ticket was: 
   ```

3. **Close updates ticket**
   ```
   ✗ Close updates ticket
   ```

### 影響範囲

- これらの問題は機能的なバグであり、ユーザー体験に影響を与える
- 特にlistコマンドの問題は、大量のチケットを扱う際に重要

## Notes

- すべてのテスト環境（ローカル、Ubuntu Docker、Alpine Docker）で同じ失敗が発生
- ファイル所有権の警告（`mv: failed to preserve ownership`）は別の問題であり、このチケットのスコープ外
