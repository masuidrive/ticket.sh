---
priority: 2
tags: ["feature", "ui", "list-command"]
description: "listコマンドの表示改善（closed_at表示とローカルタイムゾーン対応）"
created_at: "2025-06-29T15:26:49Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# listコマンドの表示改善

`ticket.sh list`の表示を改善し、完了済みチケットには`closed_at`を表示、さらに日時をローカルタイムゾーンで表示する。

## 背景

現在の`list`コマンドは：
- doneステータスのチケットに`closed_at`が表示されない
- 日時がUTC（Zulu time）で表示されており、直感的でない
- ローカルタイムゾーンでの表示が望ましい

## Tasks

- [ ] doneステータスのチケットに`closed_at`フィールドを追加表示
- [ ] UTC時刻をローカルタイムゾーンに変換する関数を実装
- [ ] 各プラットフォーム（macOS、Ubuntu、Alpine）での互換性確認
- [ ] タイムゾーン変換が失敗した場合はUTCのまま表示（グレースフルデグラデーション）
- [ ] 表示フォーマットの調整（見やすさの改善）
- [ ] テストケースの追加
- [ ] run-all-on-docker.shで動作確認

## 技術仕様

### 現在の表示例（todo/doing）
```
- status: doing
  ticket_name: 250629-151600-improve-help
  description: ヘルプメッセージの改善
  priority: 2
  created_at: 2025-06-29T15:16:00Z
  started_at: 2025-06-29T15:20:00Z
```

### 改善後の表示例（done）
```
- status: done
  ticket_name: 250629-145056-fix-close-conflict
  description: closeコマンドでマージコンフリクト対応改善
  priority: 1
  created_at: 2025-06-29 23:50:56 JST
  started_at: 2025-06-29 23:51:58 JST
  closed_at: 2025-06-30 00:00:02 JST
```

### タイムゾーン変換の実装方針

```bash
# UTC to local timezone conversion
convert_utc_to_local() {
    local utc_time="$1"
    
    # Try GNU date first (Linux)
    if date --version >/dev/null 2>&1; then
        date -d "${utc_time}" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || echo "$utc_time"
    # Try BSD date (macOS)
    elif date -j >/dev/null 2>&1; then
        date -j -f "%Y-%m-%dT%H:%M:%SZ" "${utc_time}" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || echo "$utc_time"
    # Fallback to original
    else
        echo "$utc_time"
    fi
}
```

### プラットフォーム別の考慮事項

1. **macOS**: BSD date（`-j -f`オプション使用）
2. **Ubuntu**: GNU date（`-d`オプション使用）
3. **Alpine**: BusyBox date（機能限定、フォールバック必要）
4. **タイムゾーン未設定**: UTCのまま表示

## 表示順序

doneステータスのチケットでは以下の順序で表示：
1. status
2. ticket_name
3. description（ある場合）
4. priority
5. created_at
6. started_at
7. closed_at（新規追加）

## Notes

- エラー時は元のUTC表示にフォールバック（表示が壊れないことを優先）
- 将来的には設定で日時フォーマットをカスタマイズ可能に
- パフォーマンスへの影響を最小限に（dateコマンドの呼び出し回数を考慮）
