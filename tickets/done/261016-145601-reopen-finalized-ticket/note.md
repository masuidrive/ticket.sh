# 作業ログ: reopen と close --no-merge の抜け道（GH #22）

## 何が壊れていたか

確認した事実 2 点（実装前に読んで確かめた）:

- `cmd_start` は `tickets/<name>/ticket.md` だけを見る。`done/` にある ticket では
  `Ticket not found`（rc=1）で、戻す手段が無い
- `cmd_close_no_merge` の «Idempotent: already finalized» が gate 群より手前にあって
  `return 0`。done にある ticket への `close --no-merge` は checklist / append_only /
  `pre_close_command` を 1 つも走らせずに成功を返していた

2 つ目が穴の本体。#18 で「`--force` でも抜けられない gate」と宣言したのに、**先に finalize
して後から直せば**丸ごと飛ぶ。しかも何も出力しない。

## 設計判断

### 冪等な 0 を全部やめるのではなく、「branch が動いていない間だけ」にした

retry する bot が retry したことで罰を受けてはいけないので、0 を返す道は残す必要がある。
分けた基準は「gate が効く場所かどうか」＝既存の `_gated` と同じ条件:

- base branch 上（または ticket 自身の `base_branch` 上）→ 従来どおり 0。そこでは merge が
  済んでいて gate は設計上飛ばしており（設計ノート 22）、拒否しても ticket が `done/` の外に
  取り残されるだけ。**main がどれだけ進んでいても 0** にしたのはここが理由で、「finalize 後の
  commit 数」で一律に判定すると、他の ticket の commit が載った main 上での retry が
  エラーになってしまう
- それ以外で finalize 後に commit が無い → 0
- それ以外で commit が増えている → 1（finalize の commit・増えた数・`reopen` を名指し）

### 基準 commit は `--diff-filter=A`（issue の提案 4 から変えた点）

issue は「移した commit の後に commit が増えていなければ」と書いていたが、`done/<name>` を
触った**最新** commit を基準にすると、修正 commit が note.md も直していた場合（作業しながら
note を書く運用なら普通に起きる）その commit 自身が基準になって「増えていない」と読まれ、
また検査が飛ぶ。穴を、記録を残す人に対してだけ開け直すことになる。

`git log --diff-filter=A -1 -- <done path>` で「その path を追加した commit」を取る。
rename 検出が入っていても、pathspec で片側しか見ていないので A で一致する（scratch repo で
`--no-renames` / `AR` / 既定の 3 通りを確認した）。テスト 6.3 がこの区別を固定している。

基準 commit が見つからない場合（移動が commit されていない）も 1 にした。測る基準点が無い
ときに通すのは、まさに今直している挙動だから。

### reopen は commit に pathspec を使う

修正を求められた直後は、まさに誰かが手を付け始めている瞬間。`git add` + 素の `git commit`
だと tree の編集を巻き込む。`git commit -- <ticket の path>` にすると、rename も
`closed_at` の編集も入り、他は入らない（scratch repo で確認: unrelated な staged file は
残った）。副作用として clean-tree チェックが不要になる。

### reopen が走らせないもの

- `pre_close_command`: 戻すことは「終わった」と主張しない。ここで close の検査が通ったら、
  言っている内容と逆の意味になる
- `post_start_command`: 整える対象の worktree は、今立っているその worktree

### 拒否する条件

base branch 上（merge 済み＝ファイルを戻しても判断は戻らない）／ticket 自身の branch 以外
（2 回目の close が判定すべき commit がそこに無い）／`done/` に無い／cancel 済み（`cancel` は
「やらない」と言った）／作業中の場所が埋まっている（唯一データを失い得る条件）／名前なし・
flag の打ち間違い。

## 実装

- `src/ticket.sh`: `cmd_reopen()` 新規、`main()` の dispatch、`show_usage()`、
  `cmd_close_no_merge()` の finalized ブロック差し替え
- `lib/utils.sh`: `ticket_base_from_frontmatter()` 新規（同じ cascade の 4 個目の写しを
  書かずに済ませるため。`cmd_close_no_merge` の `_gated` 側もこれに置き換えた）
- `test/test-reopen.sh`: 49 assertion / 7 section

## テスト

- ローカル `test/run-all.sh`: **798 / 798**（修正前 749 + 新規 49）
- Docker `test/run-all-on-docker.sh`: Ubuntu 22.04 **790 / 790**、Alpine **790 / 790**
- **修正前のコードに対して 32 件落ちる**ことを確認（`git stash push src lib ticket.sh` して
  テストを実行。テストは毎回 build.sh を走らせるので、戻すときは `git checkout -- ticket.sh`
  の後に `git stash pop`）

正直に書いておくと、32 落ちの中で **17 件は壊れたコードでも通っている**。その多くは空振り:

- 「commit が rename として記録されている」→ reopen が失敗した状態では HEAD が finalize の
  commit で、それ自体が rename なので通る
- 「current-ticket/ が ticket を指している」→ `start` が張った symlink がまだ残っている
- 「--dry-run は何も動かしていない」「両方のコピーが無傷」→ 何もしないので当然通る
- section 5 の「check が通れば finalize される」「closed_at が再度入る」→ 壊れたコードでは
  ticket が done/ に在り続け、`close --no-merge` が 0 を返すので、1 回目の finalize で
  入った `closed_at` を見て通る。これはまさに穴そのもので、同じ section の
  「reopen の後に gate が走る」が落ちることで区別されている

空振りが残るのは、section 1 の被害が後続 section の前提を変えるため。各 assertion を
単独で成立させるには fixture を section ごとに作り直す必要があり、落ちる 32 件で欠陥の所在は
特定できるので、ここは測れていることと測れていないことを書き残す方を選んだ。

## テスト自身のバグ 2 件（自分で踏んだ）

- `grep -q "$SCRIPT_COMMAND\? *new <slug>"` — テスト側に `$SCRIPT_COMMAND` は無いので
  パターンが壊れていた。`"new <slug>"` に直した
- section 4 の「base branch 上では --dry-run でも拒否」で `git checkout main` しただけだった。
  `done/` への移動は feature branch 上の commit なので、main では ticket は open のまま。
  `git merge --ff-only` を足した

## ドキュメント

- `README.md` / `README.ja.md`: コマンド一覧、`--no-merge` の冪等性の条件、`reopen` の節
- `spec.md` / `spec.ja.md`: コマンド一覧、`--no-merge` の表（4 通りの結果）、`reopen` の仕様節
- `DEV.md`: `cmd_reopen()` / `cmd_close_no_merge()` の記述、`ticket_base_from_frontmatter()`、
  設計ノート **26**「戻り道、さもなくば gate をやめた gate」、テスト一覧、Recent Enhancements
- `test/README.md` は従来どおり触っていない（最近の suite を 1 つも載せていない。生きた索引は
  DEV.md 側）
