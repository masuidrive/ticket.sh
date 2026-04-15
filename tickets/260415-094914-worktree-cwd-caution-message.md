---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "worktree 使用時に cwd 取り違え事故を防ぐため、start/close/help に CAUTION メッセージを追加する"
created_at: "2026-04-15T09:49:14Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# worktree 使用時の cwd 誘導メッセージ追加

## 背景

LLM コーディングエージェント（Claude Code / Codex 等）を使った開発で `./ticket.sh start --worktree` を使うと、メインリポと worktree の 2 ディレクトリが併存する。エージェントの Bash ツールは **呼び出しごとに cwd をリセットする仕様** のため、worktree に移動したつもりでも次のコマンドはメインリポで実行される事故が発生する。

### 実害の例

`start --worktree` 後、PM エージェントがサブエージェントをメインリポ cwd のまま spawn → サブエージェントは worktree の `current-ticket.md` を読めず、`tickets/done/` の直近クローズ済みチケットや git log から誤った文脈を自力で再構成して別チケットをレビューした。symlink 自体は worktree にしか無く、ticket.sh の挙動は正しい。問題は cwd の取り違え。

## 変更内容

### 1. `start --worktree` 終了時の出力に誘導メッセージを追加

worktree の絶対パスを含む CAUTION メッセージを表示する:

```
⚠ CAUTION: 以降のすべてのコマンドは worktree ディレクトリで実行してください。
  cd <worktree絶対パス>

  サブシェル・サブエージェント・別ターミナルを開く場合も、必ず同じパスに cd してから起動してください。
  メインリポのまま作業すると、current-ticket.md が見つからず別チケットの文脈を誤認する事故が発生します。
```

### 2. worktree からの `close` 終了時の出力に復帰メッセージを追加

既存の cd ヒント（`worktree-close-cd-hint` チケットで実装済み）を CAUTION 形式に強化:

```
⚠ CAUTION: worktree は削除されました。メインリポに戻ってください。
  cd <メインリポ絶対パス>
```

### 3. `./ticket.sh help` の `--worktree` オプション説明に注意書きを追加

1〜2 行で、start 後は cd、close 後はメインリポへ戻る、cwd 自動リセット環境では毎回 cd し直す必要があることを追記。

## 表現ルール

- `⚠ CAUTION:` を明示的に付けて、LLM / 人間の両方が見落とさないようにする
- 絶対パスを出す（相対パスは cwd 依存でエージェントが解釈ミスする）
- 「なぜ必要か」を 1 行添える

## やらないこと

- メインリポ側の `current-ticket.md` / `current-note.md` symlink 操作は不要
- `check` コマンドへの警告追加は今回スコープ外

Please record any notes related to this ticket, such as debugging information, review results, or other work logs, `260415-094914-worktree-cwd-caution-message-note.md`.

## Tasks

- [ ] `src/ticket.sh` の worktree 作成部分（cmd_start）で終了時メッセージに CAUTION を追加
- [ ] `src/ticket.sh` の close/cancel 時の worktree 削除後メッセージを CAUTION 形式に更新
- [ ] `src/ticket.sh` の help 出力の `--worktree` 説明に注意書きを追加
- [ ] `bash build.sh` でビルド
- [ ] `test/run-all.sh` / `test/run-all-on-docker.sh` を実行してパス
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
