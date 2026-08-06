---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "test-close-force.sh が約15%の確率で落ちる。落ちるアサーションは毎回異なり、直前に「Error: Not in a git repository」が出る。"
created_at: "2026-08-06T09:05:07Z"
started_at: 2026-08-06T09:23:53Z # Do not modify manually
closed_at: 2026-08-06T09:58:57Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

`test/test-close-force.sh` が散発的に失敗する。落ちるアサーションは実行ごとに異なり、
特定のテストが壊れているわけではない。

## 測定結果

main と feature ブランチをそれぞれ clean clone し、docker (ubuntu:22.04) 内で連続実行:

| | 12回 | 20回 |
|---|---|---|
| main | 2 失敗 | 3 失敗 |
| feature/260806-072601-sync-started-at-to-main-repo | 3 失敗 | 3 失敗 |

失敗率はおよそ 15%。両ブランチで同率であり、`start` の base branch 同期
（260806-072601）とは無関係な既存の問題であることが確認済み。

## 手がかり

- 失敗の直前に必ず次が出る:
  ```
  sed: .ticket-config.yaml: No such file or directory
  Error: Not in a git repository
  ```
  → テストのセットアップ後、cwd が期待した `$TEST_DIR` ではなくリポジトリルート等に
  いる状態でコマンドが走っている。
- `test/test-helpers.sh` の `setup_test_repo` には既に類似の対策コメントがある
  （busybox で `rm -rf` 直後に同じ相対パスを `mkdir` して `cd` すると、shell の cwd inode
  追跡が unlink 済みの古いディレクトリを返す）。Alpine 向けに絶対パス解決を入れてあるが、
  Ubuntu でも同じ症状が出ているため対策が不十分か、別の箇所に同じパターンが残っている。
- `test-close-force.sh` はセクションごとに `cd "$PROJECT_ROOT"` → `rm -rf "$TEST_DIR"` →
  `setup_test_repo "$TEST_DIR"` を繰り返しており、同じ相対パスの削除・再作成を最も多く
  行うテストである。

## 再現方法

```bash
git clone --branch main . /tmp/c-main
cd /tmp/c-main && bash build.sh
docker run --rm -v "$PWD:/workspace" -w /workspace ubuntu:22.04 bash -c '
  apt-get update -qq && apt-get install -y -qq git sudo
  useradd -m -s /bin/bash testuser; chown -R testuser /workspace
  sudo -u testuser bash -c "
    git config --global user.name T; git config --global user.email t@t
    git config --global --add safe.directory \"*\"
    cd /workspace
    F=0; for i in \$(seq 1 20); do
      bash test/test-close-force.sh 2>&1 | grep -q \"✗\" && F=\$((F+1))
    done; echo \"FAILED_RUNS=\$F / 20\""'
```

## 原因

`setup_test_repo` に計測用の出力を入れて docker 内で回し、失敗時の状態を捕まえた:

```
DBG pre-cd cwd=/workspace abs=/workspace/tmp/test-close-force-1786008457 exists=y
fatal: unable to get current working directory: No such file or directory
DBG setup cwd=/workspace/tmp/test-close-force-1786008457 git=n cfg=n
```

`cd` は成功し `pwd` も正しいパスを返すのに、直後の `git init` が cwd を取得できずに落ちて
いる。`pwd` はシェル変数 `$PWD` を返すだけなので実体を保証しない。つまり **chdir した先が
削除済みの inode** だった。

テストは1つの `TEST_DIR` をセクションごとに `rm -rf` → `setup_test_repo` で作り直す。
overlayfs (Docker) では、直前に `rm -rf` した名前で `mkdir` すると、既に unlink された古い
inode が返ることがある。以降その作業ツリーでの git 操作がすべて失敗し、その回にたまたま
実行中だったアサーションが落ちる。失敗するテストが毎回違うのはこのため。

### 否定した仮説

- **テスト内の `timeout 5` / `timeout 10` を超えている** → `timeout 90` に上げても 4/20 失敗。
  無関係（`start` 自体は docker 内で 0.163 秒）。
- **`run-all.sh` の並列実行によるディレクトリ衝突** → 逐次実行であり衝突しない。
- **削除を `mv` で名前だけ先に解放する** → 4/20 失敗のまま。呼び出し側が
  `setup_test_repo` を呼ぶ *前* に `rm -rf "$TEST_DIR"` しているため、ヘルパー側の
  対策が発動しない。

## 修正

`test/test-helpers.sh` の `setup_test_repo` が、渡されたパスに連番を付けて **毎回別の
ディレクトリ** を使うようにした。パスの再利用そのものを無くす方針で、呼び出し側が事前に
`rm -rf` していても効く。

- 使ったパスは `TEST_DIR` に書き戻す（呼び出し側が cd 戻り・後始末に使うため）
- 新しい作業ツリーに cd した後で前回のディレクトリを削除するので、長いテストでも
  `tmp/` に repo が積み上がらない

### 検証

| | 失敗 |
|---|---|
| 修正前 (main) | 3 / 20 |
| 修正後 | 0 / 20、0 / 30（`tmp/` 残骸も 0） |

`test/run-all.sh` 273/273、`test/run-all-on-docker.sh` は Ubuntu / Alpine とも 254/254 で
いずれも 0 失敗。

## Tasks

- [x] 失敗時の cwd を実際に出力させ、どの時点でディレクトリを見失うか特定する
- [x] `setup_test_repo` の絶対パス解決で足りない箇所を洗い出す
      （呼び出し側が相対パスのまま `cd` している箇所を含む）
- [x] 修正後、上記の再現手順で 20回連続 0 失敗を確認する
- [x] 同じパターンを持つ他のテストファイルにも同様の問題がないか確認する
- [x] Run tests before closing and pass all tests (No exceptions)
  - [x] `test/run-all.sh`
  - [x] `test/run-all-on-docker.sh`
- [x] Run `bash build.sh` to build the project
- [ ] Get developer approval before closing
