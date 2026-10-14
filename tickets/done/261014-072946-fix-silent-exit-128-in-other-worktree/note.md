---
ticket: 261014-072946-fix-silent-exit-128-in-other-worktree
---

# Work Log: 別の worktree からの start が無言で 128 (GH #16)

## 再現

`worktree_mode: true` の捨て repo で ticket a / b を作り、a を start して
`repo.worktrees/<a>` に cd、そこから `start <b>`。報告どおり **出力なし・exit 128**。

`bash -x` で abort 位置を特定: 生成物 `ticket.sh` の

```bash
_branch_override=$(git -C "$main_repo" show "${_probe}:${ticket_file}" 2>/dev/null \
                   | _ticket_branch_from_stream)
```

1 回目の `_probe` は `features/<a>`。この branch は b の ticket を commit する前に
切られているので b の ticket を持たず、`git show` が 128。`pipefail` で pipeline も
128、`set -e` で代入が run を終わらせる。`2>/dev/null` で git の message も無い。

## bash の挙動を先に確認した点

- `local x=$(cmd)` は **bash 3.2 でも 5 でも** command substitution の失敗を飲む。
  bare `x=$(cmd)` だけが `set -e` で致命的。監査の足切りに使った。
- EXIT trap は command substitution の subshell では **走らない**（bash 3.2 実機）。
  ERR trap は `set -E` を付ければ subshell でも走る。よって「1 行出す」仕組みは
  EXIT trap 側に置くのが誤報を出さない。
- `$BASH_COMMAND` は **未展開**のコマンド文字列。値ではなく行を指す。
- `set -e` は、関数が `|| return 1` の中で呼ばれていると**関数本体ごと**無効化される。
  これが下の check_main_repo_ready の話につながる。

## 直したもの

1. **probe ループ**（報告された本体）。`{ git show ... || true; } | ...` にして、
   持っていない probe を次へ送る。
2. **already-started チェック**。`extract_yaml_frontmatter "$ticket_file"` が cwd の
   tree を読んでいて、別 worktree では `Error: File not found` を出した上で
   「started_at 無し = まだ開始していない」と読んでいた。このチェックが絶対に
   間違えてはいけない向きに間違う。`ticket_frontmatter_text()` を追加し、disk →
   current branch → base → default_branch の順で読む。
   ついでに `/tmp/ticket_yaml.yml` という固定パスへの書き出しも消えた（同時実行で
   踏み合う形だった）。`get_yaml_field` を使う既存の書き方に合わせただけ。
3. **`emit_active_ticket_paths()`**。cwd を probe していたので、別 worktree からだと
   `layout: unknown` / `ticket: tickets/done/<b>.md`（存在しない）を出していた。
   `link_dir` が絶対パスならそれを probe root にする。agent がファイルの場所を知る
   唯一のブロックなので、1 と 2 だけ直して放置するわけにはいかなかった。
4. **EXIT trap**（お願い 2）。crash 系コード 126/127/128 のときだけ、最後に失敗した
   コマンドと位置・報告先を出す。ERR trap は記録のみ。
   意図的な失敗は 1〜6、signal は 129 以上なので、どちらにも message は付かない。
5. **`check_main_repo_ready()`** の `git symbolic-ref` を `|| true` に。

## 事実訂正

5 は最初「detached HEAD で message に届かない bug」として直したが、**修正前でも
message は出ていた**。呼び出し側が `check_main_repo_ready ... || return 1` なので
errexit が関数本体ごと抑止されていた。テスト（節 3）も修正前に 3/3 通る。
`|| true` は「呼び出し側の書き方に依存しない」ための防御として残し、コメントと
テストのコメントを事実に合わせて書き直した。**bug 修正ではない。**

## scope 外（未着手）

- `start` の resume 経路が、既に work commit を持つ feature branch に base を
  fast-forward する件（#13 で確認した既存挙動）。issue を立てるかは未決。

## テスト

- `test/test-worktree.sh` 節 17（13 assertion）。修正前の src では 8 件が落ちる。
  通ってしまう 2 件は「Error を出さない」「File not found を出さない」の否定形で、
  修正前は何も出さずに死ぬため。対になる肯定形が落ちるので検出はできている。
- `test/test-error-reporting.sh`（新規、13 assertion）。修正前は 6 件が落ちる。
  crash は build 済み `ticket.sh` の **copy** に 1 行注入して起こす（外から起こす
  手段が無く、hook を出荷物に残すべきでもない）。
- `test/run-all.sh` 617 passed / 0 failed、`test/run-all-on-docker.sh` 609 / 0。
