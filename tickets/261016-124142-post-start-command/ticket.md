---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "worktree を作った直後に導入先のコマンドを実行する設定（post_start_command / GH #19）"
created_at: "2026-10-16T12:41:42Z"
started_at: 2026-10-16T12:42:02Z # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GH #19。`start` が作る worktree には、コピーでは作れないものが入らない。
`worktree_copy_files` で `.env` のような gitignore されたファイルは持ち込めるが、
`node_modules` のように**コマンドを走らせないと作れないもの**（`npm ci` / `uv sync` /
`bundle install`）を用意する設定が無い。

PDH を使う llmhub では、worktree で test-all を回すと `frontend/node_modules` も
repo root の `node_modules` も無く依存不足で落ちる。いまは「worktree では先に
`npm install`」と文書に書いて agent が読むことに頼っており、読み落として vitest が
起動できなかった実例がある。

#18 の `pre_close_command`（close の前）と対になる、start の後のコマンドを足す。

## 設計判断（issue の提案どおり）

1. config に `post_start_command:`。shell 1 行。既定は空
2. **worktree を新しく作ったときだけ**、`worktree_copy_files` のコピーの後に、
   その worktree の root で実行する。既にある worktree を使うとき・worktree を
   作らない start では実行しない（毎回 install し直さない）
3. **失敗しても start は成功させる。** 非 0 なら warning と出力を見せ、start は 0。
   worktree は作れているので手で直して続けられる。#18 は「通らなければ進ませない」
   検査なので止めるが、こちらは「作業の場所を整える」準備なので止めない
4. 出力はそのまま見せ、`Active ticket paths:` はその後に出す
5. #18 と同じ 5 つの環境変数を渡す
6. `start --no-post-start` で 1 回だけ飛ばせる

## Tasks

- [ ] `post_start_command` を config に足す（既定値・生成される config のコメント）
- [ ] `post_start_run()` を lib に足す（worktree root で実行・失敗しても 0）
- [ ] worktree を新規作成した 2 経路（新しい branch / 既存 branch）で呼ぶ
- [ ] 既存 worktree の再利用・worktree なしの start では呼ばない
- [ ] `--no-post-start` を足す（unknown flag は従来どおりエラーのまま）
- [ ] `Active ticket paths:` を後に出す順序にする
- [ ] 環境変数 5 つを渡す
- [ ] テストを書く
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
