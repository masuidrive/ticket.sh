# Work Notes for 260916-084851-flag-handling-and-worktree-default

## 監査

未知フラグの扱いを全コマンドで実測した。**catch-all は `cmd_start` だけ**:

| コマンド | `--bogus` |
|---|---|
| new / list / restore / check / close / cancel / prompt / version | `Unknown option` で rc=1 |
| start | 黙って無視して続行 |

`start` の廃止フラグは git 履歴と docs を追った結果 `--no-push` のみ
（`637cac0` で push をやめたときのもの）。

## #11 実装

`-*)` の catch-all を削り、`--no-push` を名指しの no-op に、それ以外の `-*` を
`Unknown option` + usage で return 1 にした。エラー用の usage 文字列にも
`--no-push` が残っていたので消した(廃止フラグを help に載せ続ける理由が無い)。

実測:

```
$ ticket.sh start --worktre <ticket>
Error: Unknown option: --worktre
Usage: ... start [--worktree] [--copy-file <path>]... <ticket-name>
→ branch は作られない（main のまま）

$ ticket.sh start --no-push <ticket>
Started ticket: ...   ← 従来どおり
```

## #12 実装

`keep_worktree`（既定 false = 削除）を `delete_worktree`（既定 false = 残す）に反転。

- `--delete-worktree` を追加
- `--keep-worktree` は名指しで受けて no-op（deprecated）
- close / cancel の両方
- help から「coding agents must pass `--keep-worktree`」を削除

**実行時の deprecation 警告は出さない。** 既定が「残す」になった以上
`--keep-worktree` を渡し続けても意味は正しいままで、25 箇所に毎回ノイズを出すのは
「書き換えなくて済むように」という要件に反する。docs 上で deprecated と明記した。

## テストで見つけた既存の欠陥 2 件

### 1. `test-worktree.sh` の worktree 削除チェックが常に vacuous に通っていた

`WT_PATH` は `WORKTREE:` 行から取るので `<repo>/../<repo>.worktrees/<name>` という
`..` 入りの非正規化パス。`git worktree list` は解決済みパスを出すので、

```sh
if [[ ! -d "$WT_PATH" ]] || ! git worktree list | grep -q "$WT_PATH"; then
    pass "Worktree was cleaned up after close"
```

の grep が**常に外れ** → 条件が常に真 → **削除されていてもいなくても PASS**。
つまり「close が worktree を消したか」を一度も検査していなかった。

`worktree_path_from()` を足してパスを一度解決するようにし、アサーションが実際に
何かを見るようにした。

### 2. `run-all.sh` が `test-worktree.sh` の結果を集計していない

`run-all.sh` は各テストの出力から `✓` / `✗` を数え、無ければ
`Summary - Passed:` 行を見る。`test-worktree.sh` は `PASS:` / `FAIL:` を出し、
結果行も `  Passed: N, Failed: M`（`Summary - ` 接頭辞なし）なので**どちらにも該当しない**。

実証: `test-worktree.sh` に故意の `fail` を 1 件仕込んで `run-all.sh` を回したところ

```
Total tests run: 479
Passed: 479
Failed: 0
All tests passed!
Exit code: 0
```

**失敗が完全に不可視だった。** run-all は各テストの exit code も `|| true` で捨てている。

該当は `test-worktree.sh` のみ（`test-simple.sh` は `Summary - Passed:` 形式で拾われる）。

本チケットの作業は塞いでいない（`test-worktree.sh` を直接実行して 34/34 を確認済み）ので、
CLAUDE.md の方針どおり**別チケットにする**。

## テスト

`test/test-worktree.sh`:

- section 6 / 7 を新しい既定（残す）に合わせ、パス照合を正規化
- section 6 は「消えていないのに cd 警告を出さない」ことも見る
  （消えていない対象への警告は、警告を無視する習慣を作る）
- section 14 を新設: `close --delete-worktree` / `cancel --delete-worktree` で
  実際に消えること、消えたときだけ cd 警告が出ること
- section 15 を新設: `start --worktre` が止まること、branch も作られないこと、
  `--no-push` は通ること
- fixture が効いたかを先に assert する（前チケットの反省）

section 11 / 12 は `--keep-worktree` を渡したままにしてある。no-op になった後も
既存の呼び出しが壊れないことの回帰テストとして機能する。

34/34。`test-per-ticket-dir.sh`（`--keep-worktree` を 3 箇所で使用）も 53/53。
