# Work Notes for 260806-072601-sync-started-at-to-main-repo

## 設計段階の検証ログ（着手前）

実装方式を決めるにあたり、素の git で挙動を再現確認した。以下はすべて実際に実行した結果。

### 検証1: base 側に未コミット変更があると `merge --squash` が落ちる

却下案 A（base 側の `ticket.md` を未コミットのまま直接書き換える）の可否確認。
feature 側で `started_at` + `closed_at` をコミット、base 側で `started_at` だけを同値で
未コミット書き込み、その状態で `git merge --squash feature`:

```
error: Your local changes to the following files would be overwritten by merge:
	t.md
Please commit your changes or stash them before you merge.
Aborting
```

値が同一でも落ちる。`close` (src/ticket.sh:2665) が確実に失敗するため A は不可。

### 検証2: base 側に untracked のチケットファイルがあると `merge --ff-only` が落ちる

採用案の最頻経路（`new` → `start`）の確認。`cmd_new` は commit を作らないため、base 側の
作業ツリーには untracked な `tickets/<T>/ticket.md` が残る。その状態で worktree 側から
コミットして `git merge --ff-only feature`:

```
error: The following untracked working tree files would be overwritten by merge:
	tickets/T/ticket.md
Please move or remove them before you merge.
Aborting
```

→ 手当てしないと最頻経路で毎回フォールバックに落ち、機能が実質無効になる。
ff 直前に base 側 untracked ファイルを（ff 後の内容と一致する場合のみ）取り除く処理が必須。

### 検証3: 2手段は排他であることの確認

```
$ git fetch . feature:main            # main が別 worktree にチェックアウト済み
fatal: refusing to fetch into branch 'refs/heads/main' checked out at '...'
```

チェックアウト済みブランチへの fetch は fatal。判定を誤ると即エラーになるので、
`git worktree list --porcelain` でのチェックアウト判定が前提条件になる。

### 検証4: base の作業ツリーが dirty でも ff merge は通る

対象パス以外のファイル（`base.txt`）を dirty にした状態で `git merge --ff-only feature`:

```
Updating 5de8d9e..00687e9
Fast-forward
 t.md | 1 +
```

成功する。main repo で別の編集をしていても、ff 対象パスに触らない限り問題ない。
懸念1つ消える。

### 検証5: 非 ff は拒否される

base が独自に進んだ状態で `git fetch . feature:main`:

```
 ! [rejected]        feature    -> main  (non-fast-forward)
```

フォールバック条件は `merge --ff-only` と `fetch` の両手段で同じ形になる。

### 設計上の訂正（重要）

untracked ファイル削除の安全条件を当初「ff 後に復元される内容と一致するなら削除」と
書いたが、これは誤り。`started_at` を書き換えている以上、base 側（null）と feature 側
（時刻入り）の blob は**必ず不一致**になり、判定が常に偽になって機能しない。

正しい基準は「`start` が worktree にコピーした時点の内容と一致するか」。
`start` 冒頭でコピー元の `git hash-object` を記録し、ff 直前に再計算して比較する。
一致すれば base 側に独自編集がなく、かつ start 実行中に誰も触っていないと言える。

## 実装記録

### 入ったもの

- `lib/utils.sh`
  - `worktree_holding_branch <repo> <branch>` — branch を持つ作業ツリーのパスを返す。
    `src/ticket.sh` に3箇所あった同一 awk をこれに置き換えた。
  - `drop_untracked_if_unchanged <wt> <path> <hash>` — untracked かつ hash 一致のときだけ削除。
  - `advance_branch_ff <repo> <branch> <commit> [<path> <hash>]...` — チェックアウト済みなら
    `merge --ff-only`、そうでなければ `fetch . <commit>:<branch>`。非 ff は非ゼロで返す。
- `src/ticket.sh`
  - `record_start_on_base` — ticket.md / note.md をパス指定でコミットし、`advance_branch_ff` で
    base を進め、`auto_push` なら push。各段階の失敗はすべて警告で、`start` は成功させる。
  - `cmd_start` の worktree / 非 worktree 両経路から同じ関数を呼ぶ。snapshot（hash）は
    ブランチ操作の前に、base branch を持つ作業ツリーに対して取る。
  - `start` に `--no-push` を追加（従来は unknown flag として黙って無視されていた）。
  - config キー `no_verify`（既定 false）。
- `test/test-start-base-sync.sh` — 26 アサーション。統合8セクション + ヘルパーのユニット。

### 挙動変更（意図したもの）

**base branch から開始済みチケットを再 `start` すると resume として成功する。**
従来は `started_at` が未コミットで残るため作業ツリーが dirty になり、
`check_clean_working_dir` がエラーで止めていた。resume は元から実装されている機能
(src/ticket.sh の "Resuming work on existing ticket") なので、これが本来の姿。

これに依存していた既存テスト2件を実装の意図に合わせて更新した:
- `test/test-additional.sh` — 「二重 start は失敗する」→「resume して feature branch に戻る」
- `test/test-missing-coverage.sh` — 3つの指定方法がいずれもチケットを解決することを検証する形へ

どちらも `git add current-ticket.md`（gitignore 済みパス）が失敗して作業ツリーが dirty のまま
残る、という副作用に乗って通っていたテストだった。

### 途中で見つかった別件

`.gitignore` の `test-*` が `test/test-*.sh` にもマッチしていて、新規テストファイルが
黙って untracked になっていた（既存テストは gitignore 追加より前からコミット済みだったため
露見していなかった）。ルート直下限定の `/test-*` に修正。

### test-close-force.sh の flakiness は本変更と無関係

docker テストで `test-close-force.sh` が散発的に落ちた（毎回異なるアサーション）。
切り分けのため、main と本ブランチをそれぞれ clean clone して同一条件で連続実行した:

| | 12回 | 20回 |
|---|---|---|
| main（変更前） | 2 失敗 | 3 失敗 |
| 本ブランチ | 3 失敗 | 3 失敗 |

同率であり、変更前から存在する flaky テスト。別チケットとして切り出す。

補足: 最初に `git worktree` で比較したときは main 0/10・本ブランチ 2/10 と出たが、これは
worktree の `.git` がホスト絶対パスを指すため docker 内で git が壊れる不正な比較環境だった。
clean clone で測り直した上表が正しい。

また `start` が重くなってテストの `timeout 5` を超えた可能性も測った（docker 内 0.163 秒）。
無関係。

### 手動で確認した経路

- 非 worktree: start → main に `started_at` 反映、main が start コミットへ ff → close 通過
- worktree: `new` 直後の untracked チケットのまま start → main repo に反映、untracked 解消 →
  main repo での `list` が `doing` 表示 → close 通過
- start コミット後の `cancel` → `tickets/done/<...>-CANCELED-...` へ移動、main に戻る

### 調査メモ

- `close` のプリフライト (src/ticket.sh:2521) は
  `git diff --quiet $(git merge-base base feature) base -- $ticket_file` で base 側の
  ticket file 変更を検出しエラーにする。base へ直接コミットする案 B が不可なのはこれが理由。
  採用案は merge-base 自体が start コミットまで進むため素通りする。
- `close` に「feature が ahead 0 なら止める」判定は無い。また `close` は `closed_at` を
  feature 上でコミットするので、start コミットのみの状態でも squash 対象は空にならない。
- start の対象ブランチは `default_branch` ではなく `effective_base` (src/ticket.sh:1474)。
- `cmd_new` に git 操作は無い（`sed -n '/^cmd_new()/,/^}/p' | grep git` が空）。
