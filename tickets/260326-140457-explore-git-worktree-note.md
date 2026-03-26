# Work Notes for 260326-140457-explore-git-worktree

## 調査結果サマリー

### 発見した問題

#### 問題1: check_git_repo()がworktreeを認識しない（致命的）

- **場所**: `lib/utils.sh:7`
- **原因**: `[[ ! -d .git ]]` でディレクトリのみチェックしているが、worktreeでは`.git`はファイル（gitdirへのポインタ）になる
- **修正**: `[[ ! -d .git && ! -f .git ]]` に変更
- **検証済み**: この修正だけで`ticket.sh list`と`ticket.sh new`がworktree内で動作することを確認

#### 問題2: git worktreeのブランチ排他制約

- **内容**: 同じブランチを複数のworktreeで同時にチェックアウトできない（gitの仕様）
- **影響**: `ticket.sh start`で作成するfeatureブランチが、元のworktreeとバッティングする可能性
- **対応**: これはgitの仕様なのでドキュメントで注意喚起するのが妥当

### ticket.shのworktree関連アーキテクチャ

- **パス管理**: CWD + 相対パス方式 → worktreeでも基本的に動く
- **symlink**: `current-ticket.md` → `tickets/xxx.md` の相対パス → worktreeでも問題なし
- **git操作**: `git checkout`, `git merge --squash`等 → worktree内でも正常動作
- **ブランチ操作**: `git checkout -b` でfeatureブランチ作成 → worktree内でも動くが、ブランチの排他制約に注意

### worktree活用パターン

ticket.shとworktreeの組み合わせ方として想定されるユースケース:

1. **mainをworktreeに置いてチケットレビュー**: メインリポジトリでfeatureブランチ作業中、worktreeでmainを開いてチケット一覧を確認
2. **複数チケット並行作業**: チケットごとにworktreeを作り、それぞれ独立したfeatureブランチで作業
3. **CI/テスト用**: worktreeでテストを走らせつつ、メインで開発を継続

### 必要な修正は最小限

- `lib/utils.sh`の1行修正のみでworktree対応完了
- 他のgitコマンド（`git status`, `git checkout`, `git merge`等）はworktree内でも正常動作する
