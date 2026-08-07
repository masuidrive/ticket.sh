# Work Notes for 260807-141649-list-sees-feature-branch

## 変更内容

`cmd_list` の収集ループで、`todo` と判定されたチケットについて
`{branch_prefix}<ticket-name>` を確認し、そちらの ticket ファイルに `started_at` があれば
`doing` として扱う。表示に `started_at_only_on: <branch>` を足して、時刻がそのブランチにしか
無いこと（＝base branch 側のファイルはまだ `null`）を示す。

追加ヘルパー（`lib/utils.sh`）:

- `ticket_name_from_path <path>` — 新旧レイアウトの両方からチケット名を取り出す。
  表示ループに同じ処理が直書きされていたので、そちらも置き換えた。
- `started_at_on_branch <branch> <path>` — `git show <branch>:<path>` の出力から
  frontmatter 内の `started_at` だけを awk で抜く。チェックアウトは伴わない。
  本文に `started_at:` と書かれていても拾わないよう、`---` の対で囲まれた最初のブロックに
  限定している。

## 性能

100 チケット（全件 todo = fallback が最も効くケース）で計測:

| | 実時間 |
|---|---|
| 変更前 | 6.89 s |
| 素直な実装（チケットごとに `git show-ref`） | 8.22 s |
| ref を一括取得 | 6.94 s |

チケットごとに `git show-ref` を叩くと 100 プロセス増えて +1.3 秒だった。
`git for-each-ref --format='%(refname:short)' "refs/heads/<prefix>*"` で一度だけ取得し、
存在確認は文字列マッチに変えて、差を 0.05 秒（誤差）まで落とした。

`ticket_name_from_path` も `basename` の呼び出しをパラメータ展開に置き換えてある。

**別件（今回は手を付けていない）**: そもそも `list` は 100 チケットで 6.9 秒かかる。
これは変更前からで、チケットごとに frontmatter を一時ファイルへ書き出して `yaml_parse` を
呼ぶ作りが原因と思われる。今回のスコープ外。

## ついでに直したもの

表示ループの worktree 表示が `yaml_get "branch_prefix"` を呼んでいたが、その時点では
`yaml_get` の状態が最後に読んだ**チケットの frontmatter**に置き換わっているため、
config の `branch_prefix` は決して読まれず常に既定値 `feature/` にフォールバックしていた。
`branch_prefix` をカスタマイズした repo では worktree 行が出ない不具合。
config を parse した直後に読むよう移動した。

## テスト

`test/test-start-base-sync.sh` に 6 件追加（26 → 32）:

- ff スキップ後に `list` が `doing` を返す
- `started_at_only_on: <branch>` が出る
- その状態で base branch の ticket ファイルは実際に `null` のまま（印の前提の確認）
- `--status doing` が feature branch 由来のチケットを含む
- 一度も start していないチケットは `todo` のまま
- レガシー flat レイアウトでも fallback が効く

結果: 当該スイート 32/32、`test/run-all.sh` 279/279、
`test/run-all-on-docker.sh` は Ubuntu / Alpine とも 260/260。
