# テスト改善計画

## 1. 緊急対応（現在の失敗を修正）

### テストコードの修正
- [ ] 全テストで`git add .`を削除し、必要なファイルのみ追加
- [ ] `start`コマンド後に必ず変更をコミット
- [ ] テストディレクトリの`.gitignore`に`ticket.sh`を追加

### 具体的な修正箇所
```bash
# 修正前
git add . && git commit -q -m "init"

# 修正後  
echo "ticket.sh" > .gitignore
git add .gitignore README.md && git commit -q -m "init"
```

## 2. テストカバレッジの向上

### 不足しているテスト
- [ ] 同時並行作業のテスト（複数チケットの切り替え）
- [ ] 大量チケット時のパフォーマンステスト
- [ ] 不正なYAMLフォーマットの処理
- [ ] Gitコマンド失敗時のエラーハンドリング
- [ ] 権限不足時の動作
- [ ] ディスク容量不足時の動作

### エッジケース
- [ ] チケット名に特殊文字
- [ ] 非常に長いチケット名
- [ ] 空のリポジトリでの動作
- [ ] サブモジュール内での動作

## 3. テスト構造の改善

### 共通化すべき処理
```bash
# test/common.sh を作成
setup_test_repo() {
    local test_name="$1"
    mkdir -p "$test_name"
    cd "$test_name"
    cp ../../ticket.sh .
    echo "ticket.sh" > .gitignore
    git init -q
    git config user.name "Test"
    git config user.email "test@test.com"
    echo "test" > README.md
    git add .gitignore README.md
    git commit -q -m "init"
    git checkout -q -b develop
    ./ticket.sh init >/dev/null
}

teardown_test_repo() {
    cd ..
    rm -rf "$1"
}
```

### アサーション関数
```bash
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "  ${RED}✗${NC} $message"
        echo "    Expected: $expected"
        echo "    Actual: $actual"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="$2"
    
    if [[ -f "$file" ]]; then
        echo -e "  ${GREEN}✓${NC} $message"
        return 0
    else
        echo -e "  ${RED}✗${NC} $message"
        echo "    File not found: $file"
        return 1
    fi
}
```

## 4. CI/CD統合の改善

### GitHub Actions
- [ ] macOS、Ubuntu、Windowsでのテスト
- [ ] 複数のBashバージョンでのテスト
- [ ] カバレッジレポートの生成
- [ ] パフォーマンス計測

### Docker環境
- [ ] 各ディストリビューションでのテスト
- [ ] 最小環境でのテスト（Alpine Linux）
- [ ] 古いGit/Bashバージョンでのテスト

## 5. 実装優先順位

1. **即座に対応**（現在の問題を修正）
   - test-additional.sh の`git add`修正
   - test-close-force.sh の修正
   - test-basic.sh の修正

2. **次に対応**（基本的なカバレッジ向上）
   - エラーハンドリングテスト追加
   - 同時並行作業テスト追加

3. **将来的に対応**（品質向上）
   - テスト共通化
   - CI/CD統合改善
   - パフォーマンステスト

## 成功基準

- [ ] 全環境（macOS/Ubuntu/Alpine）で全テスト成功
- [ ] コードカバレッジ 80%以上
- [ ] 主要なユースケースが全てテスト済み
- [ ] エラーケースが適切にテスト済み