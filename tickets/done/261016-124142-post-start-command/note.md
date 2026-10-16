# Work Notes for 261016-124142-post-start-command

## 入れたもの

config の `post_start_command:`（shell 1 行）。`start` が **worktree を新しく作った
run のときだけ**、`worktree_copy_files` のコピーの後に、その worktree の root で実行する。

- `lib/utils.sh` に `post_start_run()`
- `src/ticket.sh`: 既定値、`--no-post-start`、config 読み取り、worktree を作る 2 経路
  （新しい branch / 既存 branch で worktree が無い場合）での呼び出し

## 判断したこと

### 失敗しても止めない（#18 と反対）

`pre_close_command` と `post_start_command` は同じ仕組みを逆向きに使ったもので、
失敗時の振る舞いを揃えたくなる。揃えてはいけない。

close の検査は**拒否するために在る**ので非 0 で止める。`post_start_command` が走る
時点では worktree はもう出来ているので、止めても何も守れず、ticket の方を失う——
npm registry が 1 分繋がらないだけで「開くことすらできない ticket」が残り、config を
書き換える以外の出口が無くなる。なので warning を出し、コマンド自身の出力を見せ、
再実行する行（`cd <worktree> && <command>`）を出して、`start` は 0 で終える。

DEV.md の設計ノート 24 にこの対比を書いた。

### 「worktree mode か」ではなく「この run が作ったか」で判定する

`_wt_created` を `git worktree add` が成功した場所でだけ true にしている。
resume のたびに `npm ci` が走ると、ticket を再開する費用が開始する費用と同じになる。
一方「一度消して作り直した worktree」は準備し直す——これは同じ規則の帰結であって、
resume の特例ではない。テスト section 3 が両方を固定している。

worktree を作る経路は 2 つあり（新しい branch / 既存 branch で worktree 無し）、
後者は `_wt_created` が常に true になる場所だが、条件式は両方同じ形にした。
片方だけ条件を変える改変が入らないようにするため。

### 出力順

`Active ticket paths:` より前に出す。あのブロックは `start` の出力のうち下流の
agent が読まなければならない唯一の部分で、install のログは画面の上へ押し流すだけの
長さがある。テストは行番号を比べて順序そのものを assert している。

### `--no-post-start`

準備は `start` の中でいちばん時間のかかる部分になり得るので、1 回だけ飛ばせる口を
付けた。unknown flag が従来どおりエラーであること（#11）もテストで押さえた——
新しいフラグなので、`--no-post-sta` のような打ち間違いが無言の no-op になると
発見が遅れる。

## 検証

`test/test-post-start-command.sh`（34 assertions / 6 section）:

1. key 無しなら何も走らず何も言わない
2. 作った worktree の root で走る・環境変数 5 つ・出力は paths ブロックより前・
   作られたものは worktree 側にあり main checkout には無い
3. 既存 worktree への resume では走らない / 作り直した worktree では走る
4. `--no-worktree` と `--no-post-start` では走らない / 打ち間違いはエラー
5. 失敗しても `start` は 0・warning と exit status・再実行する行・worktree と
   symlink は使える状態・`started_at` は刻まれている
6. `cd` して去り false な test で終わるコマンドが start を脱線させない

- `bash test/run-all.sh` → 727 / 727
- `bash test/run-all-on-docker.sh`（Alpine）→ 719 / 719

## 残っていること（別件）

`start` は ticket の `base_branch:` が指す branch へ checkout した**後**に ticket の
存在を確認するので、その branch に ticket が無いと「does not exist」と言いながら
呼び出し元を別の branch に置いたまま終わる。#20 の作業中に再現環境を組んでいて踏んだ。
範囲が違うので触っていない。issue を立てる。
