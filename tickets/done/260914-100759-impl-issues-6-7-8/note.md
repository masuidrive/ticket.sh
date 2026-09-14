# Work Notes for 260914-100759-impl-issues-6-7-8

## 調査結果

### yaml-sh は list の中の map を読めなかった

`ticket_files:` は `- path: ... / content: |` という list-of-maps。yaml-sh は
「flat structure only」で、実測すると `ticket_files.0.path` は取れず、`content`
というトップレベルキーに潰れていた（`yaml_list_size` も 1 を返す）。

issue #6 の実装メモは `yaml_get <prefix>.<N>.path` で読める前提だったので、
**yaml-sh 側を 1 段だけ拡張する**方針にした（`yaml-sh/` は CLAUDE.md 上
編集可のソース）。

拡張の中身（`yaml_parse` のみ。awk パーサは元から indent を出しているので無改造）:

- `list_path` / `list_indent` / `item_path` の 3 変数で「いま list item の中か」を持つ
- `- key: value` 形式の item は `<list>.<N>.<key>` にも格納する
- それに続く、list の indent より深い `KEY` は `<list>.<N>.<key>` に namespace する
  （`content: |` の複数行は `VALUE` が `current_path` に入れるので、KEY の時点で
  current_path を差し替えておく必要がある）
- item の生テキストは従来どおり `<list>.<N>` にも入れる。`yaml_list_size` は
  `<prefix>.<N>` しか数えないので、これが無いと map item の list が空に見える

既存の scalar list（`require_checklist_groups` など）は `<list>.<N>` をそのまま
読むので挙動不変。yaml-sh の 27 tests / ticket.sh の 382 tests ともに green
（拡張後のベースライン確認済み）。

制約として header に書いたもの:
- list item の 1 個目のキーはインライン値が必要（`- path: a.md`）。
  block scalar は item の下のインデント行に置く。
- nest は list item の 1 段のみ。

## 実装メモ

### #6 ticket_files
- `config_read_ticket_files` が `TICKET_FILE_PATHS[]` / `TICKET_FILE_CONTENTS[]` に読む
- `note.md` の entry は `note_content` を上書きしたうえで既存の note 生成経路に流す
  （`$$NOTE_PATH$$` 置換と "Created note file:" の出力を二重化しないため）
- path は ticket dir の外に出るもの（絶対パス / `..`）を拒否する
- `emit_active_ticket_paths` は config の entry のうち**実在するもの**だけ出す

### #7 append_only_files
- 削除行の数え方は `git log -p` の `^-` grep ではなく `git show --numstat` の
  deletions。変更行は「1 削除 + 1 追加」で、append-only は「既に書いた行に
  手を入れない」ことなので numstat の方が定義に近い。`-- foo` のような行を
  消したときに diff の `---` ヘッダと見分けがつかない問題も避けられる。
- base は issue の指定どおり `<repository>/<base>` → local `<base>` → 警告して skip

### #8 branch:
- `ticket_branch_override` / `ticket_branch_name` / `ticket_claiming_branch` を
  `lib/utils.sh` に追加。frontmatter は awk で読む（yaml-sh のグローバルを
  壊さないため。`started_at_on_branch` と同じ手）
- `close` / `cancel` の「feature branch か」判定は prefix 判定を残したまま
  「ticket が名指ししている branch」を OR で足す（後方互換）
- `list` の branch 一覧は prefix で絞らず全 local branch を引く

## 実装結果

### 追加/変更したファイル

| ファイル | 内容 |
|---|---|
| `yaml-sh/yaml-sh.sh` | `yaml_parse` に list item の map 1 段を追加（`<list>.<N>.<key>`）。header の対応構文/制約も更新 |
| `lib/utils.sh` | `_ticket_branch_from_stream` / `ticket_branch_override` / `ticket_branch_name` / `ticket_claiming_branch` / `ticket_name_for_branch` |
| `lib/append-only.sh` | 新規。`append_only_base_ref` / `_append_only_removed_lines` / `append_only_violations` / `append_only_check` |
| `src/ticket.sh` | `config_read_ticket_files` / `ticket_file_path_ok`、`cmd_new` の `--branch` と ticket_files 生成、`emit_active_ticket_paths` の `file:` 行、`cmd_start` / `cmd_restore` / `cmd_check` / `cmd_close` / `cmd_cancel` / `cmd_list` の branch 解決、close/check への append-only 組み込み、init の config テンプレート、usage、prompt |
| `build.sh` | `lib/append-only.sh` の inline |
| `test/test-ticket-files.sh` | 新規 20 件 |
| `test/test-append-only.sh` | 新規 21 件 |
| `test/test-branch-override.sh` | 新規 29 件 |
| `spec.md` / `spec.ja.md` / `README.md` / `README.ja.md` / `DEV.md` | 3 機能の記述 |

### 設計判断で issue から変えたところ

**#7 の判定単位を commit から行に変えた。** issue は「base 以降の commit のどれかが
その行を削っているか」で判定し、直し方は「削った行を再度追記する。過去の commit は
書き換えない」と書いていた。この 2 つは両立しない — commit 単位で見ると、追記し直しても
削除 commit は履歴に残り続けるので gate が解消せず、amend + force push しか出口が
無くなる。「履歴として残す価値があるファイル」に対してこれは逆。

そこで判定を「**かつてその行があって、今その行が無いか**」にした:

- 削除 commit を `<base>..HEAD` から拾い、各 commit が消した行を `git show -U0` の
  hunk 本体から取る（`^-` を hunk 内でのみ削除行と見なすので、`--` で始まる行を
  消したときに diff の `---` ヘッダと混同しない）
- そのうち**現在のファイルに無い行**だけを違反として数える
- 結果、追記し直せば解消する。issue が書いた復旧手順がそのまま成立する

副作用として「行の変更」も違反になる（変更前の文字列が失われるため）。これは
append-only の定義そのものなので意図どおり。spec / README / DEV に明記した。

### テスト

- local: 452 passed / 0 failed
- Docker (Ubuntu 22.04 / Alpine): 各 433 passed / 0 failed

### 備考

`tmp/` に過去のテスト実行が残した 741 個の scratch ディレクトリがあり、Docker の
chown が事実上進まなくなっていたので削除した（`tmp/` は gitignore 対象）。

### Docker の 1 件失敗はフレークだった

`tmp/` に前の local 実行が残した ~100 個の scratch dir がある状態で回した回だけ、
Ubuntu で `test-missing-coverage.sh` の 8「very long slug」が 1 件落ちた
（`new` は成功したのに `ls tickets/*<slug>*` が見つからない）。

- Ubuntu 単体で同テストを実行 → pass
- 同じコードの前回フル実行（Ubuntu / Alpine）→ 433/433
- `tmp/` を掃除して再実行 → Ubuntu / Alpine とも 433/433、✗ ゼロ

test-helpers.sh の `setup_test_repo` に書かれている overlayfs の
「削除済み inode が再作成されたディレクトリとして返ってくる」問題の症状と一致する。
本件の変更とは無関係。
