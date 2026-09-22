# Work Notes for 260922-060653-fix-branch-override-read-order

## Implementation Details

...

## Task 1

...

## Task N

...


## Reviewer note #N

...

## 作業ログ (2026-09-22)

### 再現

GitHub Issue #13 の手順をそのまま再現できた。`tickets/<T>/ticket.md` を main に commit したあと、
`agent/issue-107` 上でだけ `branch: agent/issue-107` を足して `start` すると:

```
HEAD=features/260922-060741-repro
  agent/issue-107
  features/260922-060741-repro
  main
```

### 原因

`cmd_start()` で `branch_name` を決める読み取り（`ticket_branch_name "$ticket_file" ...`）が
branch 切り替えの**後**にある。base にも ticket があると `on_own_branch` は false になり、
`git checkout main` が走ってから `$ticket_file` を読むので、`branch:` を持たない main 側の
写しを読んでしまう。

### 修正（src/ticket.sh）

1. `pre_switch_branch_override` を **branch 切り替え前**に読む（`base_has_ticket` 判定の直前）。
   `branch_name` はこれを最優先する。
2. `on_own_branch` の判定も同じ値を使うよう整理（以前は同じ内容を 2 回読んでいた。
   ガード条件が同一なので挙動は不変）。
3. さらに、`pre_switch_branch_override == current_branch` のときは base を checkout せず
   その場に留まる elif を追加。追加前は `git checkout main` → 直後に `git checkout agent/issue-107`
   と往復し、その途中で

   ```
   Warning: Currently on branch 'agent/issue-107' with no uncommitted changes.
   Creating new feature branch from 'main' branch instead.
   ```

   という **結局作られない branch を予告する警告**が出ていた（override が無視されたのと
   同じに読める）。往復をやめても最終状態は同じ: resume path で同じ branch を checkout し、
   `started_at` を stamp し、base への fast-forward も従来どおり走る。

### テスト

`test/test-branch-override.sh` に節「9c. a branch: added on the agent branch wins over the
base branch's copy」を追加（6 assertion）。fixture は awk で frontmatter の 1 行目直後に
`branch:` を挿入する形（BSD/GNU sed 差を避けるため）。

修正前の src で同テストを走らせると狙いどおり 2 件失敗する:

```
✗ start ignored branch: and moved elsewhere  → feature/260922-061011-backlogged
✗ start created the prefix-named branch anyway
```

### 回帰確認

- `test/run-all.sh` → 568 passed / 0 failed
- `test/run-all-on-docker.sh` → 560 passed / 0 failed
- `test-branch-override.sh` 単体 → 59 passed / 0 failed
- `--worktree` を手動確認: 同じ形で `start --worktree` すると、branch は既に cwd に
  checkout 済みなので既存 worktree を再利用。HEAD 不変、余計な branch も作られない。

### 本件の範囲外（既存の挙動、別件）

`start` の resume path は `base_has_ticket=true` のとき base を feature branch へ
fast-forward する（`record_start_on_base` → `advance_branch_ff`）。このため、`start` 前から
feature branch に作業 commit が載っていると、その commit ごと base に取り込まれる。

修正前後で同一であることを実測済み（`agent/x` に "agent work" commit を積んでから
main で `start` → どちらも main に "agent work" が入る）ので本チケットでは触っていない。
気になるなら別 issue/ticket で扱うべき。

### ドキュメント

- `spec.md` / `spec.ja.md`: `start` の節に「When the `branch:` was added on the branch itself」
  （和文「`branch:` がその branch 上でだけ書かれた場合」）を追加。
- `DEV.md`: `cmd_start()` の箇条書きに 2 項目、設計判断リストに 15b を追加。
- `README.md` / `README.ja.md`: 記述は既に修正後の挙動と一致しているため変更なし。
