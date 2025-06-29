# テスト失敗の原因分析とグルーピング

## 1. プラットフォーム依存の問題

### sed -i の違い
- **BSD (macOS)**: `sed -i '' 's/pattern/replacement/' file`
- **GNU (Linux)**: `sed -i 's/pattern/replacement/' file`
- **現状**: 一部のテストで両方試しているが、不完全

### 影響を受けるテスト
- test-additional.sh (3箇所)
- test-missing-coverage.sh (2箇所)

## 2. Git追跡の問題

### 原因
- `git add .` で ticket.sh 自体を追跡
- プラットフォーム間でファイル属性が異なる

### 影響を受けるテスト
- test-close-force.sh
- test-additional.sh
- test-basic.sh
- test-comprehensive-fixed.sh
- test-final.sh

## 3. ファイル操作の問題

### mktemp の違い
- **BSD**: `mktemp -t prefix`
- **GNU**: `mktemp --tmpdir prefix.XXXXXX`
- **現状**: 引数なしで使用（互換性あり）

### ls の違い
- ファイルがない時の挙動が異なる
- **解決済み**: safe_get_first_file 関数で対応

## 4. 環境変数の問題

### noclobber
- **解決済み**: 削除済み

### ロケール
- **解決済み**: C.UTF-8 に統一

## 失敗パターンの分類

### A. sed -i による失敗（5件）
- カスタムブランチプレフィックステスト
- 優先度ソートテスト

### B. git add . による失敗（12件）
- close --force テスト（3件）
- start コマンドテスト（複数）
- 複数チケットワークフロー

### C. その他（未分類）
- カウントパラメータテスト
- auto_push 設定テスト