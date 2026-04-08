---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "check_clean_working_dir() のエラーメッセージを改善し、未コミットファイルがtickets/のみの場合とそれ以外の場合で異なるガイダンスを表示する"
created_at: "2026-04-08T15:30:50Z"
started_at: 2026-04-08T15:32:41Z # Do not modify manually
closed_at: 2026-04-08T15:53:08Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# check_clean_working_dir() の未コミット変更メッセージを賢くする

## 背景

`ticket.sh start` 実行時に未コミット変更があると `check_clean_working_dir()` がエラーを出すが、現状は一律に「commit か stash しろ」としか言わない。

`ticket.sh new` でチケットファイルを作成した直後に `ticket.sh start` すると、未コミットファイルは `tickets/` 配下の新規チケット/ノートファイルだけであるにもかかわらず、同じエラーが出る。AI エージェントがこのメッセージを見て stash してしまい、start 後にチケットファイルが見えなくなる問題が発生した。

## 変更内容

`lib/utils.sh` の `check_clean_working_dir()` を改善する:

1. **未コミットファイルが `tickets/` 配下のみの場合**: 「チケットファイルのみが未コミットです。コミットしてから再実行してください」と案内する
2. **それ以外のファイルがある場合**: 従来通り「コミットするか stash するかユーザに確認してください」と案内する

Please record any notes related to this ticket, such as debugging information, review results, or other work logs, `260408-153050-smarter-uncommitted-changes-message-note.md`.

## Tasks

- [x] `lib/utils.sh` の `check_clean_working_dir()` を修正: git status --porcelain の結果を解析し、tickets/ 配下のみかどうかで分岐
- [x] tickets/ のみの場合: コミットして再実行を促すメッセージを表示
- [x] それ以外の場合: 従来のメッセージに加え、ユーザに確認を促す内容を表示
- [x] `build.sh` でビルドして `ticket.sh` に反映
- [x] Run tests before closing and pass all tests (No exceptions)
- [x] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md
  - [ ] Update DEV.md
- [ ] Get developer approval before closing
