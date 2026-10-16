---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "start は base_branch へ checkout する前に ticket の存在を確認する（GH #21）"
created_at: "2026-10-16T13:26:48Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GH #21。in-place の `start`（worktree を作らない場合）は、ticket の `base_branch:` が
指す branch へ **checkout してから** ticket がそこに在るかを確認する。無ければ
「Ticket not found」で終わるが、**branch は切り替わったまま**で、そのことは一言も
出ない。

再現: ticket を main に commit し frontmatter を `base_branch: release` にする
（release は ticket の commit より前に切ってあるので ticket を持っていない）。

```
$ ./ticket.sh start <ticket>
...
Switching to 'release' branch...
Error: Ticket not found
$ git branch --show-current
release
$ ls tickets/
README.md
```

これが単なる文面の問題でない理由:

1. **呼び出し元が別の branch に置かれる。** start は失敗したのに HEAD が動いている
2. **error の助言が逆効果。** 言われたとおり `list` すると release には ticket が
   無いので `(No tickets found)`。ticket は main に在るのに「無い」の確信が強まる
3. **「無い」が間違っている。** ticket は在る。切り替えた先に無いだけで、start は
   切り替える前にそれを見ていた

worktree モードでは起きない（cwd の HEAD を触らないので、同じ ticket が普通に
start できる）。in-place 経路だけの問題。

## 設計判断

1. checkout する**前**に、切り替え先に ticket が在るかを確認する。`base_has_ticket`
   は既に switch より上で計算済みなので、新しい git 呼び出しは要らない
2. 無ければ **branch を動かさずに**エラーにする。文面は「無い」ではなく実際の状態
   （ticket は在るが base branch には無い）
3. 行き先を 3 つ出す: ticket を base branch に載せる / `base_branch:` を直す /
   `--worktree` で始める（worktree 経路は ticket を運んでくれるので実際に通る）
4. ticket がどこにも無い場合は、switch する前に従来の「Ticket not found」を出す

## Tasks

- [ ] switch の前に guard を置く（ticket が base branch に無ければ動かずに止まる）
- [ ] ticket が手元に在る場合の文面（実際の状態と行き先 3 つ）
- [ ] ticket がどこにも無い場合は switch 前に「Ticket not found」
- [ ] テスト: 非 0 で終わる / branch が動かない / 文面 / その後 `list` が ticket を
      見せる / 従来のケース（base に ticket が在る）が変わらない / worktree は通る
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
