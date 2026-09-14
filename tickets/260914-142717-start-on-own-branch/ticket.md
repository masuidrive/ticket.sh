---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "start が、ticket の branch: と同じ branch 上にだけ ticket があるときも動くようにする（gh #9）"
created_at: "2026-09-14T14:27:17Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

GitHub issue #9。#8（frontmatter `branch:`）の実装の穴。

Closes #9

`start` は ticket ファイルの存在確認より**先に** base branch へ checkout するので、
ticket がその ticket 自身の `branch:` 上にしか commit されていない場合、base に
切り替えた時点で唯一の ticket を見失い `Ticket not found` になる。

bot（masuidrive/pdh の github-bot 層）の流れがちょうどこれ: machinery が
`agent/issue-N` を作って checkout し、その上で `new --branch agent/issue-N` →
commit する。base branch には ticket が無い。

`restore` / `check` / `close` は base branch へ切り替えないので #8 の実装のまま通る。
`start` だけが取り残されている。

## 再現

```bash
git checkout -b agent/issue-77
./ticket.sh new issue-77 --branch agent/issue-77 && git add tickets && git commit -m ticket
./ticket.sh start <ticket-name>
# → Warning: Currently on branch 'agent/issue-77' ... Switching to 'main' → Error: Ticket not found
```

## 方針

現在の branch が ticket の `branch:` と一致し、ticket がその branch 上に存在し、
base branch には無いなら、base へ切り替えずにそのまま `started_at` を入れて commit し、
`Active ticket paths:` を出す。base に ticket が無いので fast-forward は skip し、
その旨を 1 行出す。それ以外は現行どおり。

作業ログは `note.md` に記録する。

## Tasks

- [ ] 再現を fixture として固定する
- [ ] `cmd_start` に「ticket が自分の branch 上にしかない」経路を足す
  - [ ] base branch へ切り替えない
  - [ ] `started_at` を stamp して、その branch 上で commit する
  - [ ] base への fast-forward は skip し、理由を 1 行出す
  - [ ] `Active ticket paths:` を出す
  - [ ] 既に started な場合は再 stamp しない（resume 相当）
- [ ] worktree モードでこの経路に入らないこと（cwd の HEAD を触らないため既に別扱い）
- [ ] `branch:` が無い ticket / ticket が base にもある場合は現行と同一の挙動
- [ ] `test/test-branch-override.sh` に節を追加する
- [ ] Run tests before closing and pass all tests (No exceptions) — `test/run-all.sh` と `test/run-all-on-docker.sh`
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.md / README.ja.md
  - [ ] Update spec.md / spec.ja.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
