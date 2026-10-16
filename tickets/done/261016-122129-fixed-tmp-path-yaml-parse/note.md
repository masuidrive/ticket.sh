# Work Notes for 261016-122129-fixed-tmp-path-yaml-parse

## 直したもの

`yaml_parse` が取るのはファイルで、frontmatter は手元の文字列である。この橋渡しを
3 箇所がそれぞれ自分で名付けたパスでやっていた:

| 場所 | パス |
|------|------|
| `cmd_start`（base_branch の先読み） | `/tmp/ticket_yaml_early.yml` |
| `cmd_close` | `/tmp/ticket_yaml.yml` |
| `cmd_cancel` | `/tmp/ticket_yaml.yml` |
| `yaml-sh` の awk 出力 | `/tmp/yaml_parse_$$.tmp` |

`lib/yaml-frontmatter.sh` に `yaml_parse_text()` を置いて 3 箇所を差し替え、
yaml-sh 側も `mktemp` にした。

## 再現（修正前）

### 1. 並走すると相手の ticket を読む

repo A（base_branch: default → main）と repo B（base_branch: release-b）で
`close --dry-run` を同時に走らせた。A 側にも `release-b` という branch を置いて、
「読み違えても override が成功してしまう」形にした:

```
cross-reads=48  non-passing=48  iterations=100
repo A targeted release-b instead of main: 27 / 60 runs
```

`--dry-run` は `all preflight checks passed` と言ったうえで
`base branch: release-b` を出す。実際の close ならそこへ squash-merge が走る。

worktree を分けた並走は README が宣伝している使い方であり、`close` には
「From a worktree, close refuses to merge if the main repo is ...
(protects parallel workers)」というガードまである。そのガードは main repo の
HEAD を見ているだけで、frontmatter の読み取りは素通りだった。

### 2. 共有マシンで他人のファイルを壊せる

```
$ ln -sf ~/victim.txt /tmp/ticket_yaml.yml
$ ./ticket.sh close --dry-run
Dry-run: all preflight checks passed.
$ cat ~/victim.txt
priority: 2
base_branch: default  # Override base branch for start/close ...
```

固定の名前・`O_EXCL` 無し・world-writable な `/tmp`（CWE-377 / CWE-59）。
`rm -f` が消すのは symlink の方なので、痕跡も残らない。

## 判断したこと

### `get_yaml_field` には置き換えない

最初に考えたのは「temp ファイルをやめて `get_yaml_field`（awk で 1 行読む）に
するのがいちばん綺麗」だったが、これは壊れる。`description: |`（block scalar）は
`yaml_get` なら折り畳んだ本文を返すが、行マッチでは `|` を返す。close の commit
subject は description から作るので、`[ticket] |` という subject になる。

直すべきなのは「パスが固定であること」で、「`yaml_parse` を使っていること」では
ない。テスト section 3 がこの区別を固定している——将来これを「整理」しようとした
人が落ちる場所を作っておく。

### `mktemp` が失敗したら止める

`yaml_parse_text()` は `mktemp` が作れなければ理由を出して 1 を返す。黙って
進めないのは、「自分が書いていないファイルを読む」ことが今回のバグそのものだから。

### TMPDIR は assert しない

`mktemp`（template 無し）は GNU と busybox では `TMPDIR` を見るが、macOS は見ない
（`confstr(_CS_DARWIN_USER_TEMP_DIR)` の per-user ディレクトリを使う）。どちらも
private・予測不能・`O_EXCL` で、必要な性質は満たしている。どこに置くかは platform
の裁量なので、テストは「置いた場所が TMPDIR か」ではなく「後に残っていないか」を
見る。最初に書いた TMPDIR の assert は macOS で**空振りして通っていた**ので捨てた
（テストを信じる前に、壊れたコードに対して落ちるか確かめる理由がこれ）。

テスト section 4 は `mktemp` の shim を PATH の先に置いて、temp ファイルを自分の
ディレクトリに着地させてから数える。`grep -r` を macOS の temp dir に掛けた最初の
版は、そこに 30,451 ファイル・12 GB あって固まった。

## 検証

修正前のコードに対してこのテストを走らせ、落ちることを確認した:

```
✗ repo A read repo B's ticket in 14/40 runs
✗ repo B read repo A's ticket in 26/40 runs
✗ a planted file was clobbered through the symlink
✗ cancel clobbered a planted file
✗ no temp file was made at all
✗ the run carried on without a temp file
✗ the error does not say what is wrong
✗ it claimed success
  Passed: 6, Failed: 8
```

修正後は 14/14。40 組 = 80 run 中 40 run が相手を読んでいたので、1 回でも落とす
assert として 40 組あれば十分（再発すれば実質確実に捕まる）。

- `bash test/run-all.sh` → 693 / 693
- `bash test/run-all-on-docker.sh`（Alpine）→ 685 / 685

## 気づいたが直していないこと

`start` は ticket の `base_branch:` が指す branch へ checkout した**後**に ticket
の存在を確認する。その branch に ticket が無いと「does not exist」と言いながら、
呼び出し元を別の branch に置いたまま終わる（この作業中、再現環境を組んでいて踏んだ）。
範囲が違うので触っていない。別 issue にする。
