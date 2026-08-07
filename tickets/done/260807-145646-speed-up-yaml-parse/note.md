# Work Notes for 260807-145646-speed-up-yaml-parse

## 変更内容

`yaml-sh/yaml-sh.sh` の `yaml_parse` で、パース対象1行ごとに走っていた
`awk` ×3 + `cut` ×1（LIST/ILIST の場合はさらに `cut` ×1）をパラメータ展開に置き換えた。
差し引き5行の置き換えで、外部コマンド依存が減ったぶんコードはむしろ単純になっている。

```sh
rest="$line"
type="${rest%% *}";  rest="${rest#* }"
indent="${rest%% *}"; rest="${rest#* }"
key="${rest%% *}";    value="${rest#* }"
```

`_yaml_parse_awk` は常に4フィールド（`print "KEY", indent, key, ""` の形。値が空でも
区切りは出る）を出力するので、空白1つずつ剥がすと `cut -d' '` と厳密に同じ位置で切れる。
値が自前の先頭空白や連続空白を持っていても保たれる。

## 等価性の確認

旧実装と新実装を同じ入力に通して結果を突き合わせた（`type|indent|key|value|LIST用key` の
5値すべてを比較）。11 パターンで一致:

- 通常のスカラ / 値が空（末尾に区切りだけ残る形）
- 値の内部に連続空白 / 値の先頭に空白
- クォートと `#` を含む値
- LIST・ILIST の項目（空白を含む）
- 複数行値のペイロード行
- タブを含む値 / UTF-8 の値 / ドット区切りのキーパス

## 効果

100 チケットの repo で `list --count 100`:

| | 実時間 |
|---|---|
| 変更前 | 6.99 s |
| 変更後 | 1.73 s |

**75% 削減。** `yaml_parse` は全コマンドが通る経路なので、`list` に限らず効く。

内訳の測定（変更前）:

| 処理 | 100 チケット分 |
|---|---|
| `extract_yaml_frontmatter` のみ | 0.02 s |
| + `yaml_parse` | 5.79 s |
| + `yaml_get` × 600 | 5.97 s |
| `convert_utc_to_local` × 100 | 0.49 s |

frontmatter は7行なので、1ファイルあたり 28 プロセス、100 チケットで約 2800 プロセスが
起動していた計算になる。

## 残した非効率

- `_yaml_parse_awk` の呼び出し（ファイルあたり awk 1 プロセス）。削るにはパーサ本体を
  bash で書き直すことになり、複雑性が釣り合わない
- `convert_utc_to_local`（`date` 呼び出し）。表示対象の件数分しか走らず、自前の日付処理を
  抱えるほどの比重ではない

残り 1.73 秒の大半はこの2つ。

## テスト

`yaml-sh/test.sh` 27/27、`test/run-all.sh` 279/279、
`test/run-all-on-docker.sh` は Ubuntu / Alpine とも 260/260。
