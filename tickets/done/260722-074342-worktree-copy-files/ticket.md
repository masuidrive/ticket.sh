---
priority: 2
base_branch: default
description: "worktree_copy_files: 新 worktree 作成時に main repo の指定ファイル群をコピーする opt-in 機能"
created_at: "2026-07-22T07:43:42Z"
started_at: 2026-07-22T07:44:23Z
closed_at: 2026-07-23T05:10:27Z
canceled_at: null
---

# Ticket Overview

`start --worktree` (および worktree を作る他の経路) で新 worktree を作成した直後に、main repo 直下の指定ファイル群を worktree にコピーする opt-in 機能を追加する。

代表ユースケースは gitignore された `.env` 系の設定ファイルを新 worktree でも即座に使いたい、というもの。default は空リスト = 何もしない(既存挙動と等価)。

## Design (合意済み)

- **config キー**: `worktree_copy_files: []` (list of path strings、default 空)
  - `.ticket-config` に永続化。README では `worktree_copy_files: [".env"]` を代表例として提示する。
  - `.env` 決め打ちにはしない — 一般化した list of paths として初版から出す。
- **CLI フラグ**: `--copy-file <path>` (反復指定可)
  - `start --worktree` に添えて config の list に追加する形で上書きする(空 config でもこれ単独で使える)。
- **各エントリごとの挙動**:
  - main repo 直下 (worktree の source) に存在すれば新 worktree にコピー。
  - 新 worktree 側に同名ファイルが既にあれば skip(上書きしない)。
  - main 側に無ければ warning のみで続行(fail しない)。
- **symlink モードは初版に入れない**。将来拡張点として note に記録するのみ。
- **secret 拡散の懸念**: `.env` 系は gitignore 前提の運用のため、共有 config に `worktree_copy_files: [".env"]` が入っていても各人のローカル `.env` が各人の worktree にコピーされるだけで secret は流れない(README に「gitignore 前提」を1行明記する)。

## Tasks

- [x] `src/ticket.sh` の default config template に `worktree_copy_files: []` を追加(コメント付き)
- [x] YAML 読み込みで `worktree_copy_files` を list として parse できることを確認 / 必要なら parser 拡張 — 既存 `yaml_list_size` + `yaml_get "key.N"` で block/inline/empty すべて対応済、拡張不要
- [x] `start` サブコマンドの引数 parse に `--copy-file <path>` (反復可)を追加、config の list に追記する形で保持
- [x] `copy_worktree_files()` ヘルパ関数を追加(source ありコピー / target ありスキップ / source なし warn)
- [x] `cmd_start` の worktree 作成直後で `copy_worktree_files` を呼ぶ(new-branch + resume 両経路)
- [x] `show_usage` / `--help` テキストに `--copy-file` と config キーの説明を追記
- [x] cmd_init の default config heredoc に `worktree_copy_files: []` とその説明コメントを追加(post-init "Next Steps" は既に長いので触れず)
- [x] `README.md` / `README.ja.md` に config 一覧と使用例、gitignore 前提の注意書き
- [x] `spec.md` / `spec.ja.md` に config キー仕様、CLI フラグ仕様、コピー挙動、skip / warn ルールを追記
- [x] `DEV.md` に start_ticket の worktree コピーフックを 1 行追記
- [x] テスト追加 (`test/test-worktree-copy-files.sh`、16 assertions、8 シナリオ):
  - [x] 無効(default 空 list) → コピー発生なし(回帰防止の核)
  - [x] 有効 + main に `.env` あり → worktree にコピーされる
  - [x] 有効 + worktree に既存 `.env` あり → skip(内容が上書きされない)
  - [x] 有効 + main に `.env` 無し → warn のみで exit 0、コピーは発生しない
  - [x] `--copy-file` CLI フラグ単体 → config 空でもコピーされる
  - [x] `--copy-file` 反復 → 複数ファイルコピーされる
  - [x] config + CLI 同時指定 → マージされて両方コピーされる
  - [x] `--copy-file` を `--worktree` なしで指定 → 静かに無視
- [x] `bash build.sh` で root `ticket.sh` を再生成
- [x] `test/run-all.sh` 全 pass (264/264)
- [x] `test/run-all-on-docker.sh` (Ubuntu 245/245 + Alpine 245/245) 全 pass
- [ ] Get developer approval before closing
