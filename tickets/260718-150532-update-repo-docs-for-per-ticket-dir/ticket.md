---
priority: 2
base_branch: default
description: "リポジトリ直下のドキュメント群 (README.md / README.ja.md / spec.md / spec.ja.md / DEV.md / CLAUDE.md) と cmd_init post-init echo を per-ticket ディレクトリレイアウト canonical に更新し、レガシー互換言及は各所1箇所に留める。"
created_at: "2026-07-18T15:05:32Z"
started_at: null
closed_at: null
canceled_at: null
---

## 260718-150532-update-repo-docs-for-per-ticket-dir

### Why

前ticket `260717-045235-per-ticket-directory-layout` で ticket.sh 本体・埋め込み help (`show_usage`) ・埋め込み prompt (`cmd_prompt`) ・生成 `tickets/README.md` は per-ticket dir を canonical に更新済みだが、リポジトリ直下のドキュメント (README/spec/DEV/CLAUDE) と `cmd_init` の post-init "Next Steps" echo はレガシー形式 (`tickets/<name>.md` + `-note.md` + `current-ticket.md`) の記述のまま残っている。これらは新規ユーザ・contributor・selfupdate 経由で ticket.sh を取り込んだ agent が最初に読むエントリドキュメントなので、canonical layout が二重定義されている状態は「どっちが正なのか」を毎回推測させ、drift の温床になる。

### What / Acceptance Criteria

- [ ] AC 1 (README.md 更新): "Commands" 表・"Complete Example"・"Design Principles"・"Troubleshooting" 節が per-ticket dir レイアウトを canonical として説明する。`current-ticket/` (dir symlink) と `current-ticket.md` / `current-note.md` (互換 file symlink) の関係が図または箇条書きで示されている。レガシーフラット形式は「Legacy compatibility」相当の見出しで1箇所まとめて言及される。
- [ ] AC 2 (README.ja.md 更新): AC 1 と同じ内容が日本語版でも反映される。
- [ ] AC 3 (spec.md Storage Model 更新): Storage Model 節が per-ticket dir (`tickets/<TICKETNAME>/{ticket.md,note.md,tests/,tmp/}`) を canonical として列挙し、close/cancel はディレクトリごと `done/<TICKETNAME>/` へ git-mv されると記述されている。レガシー形式は Legacy 節1箇所で説明される。
- [ ] AC 4 (spec.ja.md 更新): AC 3 と同じ内容が日本語版でも反映される。
- [ ] AC 5 (DEV.md 更新): start/close/cancel/restore の内部フロー説明が新レイアウト (dir mv + 3 本 symlink) に更新されている。レガシーは補足1箇所で言及。
- [ ] AC 6 (CLAUDE.md — この repo 自身のもの — 更新): "Working with current-ticket" 節が per-ticket dir + 互換 symlink 前提の記述に更新されている (この repo 自体もこの canonical layout に従っていることが読み取れる)。
- [ ] AC 7 (`cmd_init` post-init echo 更新): `init` 実行時の "Next Steps" heredoc 内 (現在は `current-ticket.md` しか触れていない箇所) が per-ticket dir を canonical に書き直され、互換 symlink はレガシー言及として1箇所のみに整理される。ソースは `src/ticket.sh` を編集、`bash build.sh` で `ticket.sh` 再生成。
- [ ] AC 8 (drift 検証): 更新後に `rg -n 'current-ticket\.md|tests/tickets/|tickets/<[^>]+>\.md' README.md README.ja.md spec.md spec.ja.md DEV.md CLAUDE.md` を実行しても、残るヒットは「Legacy compatibility」相当の説明文脈内だけ (canonical 説明の中に混在していない)。
- [ ] AC 9 (テスト): 既存の `bash test/run-all.sh` (241/241) と `bash test/run-all-on-docker.sh` (Ubuntu 222/222 + Alpine 222/222) が全 pass のまま (今回はドキュメント更新 + `cmd_init` の echo テキスト変更のみで、コマンド挙動を変えないため)。
- [ ] AC 10 (`ticket.sh init` の実出力検証): 新しく `init` を実行した際の post-init 出力に per-ticket dir の説明が含まれ、レガシー言及は canonical と混在せず 1 箇所に集約されていることを実行証跡で確認する。

### Architectural Invariants check

- 前ticket が定めた「上流 pdh 共有物として汎用実装を維持する」不変則と矛盾しない (今回は docs / echo 文言のみで実装挙動を変えない)。
- CLAUDE.md の "Do not migrate legacy files" 既定と矛盾しない (ドキュメント上のレガシー言及は削除せず、canonical と混在しない位置に整理するのみ)。
- 「1 ticket = 1 work unit」原則と整合 (前ticketの実装作業とは分離してこのticket内で完結する)。

### 確定判断 (Design Decisions)

- レガシー形式の言及は各ドキュメント内 1 箇所 (見出し「Legacy compatibility」相当) にまとめる。既存ユーザに旧形式チケットの読み方が失われないようにする。
- 図解が必要な箇所 (README の Complete Example・DEV.md の内部フロー) では、per-ticket dir の物理レイアウトと、その上に張られる 3 本 symlink の対応を明示する。
- `cmd_init` の post-init echo は `show_usage` と同じ canonical 記述に揃える (この 2 箇所は近い将来リファクタで統合可能だが、本 ticket では文言統一までに留める)。
- 日本語ドキュメント (README.ja.md / spec.ja.md) は英語版と1:1 対応させる (訳ずれで内容が食い違わないようにする)。
- `cmd_init` の変更は src/ticket.sh のみ編集、`bash build.sh` で `ticket.sh` を再生成、両方を commit する (「Do NOT edit `ticket.sh` in project root directly」の既定に従う)。

### Out-of-scope

- ticket.sh 本体のコマンド挙動変更 (今回はドキュメントと echo テキストのみ)。
- 上流 pdh (github.com/masuidrive/pdh) への PR (別 ticket)。
- レガシーフラット形式チケットの `tickets/*.md` を実際に新形式へ移行する作業。
- `README.md` / `README.ja.md` の他の節 (Installation・License 等 レイアウトと無関係な節) の書き換え。
- `show_usage` と `cmd_init` echo の DRY リファクタリング (統合)。

### Implementation Notes

- 各ドキュメントの更新は Edit ツールで既存 heading 単位で行い、diff を読みやすく保つ。
- CLAUDE.md はこの repo 自体の agent ルールなので、更新後の記述が「自分自身の新レイアウト運用」と整合していることを check する。

### Dependencies

なし (前ticket `260717-045235-per-ticket-directory-layout` は既に main に merge/push 済み)。

---
Work notes: `note.md`
