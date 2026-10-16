# Work Notes for 261016-132648-no-switch-before-ticket-check

## 直したもの

in-place の `start` が ticket の `base_branch:` へ checkout する前に、その branch が
ticket を持っているかを確認するようにした。無ければ **branch を動かさずに**止まる。

`base_has_ticket` は switch のかなり上（`on_own_branch` の判定用）で既に読んで
あったので、確認を前に出すために追加の git 呼び出しは要らなかった。順序だけの変更。

## 3 つの失敗は 1 つの失敗だった

issue には 3 つ並べて書いたが、実装してみて「順序」という 1 つの欠陥の帰結だと
分かった。ticket が届くかどうかを、それを決める branch を checkout した**後**に
確認していたので、答えが被害に依存していた。

二次被害の方が厄介である。間違った message は読み直せるが、「`list` を実行せよ」と
言われて `(No tickets found)` と出る branch に置かれると、回復可能な混乱が
「確認済みの結論」に変わる。DEV.md の設計ノート 25 にこの形を書いた（設計ノート 20 の
無言 exit 128 も「読む場所が違う」話だったので、この repo で 2 回目）。

## message の文面

最初は 1 行目に path と branch 名を混ぜて書いたが、変数が展開されると 100 文字を
超えて折り返しが乱れた（#17 で同じことをやった）。散文の行は固定幅にして、展開される
ものは全部それぞれの行に出す形にした:

```
  ticket:       tickets/<name>/ticket.md
  base_branch:  release
  you are on:   main
```

## 行き先 3 つは、印字された通りに実行して確かめた

テスト section 4 は、`start` が出した行をそのまま `eval` している。再構成ではなく
その行自身を実行する——誰も試していない助言は推測なので。

そこで 1 つ直した。最初の案は `git checkout main -- <ticket.md>` だったが、これでは
**note.md が置き去りになる**。ticket directory 全体（`tickets/<name>/`）を名指しする
形にした。legacy の flat layout では ticket ファイルを名指しする（directory が無い）。
テストは「carry command が directory を名指しすること」と「その後 note.md が在ること」
の両方を assert している。

## 検証

修正前のコードに対してこのテストを走らせ、落ちることを確認:

```
✗ start moved us to 'release'
✗ HEAD moved
✗ it switched branches
✗ the ticket was taken out of the tree
✗ the error does not say what is wrong
✗ the base branch is not named
✗ it does not say the tree was left alone
✗ it switched branches to report a missing ticket
✗ no carry command was printed
✗ it names a single file
✗ the note was left behind
✗ the way out did not work
  Passed: 10, Failed: 12
```

修正後 22/22。

修正前に通っている assert が 2 つある（`it does not claim the ticket does not exist`
と `'list' still shows the ticket afterwards`）。これは section 1 が `release` に
置き去りにした結果、section 2 の `start` が「ticket が手元に無い / effective_base は
main」という別の経路に入って**成功してしまう**ため。壊れたコードでは assert が空振り
するという、この修正が取り除く混乱そのもの。全体としては 12 落ちるので検出能力に
問題は無い。

- `bash test/run-all.sh` → 749 / 749
- `bash test/run-all-on-docker.sh`（Alpine）→ 741 / 741

## 範囲外として残したこと

checkout の後に失敗し得る経路（`git checkout -b` の失敗など）は残っている。ただし
そこで止まった場合に立っているのは base branch なので、ticket を失う形ではない。
issue の提案 4 は「戻す処理で揃える」だったが、「動く前に確かめる」方が確実で、
戻す処理自体も失敗し得るので、今回は前者を採らなかった。
