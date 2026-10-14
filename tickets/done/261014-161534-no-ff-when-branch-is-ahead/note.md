---
ticket: 261014-161534-no-ff-when-branch-is-ahead
---

# Work Log: resume 経路の base fast-forward (GH #17)

## 再現と実害（修正前）

ticket を main に commit → その後に branch を切って WIP を 2 件積む →
started_at は null のまま `start`。

```
Recorded start time on 'main'.
$ git log --oneline main
8c5d415 [start] agent/issue-99
945610e WIP: still broken          ← start が取り込んだ
8cc0c09 WIP: bot work, not reviewed ← start が取り込んだ
```

- `close` の「1 ticket = 1 squash commit」が壊れる（1 ticket で main に 4 commit）
- **`cancel` でも作業が main に残る**。cancel は「merge せずに中止」なのに、
  `start` が既に入れているので取り返せない

## 当初の方針を途中で変えた

ticket と issue には「`ahead_count > 0` なら fast-forward を見送る」と書いたが、
**それでは粗すぎた。** `test-branch-override.sh` の節 9c（#13 のテスト）が落ちた。

9c は「bot が backlog の ticket を引き受けて `branch:` を書き込んで commit した」
形で、branch は 1 commit 先にいる。だがその commit は ticket 自身のファイルしか
触っていない。ここで base を止めると、**fast-forward の存在意義そのもの**
（base から `list` して `doing` に見えること）を失う。#13 のために入れた挙動を
#17 の修正で壊すことになり、片方の silent loss を別の silent loss に替えるだけ
だった。

なので判定を「branch が**何を触っているか**」に変えた。

- `lib/utils.sh` に `branch_carries_only <repo> <base> <branch> [<rel>...]`
- 対象は `ticket_file` / `note_file_rel` / `extra_rels`（config の ticket_files）
- `log --format= --name-only base..branch` で、diff ではなく **commit を列挙**する。
  branch 上で足して消したファイルは net diff に出ないが、commit は merge 先に
  残るため
- 判定できないときは非 0（branch を動かすかの判断材料なので、推測より「no」）

## もう 1 つ直したもの

`record_start_on_base()` の skip 時の note が
「`<base>` にこの ticket の copy が無いので進める先が無い」と**無条件に**言って
いた。今回の hold では base に ticket はあるので嘘になり、しかも caller 側の
note と 2 つ並んで出た。base に本当に copy が無いかを自分で確かめてから言う
ようにした。

## 確認

- A. `cancel` 後の main に作業が残らない
- B. ahead == 0 の resume は従来どおり base が `[start]` commit まで進む
- C. worktree モードでも hold する／started_at は branch に commit される
- D. ticket 自身のファイルだけ先行している branch は従来どおり base を進める
- `close` 後の main が 1 ticket = 1 commit になる

## テスト

`test/test-start-base-sync.sh` に節 10〜13 を追加（21 assertion）。
修正前の src では 7 件が落ちる（cancel のケースを含む）。
通ってしまう残りは否定形の assertion と、close の delta を数えるものなど。

- `test/run-all.sh` 638 passed / 0 failed
- `test/run-all-on-docker.sh` 630 passed / 0 failed
