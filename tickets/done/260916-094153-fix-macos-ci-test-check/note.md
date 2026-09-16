# Work Notes for 260916-094153-fix-macos-ci-test-check

## CI が落ちたのは退行ではない

直前のコミット（c17afed、テストスイート修復）で main の CI が failure になった。
落ちたのは **macOS の test ジョブだけ**で、ubuntu / shellcheck / yaml-sh は成功。

```
Suite exited 127 with no failure marks in its output — counted as 1 failure
```

**バックストップが正直に報告し始めた結果**で、私が壊したものではない。

## 証拠: 直前の「成功」run でも走っていなかった

run 35077060991（成功）の macOS ログ:

```
[09:02:16] Starting test: test-check
[09:02:16] Completed test: test-check
  Summary - Passed: 0, Failed: 0
```

**出力ゼロ、0 passed / 0 failed。** `test-check.sh` は macOS CI で一度も走っていない。
run-all が exit code を捨てていたので、0 件を 0 件として数えて素通りしていた。

## 原因

`test-check.sh` は `test-helpers.sh` を source していない一方で

```sh
TICKET_SH="timeout 5 ./ticket.sh"
...
$TICKET_SH init </dev/null > /dev/null 2>&1
```

を使う。`timeout` は GNU coreutils のもので **macOS には無い**（`gtimeout`）。
GitHub の macOS runner には coreutils が入っていないので

1. `timeout` → exit 127 (command not found)
2. 呼び出しが `> /dev/null 2>&1` なのでエラーも出ない
3. `set -e` がスイートを殺す

→ 出力ゼロ・exit 127。

私のローカル macOS で通っていたのは Homebrew の coreutils があるため
（`/opt/homebrew/bin/timeout`）。**「ローカルでは通り CI で落ちる」の 4 度目。**

## 修正

`test-check.sh` に `test-helpers.sh` を source させた。helpers の `timeout` は関数で、
`/usr/bin/timeout` → `gtimeout` → そのまま実行（警告 1 回）とフォールバックする。

`timeout` を実バイナリとして呼ぶスイートが他に無いことを走査で確認した
（`test-helpers.sh` 自身が定義元である以外は該当なし）。

## 検証

PATH から Homebrew を外して runner を模した:

| | rc |
|---|---|
| 修正前 | **127**（出力ゼロ） |
| 修正後 | **0**（11/11） |

ローカル全体 561/561、backstop 発火 0。

## 学び

このセッションで「ローカルで通り別環境で落ちる」を 4 回踏んだ
（mode 000 の挙動差 / `git status 2>&1` の警告 / `((VAR++))` の errexit / `timeout` の有無）。
いずれも**環境差が「失敗」ではなく「沈黙」として現れる**形だった。
バックストップはそれを全部「失敗」に変換する装置なので、入れた直後に
7 スイート + CI 1 件が一気に出てきたのは想定どおりの挙動。
