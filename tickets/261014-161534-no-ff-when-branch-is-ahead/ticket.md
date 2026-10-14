---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "resume 経路が作業 commit を持つ branch に base を fast-forward する (GH #17)"
created_at: "2026-10-14T16:15:34Z"
started_at: 2026-10-14T16:15:56Z # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GH #17。`start` の resume 経路が、**すでに自分の commit を持っている feature
branch** に base branch を fast-forward するため、未レビューの作業が `start` の
時点で base に入る。出力は `Recorded start time on 'main'.` の 1 行だけ。

再現済み（`tmp/repro-ff/run3.sh`）。#13 の調査中に見つけて scope 外にしていた
既存挙動で、こちらで実害まで確認した。

## 原因

`cmd_start` の resume 経路。`_resume_skip_ff` が「base が ticket を持っているか」
だけで決まっていて、branch が base より先に進んでいるかを見ていない:

```bash
local _resume_skip_ff=true
[[ "$base_has_ticket" == "true" ]] && _resume_skip_ff=false
```

`record_start_on_base()` は `[start]` commit を branch 上に作って base をそこへ
fast-forward する。branch が「base + stamp だけ」なら正しい（新規作成の経路は
その形）。resume 経路の branch は自分の commit を持ち得るので、fast-forward は
必然的にそれも連れてくる。

`ahead_count` は同じ経路の数行上で計算され、`Feature branch '...' is N
commit(s) ahead of '...'` と表示までしている。判断に使っていないだけ。

## 条件（3 つそろったとき）

branch が既にある / ticket が base にも commit されている / started_at が null。
道は 3 つ: ① bot が branch を作って作業した後の初回 start（`new --branch`）
② start が branch を作った直後に中断（src のコメント自身が想定している）
③ started_at を手で null に戻す（`start` のエラーメッセージ自身が案内している）

## 実害（確認済み）

- `close` の「1 ticket = 1 squash commit」が壊れる。main の履歴に WIP commit が
  個別に残る（確認した例では 1 ticket で 4 commit）
- **`cancel` しても作業が main に残る。** cancel は「merge せずに中止」と
  document されているが、`start` が既に入れているので消えない

## 方針

1. resume 経路で `ahead_count > 0` なら base の fast-forward をしない。
   fast-forward は spec でも best-effort とされているので、「branch が stamp 以外
   の commit を持つときもしない」は同じ契約に収まる
2. base を進めなかったことと理由を 1 行出す
3. ahead == 0 の resume は従来どおり（base は stamp だけ進む）

## Tasks

- [ ] resume 経路で ahead_count > 0 なら base の fast-forward を見送る
- [ ] 見送ったことと理由を 1 行出す
- [ ] worktree モードでも同じか確認する
- [ ] ahead == 0 の resume が従来どおりであることを確認する
- [ ] test を追加する（ff 見送り / message / ahead==0 は従来どおり / cancel で main が汚れない）
- [ ] 修正前の src で新 test が落ちることを確認する
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
