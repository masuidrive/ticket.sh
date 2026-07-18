---
priority: 2
base_branch: default
description: "cmd_init が <tickets_dir>/.gitignore を生成して per-ticket ディレクトリの tmp/ を ignore する。start/restore は tickets/<TICKETNAME>/tmp/ を自動作成する。"
created_at: "2026-07-18T15:44:50Z"
started_at: null
closed_at: null
canceled_at: null
---

## 260718-154450-gitignore-tmp-in-ticket-dirs

### Why

per-ticket ディレクトリ配下の `tmp/` は「ticket-local な一時 helper 置き場」として設計されており (ticket-local test の実行 helper、agent が試行錯誤中に作る一時 script、fixture 等)、コミット対象外にしたい。現状は上位の `.gitignore` に `tmp/` (repo root 直下 only) が入っているだけで、`tickets/<TICKETNAME>/tmp/` は誤コミットされうる。

同じく、tmp/ は「作った時に存在する」のが自然なので (agent がそこにファイルを置こうとしたときに mkdir し忘れる摩擦を無くす)、`start` / `restore` の時点で作成しておく。ドキュメント (`README.md`, `spec.md`, `cmd_prompt`, `Active ticket paths:` 出力) で「on demand」と説明していた挙動を、「常に存在する」に格上げする。

### What / Acceptance Criteria

- [x] AC 1 (init: tickets/.gitignore 生成): `./ticket.sh init` を実行すると `<tickets_dir>/.gitignore` が生成され、以下の2行を含む:
  ```
  */tmp/
  done/*/tmp/
  ```
  既に `<tickets_dir>/.gitignore` が存在する場合は、この 2 行のうち欠けているものだけ追記する (既存内容は破壊しない、重複しない)。
- [x] AC 2 (init: 冪等性): `./ticket.sh init` を 2 回連続で実行しても `<tickets_dir>/.gitignore` は 1 部ずつ、同じ 2 行が 1 回だけ含まれる (重複追記されない)。既存の他行も温存される。
- [x] AC 3 (tmp/ が実際に ignore される): 新規ticket 作成 → `tickets/<TICKETNAME>/tmp/foo.txt` を書き込み → `git status --porcelain` に `tmp/foo.txt` が現れない (repo 直下の `.gitignore` の変更なしで `<tickets_dir>/.gitignore` だけで効く)。done 側 `tickets/done/<TICKETNAME>/tmp/foo.txt` も同様に ignore される。
- [x] AC 4 (start: tmp/ 自動作成 — 新形式): `./ticket.sh start <TICKETNAME>` を新形式チケットに対して実行すると `tickets/<TICKETNAME>/tmp/` ディレクトリが作成される (worktree モードでは worktree 側にも作られる)。存在しても失敗しない (`mkdir -p` 相当)。
- [x] AC 5 (start: レガシー形式は tmp/ を作らない): レガシーフラット形式チケットに `start` しても、それに対応する per-ticket ディレクトリは存在しないので `tmp/` は作成されない (副作用なし)。
- [x] AC 6 (restore: tmp/ 自動作成 — 新形式): `./ticket.sh restore` を新形式チケットの feature branch で実行すると `tickets/<TICKETNAME>/tmp/` が存在しなければ作成される。
- [x] AC 7 (Active ticket paths 出力の描写と一致): `start` / `restore` の `Active ticket paths:` 出力で `tmp_dir:` が「作成済み」を暗示する記述になる (`(ticket-local temp helpers)` の一文で足りるが、"created on demand" 相当の表現があれば削除)。docs (`show_usage`, `cmd_prompt`, README.md, README.ja.md, spec.md, spec.ja.md, CLAUDE.md, tickets/README.md, cmd_init post-init echo) の `tmp/` 記述も同様に「常に存在する」表現に更新する。
- [x] AC 8 (テスト): 既存 `bash test/run-all.sh` (現在 241/241) と `bash test/run-all-on-docker.sh` (Ubuntu 222/222 + Alpine 222/222) が全 pass のまま。
- [x] AC 9 (回帰テスト追加): `test/test-per-ticket-dir.sh` に 4 assertion を追加:
  1. `init` 実行後 `tickets/.gitignore` が存在し、`*/tmp/` と `done/*/tmp/` が両方含まれる
  2. `init` 冪等性: 2 回目実行で `tickets/.gitignore` の該当 2 行がそれぞれ 1 回だけ
  3. `start` 後 `tickets/<TICKETNAME>/tmp/` が存在する
  4. `tickets/<TICKETNAME>/tmp/foo.txt` が `git status` に現れない (ignore が効いている)

### Architectural Invariants check

- 上流 pdh 共有物として汎用実装を維持する不変則と矛盾しない (追加は generic な `.gitignore` 生成 + `mkdir -p tmp` のみ、Hangar 固有・repo 固有の判断を含まない)。
- 「Do not migrate legacy files」既定と矛盾しない (レガシーチケットは触らない — `tickets/.gitignore` は per-ticket dir 配下の `tmp/` のみを対象にし、レガシーの flat `<TICKETNAME>.md` には影響しない)。
- 「1 ticket = 1 work unit」原則と整合。

### 確定判断 (Design Decisions)

- `<tickets_dir>/.gitignore` の生成方針は repo 直下 `.gitignore` と同じ「未存在なら新規作成、存在するなら欠けている行だけ追記」パターン (既存 `cmd_init` の gitignore 処理と統一)。
- 2 行の内容は `*/tmp/` と `done/*/tmp/` の 2 パターンで、それぞれ open ticket と done ticket 配下の tmp を ignore する。1 行 (`**/tmp/`) にまとめることも可能だが、user 指定通り 2 行に分ける (何が ignore されるか明示的に読める)。
- `tests/` は今回 auto-create しない (user 指示は `tmp/` のみ、tests/ は ticket が必要としたら作られる想定)。
- `mkdir -p` を start と restore それぞれの新形式コードパス末尾で実行する。既存の `create_current_ticket_symlinks` helper には入れない (helper は symlink を張るだけの責務を保つ)。
- worktree モードでは worktree 内の per-ticket dir に対して mkdir する (start-worktree code path)。
- ドキュメント記述は「on demand / created on demand」→「per-ticket temp helpers directory」等、常在を前提とした表現に統一する。

### Out-of-scope

- `tests/` を auto-create する変更 (user 指示外)。
- `tmp/` の中身をチケット close 時に自動削除する仕組み (`git mv` されればそのまま `done/<name>/tmp/` に移動して残る、ignore されているので commit されないだけ)。
- 上流 pdh へ PR。
- レガシーフラット形式チケットへの `tmp/` 相当機構の追加。
- `tickets_dir` を config で変えている環境で、既存の repo-root `.gitignore` の `tmp` 行と衝突しないかの検証 (repo root の `tmp` は先頭にあり `tickets_dir` 配下ではないので衝突しない、docs のみで注意喚起は不要)。

### Implementation Notes

- `src/ticket.sh` の `cmd_init` に `<tickets_dir>/.gitignore` 生成ブロックを追加 (既存の `.gitignore` 処理と隣接して配置)。
- `src/ticket.sh` の start / restore の各コードパスで、layout が "new" のときに `mkdir -p "${tickets_dir}/${ticket_name}/tmp"` を実行。worktree モードでは `mkdir -p "${wt_path}/${tickets_dir}/${ticket_name}/tmp"`。
- 回帰テストは `test/test-per-ticket-dir.sh` に既存 assertion と近い位置で追加。
- ドキュメント表現統一は同一 commit にまとめる。

### Dependencies

なし。

---
Work notes: `note.md`
