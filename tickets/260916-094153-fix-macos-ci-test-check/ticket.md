---
priority: 1
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "macOS CI で test-check.sh が timeout not found (127) で走っていなかったのを直す"
created_at: "2026-09-16T09:41:53Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

直前のコミット（テストスイート修復）で main の CI が落ちた。**バックストップが正直に
報告し始めたため**で、退行ではない。

## 事実

`test-check.sh` は `test-helpers.sh` を source していない一方で
`TICKET_SH="timeout 5 ./ticket.sh"` を使う。`timeout` は macOS には無い
（coreutils の `gtimeout`）。GitHub の macOS runner には coreutils が入っていないので

- `timeout` → **exit 127 (command not found)**
- 呼び出しは `> /dev/null 2>&1` なので何も出力されない
- `set -e` がスイートを殺す

結果、**出力ゼロ・exit 127**。

直前の「成功」run（35077060991）を確認すると、macOS の test-check は
`Passed: 0, Failed: 0` で出力ゼロ。**このスイートは macOS CI で一度も走っていない。**
run-all が exit code を捨てていたので誰も気づかなかった。

ローカル macOS で通っていたのは Homebrew coreutils の `timeout` があるため。

## 方針

`test-check.sh` に `test-helpers.sh` を source させる。helpers は `timeout` を
関数として定義し、`/usr/bin/timeout` → `gtimeout` → そのまま実行、とフォールバックする。
`timeout` を使う他のスイートは全て既に source 済み（走査で確認）。

## Tasks

- [ ] `test-check.sh` が `test-helpers.sh` を source するようにする
- [ ] `timeout` が無い PATH で 127 を再現し、修正後に通ることを確認する
- [ ] `timeout` を実バイナリとして呼ぶ他のスイートが無いことを確認する
- [ ] Run tests before closing and pass all tests (No exceptions)
- [ ] CI (ubuntu + macos) が通ることを確認する
- [ ] Get developer approval before closing
