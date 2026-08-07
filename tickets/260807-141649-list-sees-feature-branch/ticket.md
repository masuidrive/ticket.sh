---
priority: 1
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "fast-forward できなかったチケットを list が feature branch から拾って doing 表示する。base 未反映の印も付ける（外部からの意見書 B への回答）。"
created_at: "2026-08-07T14:16:49Z"
started_at: 2026-08-07T14:33:49Z # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

`advance_branch_ff` が失敗すると warning を出して処理を続ける。この判断自体は正しい
（bookkeeping の失敗でユーザの作業を止めるべきではない）が、帰結が1つ残る:

**`started_at` が feature branch にしか載らないため、base 上では `list` が `todo` を返し
続ける。** つまり `record_start_on_base` が解決したはずの元の症状がそのまま再現する。
`nothing is lost` は commit については正しいが、**`list` の表示は失われている**。

しかもこれが起きたことはその場の stderr 1行にしか残らないので、後から
「着手済みなのに `todo` に見える」状態を見ても、fast-forward に失敗したのか、そもそも
`start` していないのかを区別できない。

再現確認済み:

```
Note: Could not fast-forward 'main' to record the start time.
$ ticket.sh list                        → status: todo
$ git show main:.../ticket.md           → started_at: null
$ git show feature/<name>:.../ticket.md → started_at: 2026-08-07T14:02:13Z
```

## retry は原理的に効かない（採らない）

意見書では「失敗したら base を取り直して1回だけやり直す」が提案されたが、**base が進んだ
場合 feature branch は base の新しい commit を含まないので、ff は何度試しても不可能**。
実測:

```
--- 1回目の ff --- Diverging branches can't be fast-forwarded
--- retry ---      Diverging branches can't be fast-forwarded
含まない → ff は原理的に不可能
```

retry で救えるのは「base の作業ツリーに一時的な競合変更があった」ケースだけで、並列運用の
主要因（別の窓が commit する）には当たらない。

「後から検出して ff し直す」案も同じ理由で成立しない。base に `started_at` を載せ直すには
feature branch を merge するしかなく、それは `start` や `list` が黙って行ってよい操作ではない。

## 決定

**`list` が feature branch を見る。** base 上で `todo` と判定されたチケットについて、
`{branch_prefix}<ticket-name>` が存在すればそのブランチの ticket.md を読み、`started_at` が
あれば `doing` として扱う。`git show <branch>:<path>` で読めることは確認済み。

ff の成否に関わらず表示が正しくなるため、「ff に失敗したのか start していないのか区別
できない」問題も同時に解消する。git の中身だけを真実とする設計（サイドカー state ファイルを
持たない方針）とも整合する。

**base 未反映であることを示す印も付ける**（意見書への確認 B の回答が「印もつけて」）。
印が無いと `git show main:.../ticket.md` を見た人が `started_at: null` に驚く余地が残るため。

### 表示の検討

`list` の出力は `- status: doing` / `  ticket_path: ...` / `  priority: 2` / `  started_at: ...`
という key: value 形式。印はこの形式を壊さない形で入れる。実装時に決めるが、候補:

- `status` の値に添える（`status: doing (not on main)`）— 一目で分かるが status 値を parse
  している下流があると壊す
- 独立した行を足す（`  started_at_source: feature/<name>`）— 形式を壊さず、どこから読んだかも
  伝わる

後者を軸に検討する。

### 性能

`todo` と判定されたチケットについてのみ追加で git を叩く。ブランチ存在確認は `git show-ref`
で十分速い。`done` / `canceled` / 既に `doing` のものは触らない。

## Tasks

- [ ] `cmd_list` に、todo のチケットについて feature branch の `started_at` を読む処理を追加する
- [ ] base 未反映であることを示す表示を決めて実装する
- [ ] `--status` によるフィルタが新しい doing 判定と整合することを確認する
- [ ] レガシー flat レイアウトでも動作することを確認する
- [ ] 性能: チケット数が多い repo で `list` が実用的な速度に留まることを確認する
- [ ] `advance_branch_ff` 失敗時の警告文を「表示には影響しない」旨に更新する
- [ ] テストを追加する（ff 失敗後に list が doing + 印を出す / 未 start は todo のまま /
      レガシーレイアウト）
- [ ] ドキュメント更新（spec.*.md の状態判定、ヘルプ）
- [ ] Run tests before closing and pass all tests (No exceptions)
  - [ ] `test/run-all.sh`
  - [ ] `test/run-all-on-docker.sh`
- [ ] Run `bash build.sh` to build the project
- [ ] Get developer approval before closing
