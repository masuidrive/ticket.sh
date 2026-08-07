---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "yaml_parse が1行につき4プロセス起動しているのをパラメータ展開に置き換える。list が100チケットで7秒かかる主因。"
created_at: "2026-08-07T14:56:46Z"
started_at: 2026-08-07T14:57:13Z # Do not modify manually
closed_at: 2026-08-07T15:17:48Z # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

`ticket.sh list` が 100 チケットで約 7 秒かかる。内訳を測ったところ `yaml_parse` が
その 83% を占めていた。

| 処理 | 100 チケット分 |
|---|---|
| `extract_yaml_frontmatter` のみ | 0.02 s |
| + `yaml_parse` | 5.79 s |
| + `yaml_get` × 600 | 5.97 s |
| `convert_utc_to_local` × 100 | 0.49 s |
| **`list` 全体** | **6.98 s** |

## 原因

`yaml-sh/yaml-sh.sh` の `yaml_parse` が、パース対象の **1行につき4回サブシェルを起動**して
いる（`:324-327`、および list 項の `:331`）:

```sh
local type=$(echo "$line" | awk '{print $1}')
local indent=$(echo "$line" | awk '{print $2}')
local key=$(echo "$line" | awk '{print $3}')
local value=$(echo "$line" | cut -d' ' -f4-)
```

ticket の frontmatter は7行なので、1ファイルあたり 28 プロセス。100 チケットで約 2800
プロセスになる。

## 方針

この5行を bash のパラメータ展開に置き換える。`cut -d' ' -f4-` と同じ「空白1文字区切り」の
意味を保つため、`read` ではなく `${var%% *}` / `${var#* }` で削る。

```sh
local rest="$line"
local type="${rest%% *}"; rest="${rest#* }"
...
```

外部コマンドへの依存が減るので**複雑性はむしろ下がる**。`yaml_parse` は全コマンドが通る
経路なので、`list` 以外も速くなる。

`_yaml_parse_awk` の呼び出し（ファイルあたり awk 1プロセス）はそのまま残す。ここを削るには
パーサ本体を書き直すことになり、複雑性が釣り合わない。

## 触らないもの

- `convert_utc_to_local`（0.49 s / 100 件）。`date` を呼ぶのが主因だが、表示対象の件数分
  しか走らず、削るには日付処理の自前実装が要る
- `list` 側のロジック。`yaml_parse` が速くなれば `list` 固有の最適化は不要

## Tasks

- [x] `yaml_parse` の行分解をパラメータ展開に置き換える（`:324-327`, `:331`）
- [x] 分割の意味が変わっていないことを確認する（値に連続空白・タブ・記号を含むケース）
- [x] 100 チケットで `list` を再計測し、改善幅を記録する
- [x] yaml-sh のテストが通ることを確認する
- [x] Run tests before closing and pass all tests (No exceptions)
  - [x] `test/run-all.sh`
  - [x] `test/run-all-on-docker.sh`
- [x] Run `bash build.sh` to build the project
- [ ] Get developer approval before closing
