---
priority: 2
base_branch: default
description: "worktree_copy_files: 新 worktree 作成時に main repo の指定ファイル群をコピーする opt-in 機能"
created_at: "2026-07-22T07:43:42Z"
started_at: null
closed_at: null
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

- [ ] `src/ticket.sh` の default config template に `worktree_copy_files: []` を追加(コメント付き)
- [ ] YAML 読み込みで `worktree_copy_files` を list として parse できることを確認 / 必要なら parser 拡張
- [ ] `start` サブコマンドの引数 parse に `--copy-file <path>` (反復可)を追加、config の list に追記する形で保持
- [ ] `copy_worktree_files()` ヘルパ関数を追加:
  - 引数: source dir (main repo root), target dir (worktree root), list of paths
  - 挙動: 各 path について source に存在すれば target にコピー、target に既にあれば skip、source に無ければ stderr に warn
- [ ] `cmd_start` の worktree 作成直後 (worktree ブランチが checkout された後) で `copy_worktree_files` を呼ぶ
- [ ] `show_usage` / `--help` テキストに `--copy-file` と config キーの説明を追記
- [ ] `cmd_init` の post-init 案内 (Next Steps) や README template で `worktree_copy_files` に触れる(重くしすぎない)
- [ ] `README.md` / `README.ja.md` に config 一覧と使用例 (`worktree_copy_files: [".env"]`)、gitignore 前提の注意書き
- [ ] `spec.md` / `spec.ja.md` に config キー仕様、CLI フラグ仕様、コピー挙動、skip / warn ルールを追記
- [ ] `DEV.md` 更新(必要なら)
- [ ] テスト追加 (`test/test-worktree-copy-files.sh` 相当、`test/run-all.sh` に組み込み):
  - 有効 + main に `.env` あり → worktree にコピーされる
  - 有効 + worktree に既存 `.env` あり → skip(内容が上書きされない)
  - 有効 + main に `.env` 無し → warn のみで exit 0、コピーは発生しない
  - 無効(default 空 list) → コピー発生なし(回帰防止の核)
  - `--copy-file` CLI フラグ単体 → config 空でもコピーされる
  - `--copy-file` 反復 → 複数ファイルコピーされる
- [ ] `bash build.sh` で root `ticket.sh` を再生成
- [ ] `test/run-all.sh` 全 pass
- [ ] `test/run-all-on-docker.sh` (Ubuntu + Alpine) 全 pass
- [ ] Get developer approval before closing
