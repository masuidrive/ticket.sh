# Work Notes for 260914-142717-start-on-own-branch

## 再現（gh #9 の fixture どおり）

```
git checkout -b agent/issue-77
./ticket.sh new issue-77 --branch agent/issue-77 && git add tickets && git commit -m ticket
./ticket.sh start <ticket-name>
→ Warning: Currently on branch 'agent/issue-77' with no uncommitted changes.
  Creating new feature branch from 'main' branch instead.
  Switching to 'main' branch...
  Error: Ticket not found
```

`cmd_start` の順序が原因。ticket ファイルの存在確認（`if [[ ! -f "$ticket_file" ]]`）
より**前**に base branch へ checkout する分岐があり、ticket が override branch 上に
しか無いとそこで唯一の copy から離れてしまう。

`restore` / `check` / `close` が #8 の実装のまま通るのは、あれらが base branch へ
切り替えないから。`start` だけが取り残されていた。

## 実装

### `record_start_on_base` に 10 番目の引数 `skip_base_ff`

stage → commit までは共通で、`advance_branch_ff` の手前で分岐する。base に ticket の
copy が無い以上 fast-forward する対象が無いので、理由を 1 行出して return する。
`${10:-false}` なので既存の 9 引数呼び出しは不変。

### `cmd_start` に `on_own_branch`

`current_branch` を取った直後に判定し、3 条件が揃ったときだけ true:

1. 現在の branch が ticket の `branch:` と一致する
2. ticket ファイルが作業ツリーに存在する
3. base branch にその ticket が無い（`git cat-file -e "<base>:<path>"` が失敗）

3 つとも必要だった理由:

- 1 が無いと、あらゆる feature branch から `start` が base に戻れなくなる
- 2 が無いと、守る対象が無いのに経路だけ変わる
- 3 が無いと、両方の branch にある ticket が、どちらから見ても `doing` と読めるように
  している fast-forward を失う

worktree モードは除外。そもそも cwd の HEAD を触らないので、守る必要が無い。

使う箇所は 2 つ:

- branch 切り替えの分岐に `elif [[ "$on_own_branch" == "true" ]]` を足し、
  base へ checkout せず `check_clean_working_dir` だけ通す
- `branch_name` 決定の直後に専用経路を置き、stamp → commit → symlink → paths → return

専用経路が要る理由: そのまま落とすと「branch が既に存在する → resume」経路に入り、
resume は `started_at` を入れない。結果 ticket が永久に `todo` のままになり、bot が
`started_at` を手で書く運用に戻ってしまう——`start` を持つ意味が無くなる。

2 回目の `start` は再 stamp せず resume する（`started_at` は作業を始めた時刻であり、
2 回目の start は中断したセッションが作業リンクを取り戻す手段）。

## 意図的に変えなかったこと

**branch が先に存在し、かつ ticket が base にもある場合は、従来どおり resume（stamp しない）。**

`on_own_branch` 経路は branch が既にあっても stamp するので、ここだけ挙動が分かれる。
これは意図的:

- own-branch では branch の存在が偶発的（bot が作っただけで ticket.sh は start していない）で、
  stamp しなければ ticket が `todo` から出られない
- base に ticket がある場合は通常経路（base から branch を作る）が使えるし、
  「既存 branch は resume」は #8 以前からの長年の挙動で、手で `feature/<name>` を
  作った場合も同じ

テスト section 9 の最初の fixture でこれを踏んで assertion を 1 つ書き直した
（branch を先に作ると resume 経路に入るので、通常経路の比較には branch を先に作らない）。

## テスト

`test/test-branch-override.sh` に section 8 / 9 を追加（全体で 45 assertion）:

- 8: own-branch 経路（fixture、start 成功、branch 維持、stamp、commit、ff skip の説明、
  base 不変、symlink、paths、2 回目は resume、再 stamp しない、close まで通る）
- 9: 通常経路が変わっていないこと（base に ticket がある場合の ff、無関係な branch からの start）

local 468/468。

## テストが掘り当てた既存バグ: `start` が git の警告を「未コミット変更」と読む

section 9 に足した「無関係な branch から start すると、その branch を離れて
ticket の branch に着く」が **Docker の Ubuntu / Alpine 両方で落ちた**（macOS では通る）。
フレークではなく決定的。

原因は `cmd_start` の

```sh
if ! git_status_output=$(git status --porcelain 2>&1); then
```

`2>&1` で **stderr を porcelain の出力に畳み込んでいた**。git が警告を出す環境
（CI コンテナでは `~/.config/git/ignore` が読めず
`warning: unable to access '/root/.config/git/ignore': Permission denied` が毎回出る）
では、tree がクリーンでも `$git_status_output` が非空になり、

```
Error: Uncommitted changes on feature branch
You are on feature branch 'some/unrelated' with uncommitted changes.
```

と言って停止する。既に commit 済みのファイルを commit しろと言う形になる。

#8 / #9 由来ではなく**元からあったバグ**。これまで踏まれなかったのは、
「警告の出る環境で feature branch から start する」経路を通るテストが無かったため。
`--porcelain` を使う他の 4 箇所はすべて `2>/dev/null` で、ここだけが `2>&1` だった。

修正は stderr を捨てるだけ（exit status の判定は従来どおり）。

回帰テストは section 9 に追加。`core.excludesFile` を mode 000 のディレクトリ内に
向けて git に warning を出させ、その状態で start が branch を移れることを見る。
root 実行では mode 000 が効かないので、`git status --porcelain 2>&1 >/dev/null` が
実際に非空かを先に確かめ、警告を作れない環境では skip する。

CLAUDE.md は「既存コードのエラーは別チケットを切って現タスクの後に対応」としているが、
これは現チケットのテストを塞いでいて後回しにできないため、本チケット内で直した。

### 回帰テストの作り方を 2 回間違えた

**1 回目: mode 000 のディレクトリに `core.excludesFile` を向ける。**
macOS では warning + exit 0 になるが、**Linux では git が hard error を返す**
（`Error: Failed to check git status`）。「読めないパス」に対する挙動が build で
違うので、警告を作る手段として使えない。最初のバグと同じ「macOS では通り
Docker では落ちる」を、今度はテスト側でやってしまった形。

**2 回目: PATH に git の shim を置いたが、shim を repo の中に作った。**
`?? shim/` で tree が本当に dirty になり、テストは「正しい理由で」落ちていた。
`start` の判定は正しく、私の fixture が壊れていた。

**最終形**: shim は `TEST_DIR`（repo の外）に置き、引数に `status` を含む呼び出しの
ときだけ stderr に警告を出して実 git に exec する。加えて

- shim が「警告を出しつつ exit 0 する」ことを fixture として先に assert する
- 修正を一時的に戻してテストが落ちることを確認した（落ちる → 直す → 通る、を実測）

shim を `status` だけに限ったのは、全 git 呼び出しに警告を出すと start の他の
`$(git ...)` も巻き込んで、このテストが 1 行のバグ以外の理由でも落ちるようになるため。
