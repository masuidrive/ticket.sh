# Work Notes for 260916-083156-gate-close-no-merge

## 事実確認

issue #10 の主張 2 点をコードで確認した。どちらも事実。

1. `cmd_close_no_merge` に `checklist_gate` / `checklist_require_groups` /
   `append_only_check` の呼び出しは **0 件**
2. default branch 上の `check` は Case 3 で `✓ No active ticket (on default branch)`
   を出し、`checklist_ticket` を設定しないまま return するので checklist を一切
   出力しない。issue が「死んだコードだった」と書いているのはこれ

## この制約を書いたのは #7 の実装時（自分）

spec / README / DEV / issue #7 コメントに

> `close --no-merge` は merge 後に base branch 上で走るので `<base>..HEAD` が空で、
> 測る履歴が残っていない

と明記した。**前提は「コマンド」ではなく「コマンドが走る場所」についてのものだった**のが
弱点。同じコマンドが別の場所で走り出した瞬間に、制約の説明ごと誤りになった。

## 実装

### gate の適用条件

`current_branch != <ticket の base branch>` のときだけ効かせる。base は ticket の
`base_branch`（`merge_to` 後方互換込み）、無ければ config の `default_branch`。

`default_branch` だけで判定しないのは、ticket が `base_branch` で別の branch を
指しているとき、そちらが「merge 後に立っている場所」になるため。

base branch 上で飛ばすのは維持した。そこでは merge が既に済んでいるので、拒否しても
ticket が `done/` の外に取り残されるだけで、誰の役にも立つ行動にならない。

### 効かせる 3 つ

`cmd_close` と同じ順序・同じ関数:

1. `require_checklist_groups` → `checklist_require_groups`（欠落グループを先に）
2. `require_checklist` → `checklist_gate`（未記入）
3. `append_only_files` → `append_only_check`（失われた行、new layout のみ）

すべて `update_yaml_frontmatter_field` の**前**に置いたので、拒否時に closed_at も
git mv も走らない（テストで「拒否前に tree が触られていない」ことを見ている）。

### flag にしなかった

issue の要望どおり既定で効かせる。3 つの gate はいずれも config で opt-in
（既定は空 / false）なので、**既に gating を要求しているプロジェクトにしか影響しない**。
後方互換の実害はほぼ無い。

flag による opt-in を避けたのは、迂回が**無出力**で気づけないことが issue の動機だから。
飛ばす判断を呼び手に委ねると「呼ぶのを忘れる」形の穴が残り、しかも沈黙する。

### ついでに直した: `--dry-run` の黙殺

`cmd_close` は `--dry-run` を受け取るが、`--no-merge` の分岐は `dry_run` を
`cmd_close_no_merge` へ渡していなかったので、**受け取って黙って無視**していた。
検証したつもりで何も検証していない状態を作るので、渡すようにして gate の後・
書き込みの前で止めるようにした。gate を事前に見る手段でもある。

## テスト

`test/test-close-no-merge.sh` に section 8 / 9 / 10 を追加（全体 23 assertion）:

- 8: feature branch 上で checklist / append_only が効く、拒否前に何も書かない、
  `--dry-run` で見える、充足すれば通る
- 9: base branch 上では従来どおり飛ぶ（gate が拒否する状態を作ったうえで通ることを見る）
- 10: gate キー未定義なら feature branch 上でも従来どおり通る

gate を `if false` で無効化して**6 件落ちることを実測**した（落ちる → 直す → 通る）。

local 全体 green。

## Alpine で 4 件落ちた: テストが python3 / perl に依存していた

Ubuntu 471/471 に対し **Alpine が 469/473**。落ちたのは section 8 / 9 の後半で、
原因はテスト側:

```
/workspace/test/test-close-no-merge.sh: line 222: perl: command not found
```

チェックリストを `- [ ]` → `- [x]` に書き換えるのに python3 のヒアドキュメントを使い、
失敗時の fallback に perl を置いていた。**Alpine にはどちらも無い**ので書き換えが
実行されず、「充足したはずの ticket」が未記入のまま gate に弾かれていた。

つまり ticket.sh 側は正しく、私の fixture が黙って何もしていなかった。

修正:

- `sed_i`（test-helpers の互換ラッパ、BSD/GNU 両対応）に置き換え
- **書き換えが効いたことを assert する**ようにした。`- [ ]` が残っていれば
  「test setup: checklists were not settled」として落とす。黙って何もしない fixture は
  今回で 3 回目なので、次は setup の失敗として見えるようにする

（#9 でも shim / mode 000 の fixture を 2 回間違えている。「fixture が期待どおり
作用したか」を先に assert するのを既定にすべきだった。）
