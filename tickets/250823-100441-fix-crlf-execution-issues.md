---
priority: 2
description: "ticket.sh実行ファイル自体のCRLF改行コード問題を根本的に解決する"
created_at: "2025-08-23T10:04:41Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
---

# ticket.sh実行ファイルのCRLF問題根本解決

## 問題の概要
ticket.shファイル自体がCRLF改行コード（Windows形式）で保存されると、Unix/Linux環境で実行時に以下のエラーが発生する：

```
/usr/bin/env: 'bash\r': No such file or directory
```

## 発生原因
1. **Git設定**: `core.autocrlf=true`でWindows環境からコミット時にCRLFが混入
2. **エディタ設定**: VSCode等でCRLF改行コードが自動設定される
3. **selfupdateコマンド**: GitHubからダウンロード時にCRLF変換される可能性
4. **クロスプラットフォーム開発**: 開発者の環境による改行コード差異

## 影響範囲
- ticket.shファイルが実行不可能になる
- selfupdateコマンドが失敗する
- Windows環境の開発者がLinux環境で作業する際に問題が発生

## 根本的解決策
GitとビルドプロセスレベルでLF改行コードを強制し、環境に依存しない実行ファイルを生成する。

## Tasks

- [ ] .gitattributesファイルでticket.sh関連ファイルをLF強制設定
- [ ] build.shでticket.sh生成時にLF改行コードを保証
- [ ] selfupdateコマンドでダウンロード後のLF変換処理を追加
- [ ] 既存のticket.shファイルの改行コード確認・修正
- [ ] 各種環境でのテスト（Windows, macOS, Linux）
- [ ] ドキュメントにクロスプラットフォーム注意事項を追記
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Get developer approval before closing
