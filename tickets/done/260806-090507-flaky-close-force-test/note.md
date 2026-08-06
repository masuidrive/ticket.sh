# Work Notes for 260806-090507-flaky-close-force-test

## 調査ログ

計測はすべて docker (ubuntu:22.04) 内で、clean な作業コピーに対して実施した。
`git worktree` で比較すると worktree の `.git` がホスト絶対パスを指すため docker 内で
git が壊れ、無意味な結果になる（実際に一度それで誤った差を観測した）。
`git clone` か `git archive | tar -x` で独立したディレクトリを作ること。

### 1. 変更との無関係を確認

| | 12回 | 20回 |
|---|---|---|
| main | 2 失敗 | 3 失敗 |
| feature/260806-072601-sync-started-at-to-main-repo | 3 失敗 | 3 失敗 |

### 2. timeout 仮説を否定

テスト内の `timeout 5` / `timeout 10`（`setup_test_repo` の `ticket.sh init`）を
すべて `timeout 90` に置換して 20回 → **4 失敗**。無関係。

参考に `ticket.sh start` の実測は docker 内で 0.163 秒。

### 3. 並列実行を否定

`test/run-all.sh` はテストを逐次実行しており、`tmp/test-*-$(date +%s)` の名前が
別テストと衝突することはない。

### 4. 症状の直接観測

`setup_test_repo` に一時的な出力を仕込んだ:

```
DBG pre-cd cwd=/workspace abs=/workspace/tmp/test-close-force-1786008457 exists=y
fatal: unable to get current working directory: No such file or directory
DBG setup cwd=/workspace/tmp/test-close-force-1786008457 git=n cfg=n
```

- `cd` は成功している（rc=0、`$PWD` も正しい）
- ディレクトリも `exists=y` で存在する
- それでも `git init` が `getcwd()` に失敗する

`pwd` はビルトインで `$PWD` を返すだけなので、実体の生存は保証しない。chdir 先が
unlink 済み inode になっている、というのが結論。

### 5. mv 方式では直らなかった

「`rm -rf` の代わりに `mv` で名前を先に解放してから削除する」を `setup_test_repo` に
入れたが 4/20 失敗のまま。理由は呼び出し側:

```bash
cd "$PROJECT_ROOT"
rm -rf "$TEST_DIR"          # ← ここで既に消えている
setup_test_repo "$TEST_DIR" # ← ヘルパーの [[ -e ]] ガードが false になり不発
```

ヘルパー側でどう賢く消しても、呼び出し側が先に同じ名前を消していれば意味がない。

### 6. 採用した修正

パスの再利用そのものを無くす。`setup_test_repo` が渡されたパスに呼び出し回数の連番を
付け、毎回別のディレクトリを使う。

- `TEST_DIR` に実際に使ったパスを書き戻す。呼び出し側は 15 箇所すべてが
  `setup_test_repo "$TEST_DIR"` の形なので整合する。唯一の例外
  `test-epic-management.sh` は `local dir` を渡すだけで以降参照しないため影響なし。
- 前回のディレクトリは、新しい作業ツリーに cd した後に削除する（cwd が消えないよう
  順序が重要）。これで `tmp/` に repo が積み上がらない。

### 7. 検証

- `test-close-force.sh` 単体: 20回 0 失敗 → さらに 30回 0 失敗（計 50回）
- 実行後の `tmp/` 残骸: 0
- `test/run-all.sh`: 273/273
- `test/run-all-on-docker.sh`: Ubuntu / Alpine とも 254/254

修正前の失敗率が 15% なので、50回連続 0 失敗であれば偶然の可能性は無視してよい。
