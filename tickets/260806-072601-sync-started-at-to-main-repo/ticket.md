---
priority: 2
base_branch: default  # Override base branch for start/close (default: use default_branch from config)
description: "start 時に started_at を feature branch でコミットし、base branch を ff で進めて反映する（モード非依存）。併せて「サイドカー state ファイルは使わない」設計方針を明文化する。"
created_at: "2026-08-06T07:26:01Z"
started_at: null  # Do not modify manually
closed_at: null   # Do not modify manually
canceled_at: null # Do not modify manually
---

# Ticket Overview

`start` が書き込む `started_at` は feature branch の作業ツリーにしか存在せず、しかも
未コミットのまま残る。そのため base branch から見た `ticket.md` は `started_at: null`
のままで、`list` は作業中のチケットを `todo` と表示し、開始時刻も分からない。

worktree モードでは main repo 側がまさにこの状態になるため目立つが、非 worktree モードでも
base branch に戻れば同じことが起きる。**これはモード固有の問題ではない。**

これを解消し、base branch 側の `tickets/<TICKETNAME>/ticket.md` にも同一の `started_at`
を反映する。併せて、この種の状態を Git 管理外のサイドカー state ファイルで持つ設計を
採らないことをドキュメントに明文化する。

## 採用する方式

モードに依存しない単一の動作として実装する。`start` で:

1. 作業ツリーの `ticket.md` に `started_at` を書く（現行どおり）
2. その変更を feature branch 上でコミットする（`[start] <ticket-name>` 相当）
3. **base branch を fast-forward で進める**

対象ブランチは `default_branch` ではなく `effective_base`（ticket の `base_branch:` で
上書きされうる。src/ticket.sh:1474）。feature branch はそこから作られるので、ff できるのは
`effective_base` に対してだけ。

3 の手段だけが状況で変わるが、分岐条件は `use_worktree` ではなく
**「その branch がどこかの worktree にチェックアウトされているか」**である
（worktree モードでも main repo が base 以外にいることはあり得るため、
モードで分岐するのは誤り）。両者は排他:

- チェックアウトされている → その作業ツリーで `git -C <wt> merge --ff-only <feature>`
- どこにもチェックアウトされていない → `git fetch . <feature>:<base>`
  （git はチェックアウト中のブランチへの fetch を拒否するため、上の条件と自然に排他になる）

ヘルパー（例: `advance_branch_ff <branch> <commit-ish>`）に切り出し、呼び出し側は
モードを意識しない形にする。

### untracked チケットファイルの扱い（必須対応）

`new` は commit を作らない（`cmd_new` に git 操作なし）。よって「`new` → `start`」という
最頻経路では、base branch 側の作業ツリーに **untracked な `tickets/<T>/ticket.md`** が
残ったまま ff を試みることになる。git はこれを拒否する（再現確認済み）:

```
error: The following untracked working tree files would be overwritten by merge:
	tickets/T/ticket.md
Please move or remove them before you merge.
```

何も手当てしないと、**一番よく通る経路でこの機能が毎回フォールバックに落ちて無効になる**。
ff の直前に、base branch 側の untracked なチケットファイルを取り除く必要がある。

**削除の安全条件。** 無条件に消すと、base 側にしか存在しない編集があった場合に失われる。
そこで「消しても何も失われない」ことを確認してから消す。判定基準は
**「`start` が worktree にコピーした時点の内容と一致するか」**である。

- feature branch 側の blob と比較してはいけない。`started_at` を書き換えている以上
  base 側（`null`）と feature 側（時刻入り）は必ず不一致になり、判定が常に偽になって
  機能しない。
- `start` の冒頭でコピー元ファイルの hash（`git hash-object`）を記録し、ff 直前に
  同じファイルの hash を再計算して比較する。一致すれば「base 側に独自の編集はない」
  かつ「start 実行中に誰も触っていない」と言えるので削除して ff。
- 不一致なら削除せず、警告のみ出してフォールバックする。

なお `close` の `merge --squash` も同じ理由で失敗しうる。ff が成功すれば untracked は
tracked に変わるため、この変更は既存の失敗経路をひとつ潰す副次効果を持つ。

## 却下した方式と理由

### A. main repo の `ticket.md` を未コミットのまま直接書き換える

`close` は worktree モードで `git -C $main_repo merge --squash <feature-branch>` を実行する
(src/ticket.sh:2665)。main repo の作業ツリーに `ticket.md` の未コミット変更があると、
値が feature 側と同一でも git は abort する（再現確認済み）:

```
error: Your local changes to the following files would be overwritten by merge:
	tickets/.../ticket.md
Please commit your changes or stash them before you merge.
```

feature 側は `closed_at` も足すので必ず同じパスを touch する → `close` が確実に失敗する。

### B. main repo の default branch に `started_at` を直接コミットする

`close` のプリフライト (src/ticket.sh:2521) が
`git diff --quiet $(git merge-base default feature) default -- $ticket_file` で
「default 側でも ticket file が変更された」ことを検出し、エラーで停止する。
毎回 `close --force` が必要になるため不可。

採用方式（feature branch でコミット → ff merge）は merge-base 自体がその start コミットまで
進むため、このプリフライトを素通りする。

### C. Git 管理外のサイドカー state ファイル（`tickets/.state.json` 等）

