---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "close の commit message から YAML frontmatter を除き、echo -e による本文破壊と複数行 description による subject 混入も直す"
created_at: "2026-08-10T09:40:07Z"
started_at: 2026-08-10T09:40:49Z # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GitHub issue [#2](https://github.com/masuidrive/ticket.sh/issues/2) への対応。

`cmd_close` が生成する squash commit の message は、body に ticket ファイルの
**全文**を埋め込んでいる (`src/ticket.sh:2774` の `cat "$ticket_file"`)。その結果、
`git show` の body は必ず YAML frontmatter の 8〜9 行で始まる。

```
---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "…"
created_at: "2026-08-08T06:57:59Z"
started_at: 2026-08-08T09:12:32Z # Do not modify manually
closed_at: 2026-08-09T00:37:11Z # Do not modify manually
canceled_at: null # Do not modify manually
---
```

自リポの `ce2c796` でも再現する。`# Do not modify manually` などは ticket ファイルの
**編集者**に向けて `ticket.sh` が書いたコメントであって、履歴の読み手向けではない。
`git blame` から辿った人が最初に読む 8 行が機械向けメタデータになる。close のたびに
機械的に再生産されるため蓄積する。frontmatter は `ticket.sh` の生成物なので、
利用側の書き方では消せない。

## 方針

**本文の全文埋め込みという設計自体は維持する。** `tickets/done/` を開かずに
`git blame` から Why に届くのはこの設計の利点で、報告者もそこに依存して運用している。
変えるのは frontmatter を除く 1 点のみ。

**設定キーは追加しない。** 報告者も「設定を書かないと frontmatter が入ったままに
なる形ではなく、既定の挙動として」と明示している。直前の `start` の push 廃止でも
設定を足さずに既定を変えており、方針が揃う。

**情報は失われない。** frontmatter を message から落としても、同じ commit の tree に
`tickets/done/<name>/ticket.md` が frontmatter 込みで入っている。加えて `closed_at` は
commit の author date と、`description` は subject と重複している。

## 併せて直す 3 点

調査中に見つかった、同じ行まわりの問題。

### 2. `echo -e` が ticket 本文中のバックスラッシュを解釈する

`src/ticket.sh:2847` と `:2930` が `echo -e "$commit_msg"` を使っている。`-e` は本文中の
`\n` `\t` `\\` も解釈するため、コードブロックにエスケープ列を含む ticket を close すると
commit message が壊れる。

```
body with printf "a\nb" and a tab \t here
   ↓ echo -e
body with printf "a
b" and a tab 	 here
```

`-e` が要るのは組み立て (`:2788`) がリテラルの `\n\n` を使っているからで、同ファイルの
`:2412` は既に `$'\n\n'` を使い `-e` を付けていない。そちらに揃えれば `-e` を外せる。

### 3. 複数行 description が subject に混入する

`description` が YAML block scalar のとき、`yaml_get "description"` は改行入り＋末尾改行
付きの文字列を返す（実測済み）。

```yaml
description: |
  first line of desc
  second line of desc
```
→ `first line of desc\nsecond line of desc\n\n`

これが `[${ticket_name}] ${description}` に入ると subject が黙って 2 行になり、`%s` は
2 行を連結して返し、subject と body の間に余計な空行が入る。YAML として正当な書き方なので
利用側では回避できない。subject 用に改行をスペースへ畳み、末尾空白を落とす。

**description の長さは切り詰めない。** issue の当初版にあった「subject が数百字になる」件は
報告者自身が利用側の問題として取り下げている。どこで切っても情報が欠け（日本語は語の途中で
切れる）、全文を body 頭に置く形は重複を減らす今回の趣旨と衝突し、マジックナンバーが増える。
git は長い subject を拒否しない。

### 4. `yaml-sh.sh` のループ内 `local`（無関係のついで）

先の高速化で `yaml-sh/yaml-sh.sh:331` の `local type indent key value rest` を while ループの
**内側**に置いた。zsh は同一スコープでの `local` 再宣言のたびにパラメータ一覧を stdout へ
出すため、zsh から `source` すると毎周ゴミが出る。yaml-sh は README で Bash 3.2+ を対象と
明記し ticket.sh も bash shebang なので実害はないが、宣言をループ外へ出すだけで消える。

## 影響範囲

- `cancel` と PR マージ経由の finalize (`:2410`) は本文を埋め込んでいないので対象外
- `spec.md:701` / `spec.ja.md:694` が `git commit -m "[ticket-name] description\n\n$(cat ticket-file)"` と
  書いているので更新が要る
- `extract_markdown_body` (`lib/yaml-frontmatter.sh:147`) は frontmatter の無いファイルには
  全文を返すので、レガシー・手書き ticket の挙動は壊れない
- frontmatter 直後の空行がそのまま残る（`\n# Ticket Overview`）ため、subject との間が
  3 連改行になる。先頭の空行を落とす必要がある

## Tasks

- [ ] `src/ticket.sh:2774` の `cat "$ticket_file"` を `extract_markdown_body` に差し替え、body 先頭の空行を落とす
- [ ] body が空の ticket で message が余計な空行で終わらないことを確認
- [ ] `:2788` の組み立てを `$'\n\n'` に変え、`:2847` / `:2930` の `echo -e` から `-e` を外す
- [ ] subject 用に description の改行をスペースへ正規化し、末尾空白を落とす
- [ ] `yaml-sh/yaml-sh.sh` の `local` 宣言を while ループ外へ移す
- [ ] テストを追加 — frontmatter が body に出ないこと / バックスラッシュを含む本文が保たれること / 複数行 description が 1 行 subject になること / frontmatter 無しファイルのフォールバック / レガシー flat ticket
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md（`spec.md:701` / `spec.ja.md:694` の commit message 例）
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
- [ ] issue #2 に対応内容を返信して close
