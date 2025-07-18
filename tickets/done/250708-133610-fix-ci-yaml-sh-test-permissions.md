---
priority: 2
tags: ["ci", "permissions", "yaml-sh"]
description: "Fix CI yaml-sh test execution - change from ./test.sh to bash ./test.sh to avoid permission issues"
created_at: "2025-07-08T13:36:10Z"
started_at: 2025-07-08T13:57:55Z # Do not modify manually
closed_at: 2025-07-08T14:00:09Z # Do not modify manually
---

# Fix CI yaml-sh Test Permission Issues

## 概要
CI環境でyaml-shのtest.shが実行権限エラーで失敗する問題を修正する。`./test.sh`から`bash ./test.sh`に変更してexecute bitに依存しない実行方式に変更する。

## 問題の詳細

### CI エラー
```
Run cd yaml-sh
/home/runner/work/_temp/644b97d1-e910-4c59-bb7e-70a0610b99ee.sh: line 2: ./test.sh: Permission denied
Error: Process completed with exit code 126.
```

### 根本原因
1. **Execute bit消失**: GitやCI環境でファイルのexecute権限が失われる
2. **権限依存実行**: `./test.sh`はexecute bitが必要
3. **CI環境の制約**: GitHub Actionsなどでファイル権限が保持されない場合がある

### Execute bit消失の原因
- Gitのcore.filemode設定
- Windowsファイルシステムからの操作
- CI環境でのcheckout処理
- ファイルの編集・保存時の権限リセット

## 要件

### 修正方針
1. **権限に依存しない実行方式**: `bash ./test.sh`を使用
2. **CI設定ファイルの更新**: GitHub Actionsワークフローの修正
3. **統一的な実行方式**: 他のスクリプトとの整合性確保

### 対象ファイル
- `.github/workflows/ci.yml` (またはCI設定ファイル)
- `yaml-sh/test.sh`の実行方式変更

## Tasks
- [x] CI設定ファイル（GitHub Actions）を特定
- [x] yaml-sh test実行箇所を確認
- [x] `./test.sh`を`bash ./test.sh`に変更
- [x] 他のスクリプト実行も同様の問題がないか確認
- [x] CI実行テストで検証
- [x] ローカル環境でも動作することを確認
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Get developer approval before closing

## 修正例

### 変更前
```yaml
- name: Run yaml-sh tests
  run: |
    cd yaml-sh
    ./test.sh
```

### 変更後
```yaml
- name: Run yaml-sh tests
  run: |
    cd yaml-sh
    bash ./test.sh
```

## 実装結果

### 修正内容
**ファイル**: `.github/workflows/test.yml:65-68`

**変更前**:
```yaml
- name: Test yaml-sh
  run: |
    cd yaml-sh
    ./test.sh
```

**変更後**:
```yaml
- name: Test yaml-sh
  run: |
    cd yaml-sh
    bash ./test.sh
```

### 検証結果
- ✅ ローカル環境でbash実行が正常動作（27/27テスト合格）
- ✅ 他のスクリプト実行は既にchmod +xで適切に処理済み
- ✅ 権限に依存しない確実な実行方式に変更完了

### 効果
1. **CI安定性向上**: execute bit消失でもテストが失敗しない
2. **環境非依存**: Windows、Linux、macOS環境で統一動作
3. **保守性向上**: 権限設定の手間が不要

## Notes
- この問題は権限に依存しない実行方式で解決可能
- 他のCI環境（GitLab CI、Jenkins等）でも同様の問題が発生する可能性
- bash実行はshebang行を正しく解釈するため互換性が高い
- execute bitの保持は環境依存なので、bash実行の方が確実
