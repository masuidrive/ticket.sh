# Work Notes for 260718-150532-update-repo-docs-for-per-ticket-dir

## Scope

Docs-only follow-up for the per-ticket-directory layout that landed in
`260717-045235-per-ticket-directory-layout`. The runtime behavior of
ticket.sh commands is not changed here — only doc strings, the `cmd_init`
"Next Steps" heredoc, and the top-level README/spec/DEV/CLAUDE docs.

## Files touched

- `README.md` — Key Features / Ticket Layout (new section) / Commands table / Success message templates / Automatic Organization / Working Notes / Check Command Diagnostics
- `README.ja.md` — 主な機能 / チケットのレイアウト (新規節) / コマンド / success message テンプレ / 自動整理 / 作業ノート
- `spec.md` — 🚀 Ticket Management → Per-Ticket Directory Layout (renamed & rewritten) / Branch Integration / 📖 Usage (start/restore/close/cancel) / 📁 Directory Structure / init flow / start flow / cancel flow / USAGE block / WORKFLOW / TROUBLESHOOTING
- `spec.ja.md` — 同上、日本語版
- `DEV.md` — restore の 1-line 定義 / `create_ticket()` / `start_ticket()` / `close_ticket()` / `cancel_ticket()` の内部フロー説明
- `CLAUDE.md` — この repo 自身の agent ルール。Working with current-ticket 節 + Ticket Layout 節を per-ticket dir + 3 symlink 前提に全面書き直し
- `src/ticket.sh` — `cmd_init` の post-init "Next Steps" heredoc を per-ticket dir canonical に統一。`show_usage` と表現を揃える
- `ticket.sh` — 上を `bash build.sh` で再生成

## AC 10 evidence — `./ticket.sh init` post-init 出力（新形式で書かれている）

```
## Ticket layout

Each ticket is a per-ticket directory:

    tickets/<TICKETNAME>/
      ticket.md   # ticket body (YAML frontmatter + Markdown)
      note.md     # working notes / log
      tests/      # ticket-local tests (created on demand)
      tmp/        # ticket-local temp helpers (created on demand)

While a ticket is active, three symlinks in the repo root point at it:

- `current-ticket/` -> the per-ticket directory (reach as `current-ticket/ticket.md`, `current-ticket/note.md`, etc.)
- `current-ticket.md` -> the ticket body (compat file symlink)
- `current-note.md` -> the note file (compat file symlink)

*Legacy compatibility*: flat-file tickets from earlier ticket.sh versions
(`tickets/<TICKETNAME>.md` + `tickets/<TICKETNAME>-note.md`) still work with
every command; they are never auto-migrated.

...
```

（完全出力は本 note を書いた時点で実行して確認済み。post-init heredoc の
すべての行が per-ticket dir + 3 symlink を canonical として説明しており、
レガシー言及は 1 箇所 "*Legacy compatibility*: ..." のみに集約されている。）

## AC 8 evidence — drift 検証

`rg -n 'current-ticket\.md|current-note\.md|-note\.md|tickets/\*\.md|tickets/<[^>]+>\.md'`
の残りヒットはいずれか:
  - canonical な 3 symlink の説明文脈（"compat file symlink"／"symlink 群 ... を再構築" 等）
  - レガシー互換の説明（"Legacy compatibility" 節、"レガシーフラット形式" 節）
  - ticket.sh がまだ emit する実文字列を documenting しているエラーメッセージブロック（`grep 'current-ticket.md missing'` 等）

canonical 説明の中にレガシーだけを前提とする記述は残っていない。

## 判断ログ

- `show_usage` と `cmd_init` echo の統合リファクタは out-of-scope とし、
  本 ticket では文言の一致にとどめる（DRY 化は近い将来の別 ticket で）。
- README 内の config example にある `start_success_message` /
  `close_success_message` テンプレは、`current-ticket.md` (compat symlink)
  への言及を `current-ticket/ticket.md` に更新（本体もそう扱えるし、
  新規ユーザには canonical パスの方を見せたい）。
- error message ブロック内の "current-ticket.md missing" 等は、
  ticket.sh が実際に emit する文字列を describe しているので、
  文言そのままで残す（実装との drift 防止）。