**採用しない。** チケットの状態は `ticket.md` の YAML frontmatter だけを唯一の真実とする。
理由:

- サイドカーファイルは gitignore 前提であり、clone / worktree / CI をまたいで共有されない
- frontmatter と state ファイルの二重管理になり、drift したときにどちらが正か決められない
- ticket.sh は「Git-native / Markdown-based」を設計原則としており、Git が追跡しない場所に
  状態を置くことはこの原則に反する

この方針をドキュメントに明記する。

## 実装上の注意

- **ff できない場合のフォールバック**: base branch が既に進んでいると ff できない
  （複数 worktree でほぼ同時に `start` した場合や、base に別のコミットが載っている場合）。
  このときは base を進めず、警告のみ出して続行する（`started_at` は feature branch 側に
  残るので実害はない）。`start` 全体を失敗させないこと。この扱いも上記2手段で共通。
- **コミット対象はパス指定に限定する**: `git add -A` は不可。`ticket.md`（新フォーマットでは
  同ディレクトリの `note.md` も）だけをパス指定でコミットする。worktree には
  `worktree_copy_files` で `.env` 等がコピーされ、`current-ticket*` symlink も生成される。
  これらは gitignore 前提だが、古い `.gitignore` のリポジトリでは混入しうる。
- **pre-commit hook（決定済み）**: hook は**通すのがデフォルト**（`close` と揃える）。
  スキップは設定で選べるようにする（`.ticket-config.yaml` に `no_verify: false` 相当の
  キーを追加し、既定値は `false` = verify する）。既存の config は
  `DEFAULT_AUTO_PUSH` 等と同じ命名・読み出し方に合わせる (src/ticket.sh:126-137)。
- **push（決定済み）**: `auto_push` の設定に従う。有効なら `start` の ff 後に base branch を
  push する。
- **リモートとの非 ff**: 他人が base を進めていると、ローカル base を ff で進めた後の push が
  reject されうる（既存の `close` でも起きるが、base が動く頻度が上がるぶん顕在化しやすい）。
  push 失敗は警告に留め、`start` 自体は成功させること。
- **behind 警告**: base が start ごとに進むので、並行中の他 feature branch は behind 表示に
  なる。`close` はブロックされないが、`start`（resume パス）の警告文言が煩くならないか確認する。
- **resume パス / 既存チケット**: ブランチが既に存在する `start`（resume）と `restore` は
  `started_at` を書き換えない。本機能の導入前に start されたチケットは base 側が null のまま
  残る。遡及的な補完は行わない（行わないことを設計として明記する）。
- **レガシー flat レイアウト**: `tickets/<TICKETNAME>.md` + `-note.md` でも同様に動くこと。
- **epic 系コマンドへの影響**: `epics/` 側にも独自のブランチ／コミット処理がある
  (src/ticket.sh:3719 以降)。本変更が干渉しないことを確認する。
- **既存テストの前提**: 「`start` は commit を作らない」「`start` 後に base branch が動かない」
  を前提にしたテストがあれば更新が必要。

## Tasks

- [ ] base branch を ff で進めるヘルパー（`merge --ff-only` / `fetch .` の2手段）を実装する
- [ ] ff 直前に base 側の untracked チケットファイルを安全に取り除く処理を実装する
      （`start` 冒頭で記録したコピー元の `git hash-object` と ff 直前の再計算が一致する場合のみ
      削除。不一致なら触らず警告してフォールバック）
- [ ] `cmd_start` に started_at コミット + ヘルパー呼び出しを実装する（モード非依存の共通経路）
      — コミット対象は ticket.md / note.md のパス指定に限定
- [ ] ff できない場合のフォールバック（警告のみで続行）を実装する
- [ ] hook スキップ用の config キー（既定 `false` = verify する）を追加する
- [ ] `auto_push` 有効時に ff 後の base branch を push する（失敗は警告に留める）
- [ ] 対象ブランチが `default_branch` ではなく `effective_base` であることを確認する
      （ticket に `base_branch:` 指定があるケース）
- [ ] worktree / 非 worktree の両方で同じ結果になることを確認する
- [ ] base branch が別の worktree にチェックアウトされているケースを確認する
- [ ] レガシー flat レイアウトでも動作することを確認する
- [ ] `close` / `cancel` が新しい履歴形状で正常に動くことを確認する（プリフライト・squash merge）
- [ ] epic 系コマンドに干渉しないことを確認する
- [ ] テストを追加する（base 側 started_at 反映 / new→start の untracked 経路 / 2手段の分岐 /
      ff 不可時のフォールバック / base_branch 指定 / hook スキップ設定 / close 通過）
- [ ] 新しい config キーを README.*.md / spec.*.md の設定一覧に追記する
- [ ] Run tests before closing and pass all tests (No exceptions)
  - [ ] `test/run-all.sh`
  - [ ] `test/run-all-on-docker.sh`
- [ ] Run `bash build.sh` to build the project
- [ ] Update documentation if necessary
  - [ ] Update README.*.md
  - [ ] Update spec.*.md — State Management に「サイドカー state ファイルは使わない」を明記 + start の挙動
  - [ ] Update DEV.md — Key Design Decisions に同方針を追加
- [ ] Get developer approval before closing
