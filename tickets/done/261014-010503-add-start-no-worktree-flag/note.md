# Work Notes for 261014-010503-add-start-no-worktree-flag

## Implementation Details

...

## Task 1

...

## Task N

...


## Reviewer note #N

...

## 作業ログ (2026-10-14)

### 実装 (src/ticket.sh, cmd_start)

1. `--no-worktree` を追加。`use_worktree=false` にし、`no_worktree_flag_set=true` を立てる。
   `--worktree` 側も `worktree_flag_set=true` を立てるようにした（**どちらの向きで指定されたか**を
   記録する。結果の boolean だけでは「指定が無い」と「false を指定した」が区別できない）。
2. `worktree_mode` の読み込みを `no_worktree_flag_set != true` で条件付けた。
   ここが issue の指摘どおり本質で、**この一行が無いとフラグは機能しない**:
   引数解析の後に無条件で `use_worktree=true` に上書きしていたため。
3. `--worktree` と `--no-worktree` の同時指定はエラー（引数解析の直後、`ticket_input` の
   チェックより前に置いたので、拒否した呼び出しは何もしない）。後勝ちにしない理由は、
   コマンドラインを複数箇所から組み立てる呼び出し側に引数の順序が見えないこと。
4. `--no-worktree` + `--copy-file` は **warning を出して続行**。
   - コピー先の worktree が無いので適用されようが無い
   - ただし「worktree を作ったときにだけ適用」は元から `--copy-file` の契約なので、
     拒否にすると「常に `--copy-file` を渡す wrapper」が壊れる
   - 一方 `--worktree`/`--no-worktree` の同時指定はどちらが効いたか分からない曖昧さなので
     エラー。こちらは曖昧さではなく冗長さなので warning、という切り分け

### 読み込み順の変更が load-bearing であることの確認

`--no-worktree` のフラグ追加だけ残し、`worktree_mode` の条件だけ元に戻して実行したところ、
狙いどおり該当アサーションだけが落ちた:

```
✓ worktree_mode: true still creates a worktree with no flag
✗ --no-worktree still made a worktree
    git -C ... worktree add -b feature/...-nwt-off ...
```

### テスト

`test/test-worktree.sh` に節「16. Testing --no-worktree (issue #14)」を追加（14 assertion）。

- `worktree_mode: true` + フラグ無し → worktree が作られる（**既定が壊れていないことの確認**。
  節 9 と重複するが、config の読み込み位置を動かしたので、ここでも押さえる）
- `--no-worktree` → `WORKTREE:` 行が出ない / `git worktree list` が増えない / 今の checkout で
  branch が切り替わる
- その checkout で積んだ commit が ticket の branch に載る（この形の目的そのもの）
- そのまま `close` が通る
- `--worktree --no-worktree` / `--no-worktree --worktree` 両順でエラー、branch も作られない
- `--no-worktre` は `Unknown option` で弾かれる（#11 の穴に戻っていない）
- usage 行に両フラグが出る
- `--no-worktree --copy-file .env` → warning が出て、start 自体は成功する
- `worktree_mode` 無しでの `--no-worktree` は素の `start` と同じ

### 回帰確認

- `test/run-all.sh` → 582 passed / 0 failed
- `test/run-all-on-docker.sh` → 574 passed / 0 failed

### ドキュメント

- help の `start` 行を `[--worktree|--no-worktree]` に変更し、`--no-worktree` の説明を 1 項目追加
- `init` が書き出す config の `worktree_mode` コメント（生成結果を実際に確認済み）
- `worktree_copy_files` のコメントを「`--worktree`, or `worktree_mode: true` without
  `--no-worktree`」に修正
- `README.md` / `README.ja.md`: Worktree セクションに「1 回だけ外す」項目を追加、config 例も更新
- `spec.md` / `spec.ja.md`: **Worktree Mode** に 5 項目（既定であって上書きではない / 同時指定は
  エラー / `--copy-file` は warning / このフラグが支える形）、config 例も更新
- `DEV.md`: `start_ticket()` に 1 項目、設計判断リストに 19 番、Recent Enhancements に 1 行
