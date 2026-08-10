# Notes

## 報告の裏取り

issue #2 の内容は自リポで再現した。`ce2c796` (`[260807-145646-speed-up-yaml-parse] …`) の
body が frontmatter 8 行で始まっている。報告者が挙げた `ticket.sh:4062` / `:4073` は
生成後の行番号で、ソース側は `src/ticket.sh:2774` の `local ticket_content=$(cat "$ticket_file")`。

報告者が指摘した「回避手段が無い」も確認した。`close` のオプション・`.ticket-config.yaml`
のどちらにも commit message の書式を触るものは無い。

## 調査中に見つかった 2 件

いずれも同じ数行に同居していたので併せて直した。

### `echo -e` によるバックスラッシュ展開

`:2847` / `:2930` が `echo -e "$commit_msg"` を使っていた。`-e` はチケット本文中の
`\n` `\t` `\\` も展開する。実測:

```
$ msg='subject\n\nbody with printf "a\nb" and a tab \t here'; echo -e "$msg"
subject

body with printf "a
b" and a tab 	 here
```

`-e` が要ったのは組み立て (`:2788`) がリテラルの `\n\n` を使っていたから。`$'\n\n'` に
変えて `-e` を落とした。同ファイルの `:2412`（PR マージ経由の finalize）は元から
`$'\n\n'` + `echo` で正しかったので、そちらに揃った形。

### 複数行 description の subject 混入

`yaml_get "description"` は block scalar をそのまま返す。実測:

```yaml
description: |
  first line of desc
  second line of desc
```
→ `first line of desc\nsecond line of desc\n\n`（末尾に改行 2 つ付き）

これが `[${ticket_name}] ${description}` に入ると subject が 2 行になる。改行をスペースに
畳んで前後の空白を落とす形にした。trim は `${v#"${v%%[![:space:]]*}"}` の慣用句で、
このリポジトリでは `src/ticket.sh:3552` と `:4477` が既に同じ書き方をしている。

**長さの切り詰めはしない。** issue の当初版にあった件は報告者が利用側の問題として
取り下げている。どこで切っても情報が欠け、全文を body 頭に置く形は重複を減らす今回の
趣旨と衝突し、マジックナンバーが増える。git は長い subject を拒否しない。

## 実装

`cat` → `extract_markdown_body`。frontmatter 直後の空行がそのまま残る（実測で先頭が
`\n# Ticket Overview`）ので、先頭の改行を落とすループを足した。body が空のときは
`\n\n` ごと付けないようにして、subject だけのメッセージが末尾に空行を持たないようにした。

## `yaml-sh` のループ内 `local`（無関係）

先の高速化で `local type indent key value rest` を while ループの内側に置いていた。
zsh は同一スコープでの `local` 再宣言のたびにパラメータ一覧を stdout に出す:

```
$ zsh -c 'f() { for i in 1 2 3; do local type indent; type=T$i; indent=$i; done; }; f'
type=T1
indent=1
type=T2
indent=2
```

（最終周は関数を抜けるので出ない。）yaml-sh は README で Bash 3.2+ を対象と明記し
ticket.sh も bash shebang なので実害は無いが、宣言をループ外へ出して消した。
zsh から `source` して `yaml_parse` を呼び、無音になることを確認済み。

## テスト

`test/test-close-commit-message.sh` を新規作成。17 assertion。`run-all.sh` は
`test-*.sh` を glob で拾うので登録作業は不要。

**負のコントロールを取った。** src を旧実装に戻して（`cat` / `echo -e` / 生の
`description`）走らせると 17 中 10 が落ちる:

```
✗ frontmatter comments leaked into the commit message
✗ frontmatter keys leaked into the commit message
✗ unexpected spacing after the subject
✗ backslash-n in the body was expanded
✗ backslash-t in the body was expanded
✗ a doubled backslash in the body was collapsed
✗ the description should be folded onto the subject line
✗ unexpected spacing after a folded subject
✗ an empty body should not add blank lines
✗ frontmatter leaked into a legacy ticket's commit message
```

つまり直した 3 件すべてに、旧実装で落ちるテストが対応している。

カバーした形: frontmatter 除去 / 本文は残る / done 配下のファイルには frontmatter が
残る（情報が失われていないことの確認）/ subject 直後の空行が 1 つ / バックスラッシュ 3 種 /
block scalar description / 本文なし / description なし / 空白のみ description /
レガシー flat レイアウト / frontmatter 無しファイルのフォールバック。

## テスト結果

| | |
|---|---|
| `yaml-sh/test.sh` | 27/27 |
| `test/run-all.sh` | 296/296 |
| `test/run-all-on-docker.sh` Ubuntu 22.04 | 277/277 |
| `test/run-all-on-docker.sh` Alpine | 277/277 |

## 対象外と判断したもの

- `cancel` (`src/ticket.sh:3197`) — `commit_msg` に本文を埋め込んでいない
- PR マージ経由の finalize (`:2410`) — description のみ。`$'\n\n'` + `echo` で元から正しい
- 設定キーの追加 — 報告者が「既定の挙動として」と明示。直前の start の push 廃止でも
  設定を足していない
