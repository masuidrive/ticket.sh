---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "new が note.md 以外の追加ファイル（progress.md 等）も config のテンプレートから作れるようにする"
created_at: "2026-09-14T09:57:53Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

`new` が生成する ticket 付属ファイルは `note.md`（`note_content`）だけで固定されている。PDH（masuidrive/pdh）は 2026-09-14 から ticket dir に **`progress.md`（追記だけの経緯。note は現在値だけにする）** を置く運用にしたが、ticket.sh が作らないので agent が作る規則になっている。実測（pdh-ghbot-smoke、claude）では散文の規則 3 か所に書いても agent は作らず、runner 側の hook で補うことになった。**「無ければ作る」を毎回 agent に頼るのではなく、`new` が note と同じ手で作るのが筋。**

progress.md 専用のキーにはしない。**任意のファイル名と内容の組を config に列挙できる形**にして、progress.md はその 1 例にする。

## 設計判断（提案）

1. config に `ticket_files:` を足す。要素は `path`（ticket dir 相対）と `content`（`note_content` と同じ置換 `$$TICKET_NAME$$` / `$$NOTE_PATH$$` を使えるテンプレート）。
   ```yaml
   ticket_files:
     - path: progress.md
       content: |
         # Progress: $$TICKET_NAME$$
   ```
2. `note_content` は残す（後方互換）。`ticket_files` に `note.md` を書いた場合は `note_content` より優先する。
3. `new` は `ticket_files` の各ファイルを作る。既存ファイルがあれば上書きしない（`restore` / 再実行で消さない）。
4. `start` / `restore` の `Active ticket paths:` に、作ったファイルの実パスを 1 行ずつ足す（`note:` と同じ形。agent が path を推測しなくて済む）。
5. flat 形式（旧レイアウト）では作らない。per-ticket dir のときだけ。
6. `close` / `cancel` は dir ごと移すので変更なし。

## 実装メモ

- `src/ticket.sh` の `note_content` を読む箇所（`yaml_get "note_content"`、置換、`Create note file`）の隣に、リストを回すループを足す。yaml-sh のリストは `yaml_list_size` + `yaml_get <prefix>.<N>.path` で読める（`require_checklist_groups` の実装を参照。クォート剥がしも同じ）。
- 複数行 `content` が yaml-sh で読めるかを先に確かめる（`note_content` と同じ `|` ブロックなので読めるはず。要素の中の `|` は要確認）。

## What / Acceptance Criteria

- [ ] `ticket_files` に `path` と `content` を列挙すると、`new` が ticket dir にそのファイルを作る（`$$TICKET_NAME$$` / `$$NOTE_PATH$$` が置換される）
- [ ] `ticket_files` 未定義なら現行と同一の挙動
- [ ] 既に存在するファイルは上書きしない
- [ ] `start` / `restore` の出力に、作ったファイルの実パスが出る
- [ ] flat 形式の ticket では作らない
- [ ] spec.md / spec.ja.md / README に `ticket_files` の説明が入る

## Tasks

- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
