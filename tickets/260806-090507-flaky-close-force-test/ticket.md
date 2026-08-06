---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "test-close-force.sh が約15%の確率で落ちる。落ちるアサーションは毎回異なり、直前に「Error: Not in a git repository」が出る。"
created_at: "2026-08-06T09:05:07Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
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

## Tasks

- [ ] 失敗時の cwd を実際に出力させ、どの時点でディレクトリを見失うか特定する
- [ ] `setup_test_repo` の絶対パス解決で足りない箇所を洗い出す
      （呼び出し側が相対パスのまま `cd` している箇所を含む）
- [ ] 修正後、上記の再現手順で 20回連続 0 失敗を確認する
- [ ] 同じパターンを持つ他のテストファイルにも同様の問題がないか確認する
- [ ] Run tests before closing and pass all tests (No exceptions)
  - [ ] `test/run-all.sh`
  - [ ] `test/run-all-on-docker.sh`
- [ ] Run `bash build.sh` to build the project
- [ ] Get developer approval before closing
