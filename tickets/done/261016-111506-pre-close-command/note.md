# Work Notes for 261016-111506-pre-close-command

## 何を足したか

config に `pre_close_command:`（shell 1 行）。`close` が何かを commit する直前
——clean-check と checklist / append-only の gate の後、squash-merge の前——に
repo root で走らせ、exit が 0 以外なら close を中止する。

- `lib/utils.sh` に `pre_close_run()`。コマンドの stdout / stderr は捕まえず、
  そのまま通す。整形して包み直したところで、検査が何を見つけたかを知っているのは
  導入先の側なので、読む層が 1 枚増えるだけになる。
- `src/ticket.sh`: `DEFAULT_PRE_CLOSE_COMMAND=""`、`cmd_init` の config template、
  help、`cmd_close` と `cmd_close_no_merge` の 2 箇所の gate。

## 判断したこと

### subshell で `set -euo pipefail` を外して走らせる

値は導入先が書いた shell 1 行で、判定するのはその行自身の exit status である。
`set -e` を継いだままにすると、ごく普通の `grep -q x f && echo ok` が「grep が
何も見つけなかった」だけで close を落とす。`set -u` も同様に、導入先の一行が
未定義変数を踏んだ瞬間に意味が変わる。subshell なのは、`cd` する検査や変数を
export する検査が、その後に続く close を変えられないようにするためでもある。
テスト section 10 がこの 2 つを固定している。

### `close --no-merge` でも走らせる（ただし base branch 以外でだけ）

issue は `--no-merge` に触れていないが、`--no-merge` は close である。しかも
`require_checklist` / `append_only_files` の gate は既に「ticket の base branch
以外で走っているときだけ効く」という形で `--no-merge` に入っている（#10）。
`pre_close_command` だけ入れないと、「`--force` でも抜けられない」と宣言した
gate が、close を呼ぶ場所を `--no-merge` に変えるだけで迂回できることになる。
同じ条件・同じ場所に置いた。base branch 上では走らせない理由も同じで、そこでは
merge が済んでいるため、拒否しても ticket が `done/` の外に取り残されるだけ。

### 環境変数は issue の 3 つに 2 つ足した

issue は `TICKET_NAME` / `TICKET_DIR` / `TICKET_BASE_BRANCH` を「例」として
挙げ、目的を「検査が branch 名やパスを推測しなくて済む」と書いている。その目的に
対して 3 つでは足りなかった:

- `TICKET_DIR` は legacy の flat layout（`tickets/<name>.md`）では存在しない。
  空を渡すしかなく、そのとき「ticket はどこか」に答えられる変数が無くなる。
  → `TICKET_FILE` を足した。どちらの layout でも ticket の `.md` を指す。
- 「branch 名」は複数ある。base だけ渡して feature branch を推測させるのは、
  推測させない目的と合わない。→ `TICKET_BRANCH` を足した。

`TICKET_BASE_BRANCH` は ticket が `base_branch:` を持つ場合それを渡す。
`cmd_close` の中で `default_branch` が ticket の `base_branch` で上書きされた
**後**に読んでいるので、retarget された ticket には実際に merge される先が渡る
（テスト section 5 の最後がこれ）。

## 検証

- `bash test/run-all.sh` → 679 / 679
- `bash test/run-all-on-docker.sh`（Alpine）→ 671 / 671
- 新規 `test/test-pre-close-command.sh` は 41 assertions / 10 section

テストで特に固定したのは、`if` 一本で済む「落ちたら止まる」ではなく、その周りの
約束の方: 導入先の出力がそのまま見えること、`--force` で抜けられないこと、
`--dry-run` で close の前に分かること、`cancel` では走らないこと、環境変数が
名乗っている値を実際に持っていること。どれも他のテストが気づかないまま
「整理」できてしまう行である。

## 気づいたが直していないこと

`cmd_close` にも `/tmp/ticket_yaml.yml` への直書きが残っている（src/ticket.sh の
ticket status 読み取り）。#16 で `cmd_start` 側は `ticket_frontmatter_text()` に
置き換えたが、close 側は手付かず。並走する 2 つの close が踏み合う形になるので、
別 issue にする価値がある。このチケットの範囲外なので触っていない。
