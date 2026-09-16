---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "run-all がテストの失敗を見落とす件と、start が resume で started_at を入れない件を直す"
created_at: "2026-09-16T09:11:11Z"
started_at: 2026-09-16T09:11:11Z # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

直前のチケット（gh #11 / #12）の作業中に見つかった 2 件。どちらも
「失敗・欠落が無言で通る」型で、GitHub issue は立っていない（開発者の口頭指示）。

## 1. `run-all.sh` がテストの失敗を集計しないことがある

`run-all.sh` は各テストの出力から `✓` / `✗` を数え、無ければ `Summary - Passed:` 行を見る。
`test-worktree.sh` は `PASS:` / `FAIL:` を出し、結果行も `  Passed: N, Failed: M`
（`Summary - ` 接頭辞なし）なので**どちらにも該当しない**。加えて `run-all.sh` は
各テストの exit code を `|| true` で捨てている。

実証: `test-worktree.sh` に故意の失敗を 1 件仕込んで `run-all.sh` を回すと

```
Total tests run: 479
Passed: 479
Failed: 0
All tests passed!
Exit code: 0
```

**失敗が完全に不可視。** いま該当するのは `test-worktree.sh` だけだが、出力形式に
依存した集計である限り、次に書かれるテストでも同じことが起きる。

## 2. `start` が既存 branch を resume するとき `started_at` を入れない

`start` は branch を作ってから stamp するので、その間に失敗すると
（frontmatter が壊れている、中断された等）branch だけが残り `started_at` は null のまま。
以降の `start` は「branch が既にある」ので resume 経路に入り、resume は stamp しない。

結果、ticket は永久に `todo` のままになり `close` が

```
Error: Ticket not started
```

で止まる。frontmatter を手で書くまで前に進めない。前チケットの作業中に実際に踏んだ。

## Tasks

- [ ] `run-all.sh` が各テストの exit code を見るようにする（出力形式に依存しない backstop）
- [ ] 全テストが成功時に exit 0 を返すことを確認する
- [ ] `test-worktree.sh` の PASS / FAIL を他と同じ記号に揃え、集計に乗せる
- [ ] 故意の失敗を仕込んで run-all が落ちることを実証する
- [ ] `start` の resume 経路で `started_at` が null なら stamp する
- [ ] base に ticket が無い場合は fast-forward を skip する（gh #9 と同じ扱い）
- [ ] 既に started な ticket を resume しても再 stamp しない
- [ ] テストを追加する
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
- [ ] Get developer approval before closing
