# テストガイドライン

## 1. TDD (Test-Driven Development)

### TDDの黄金サイクル（Red-Green-Refactor）

1. **Red（レッドフェーズ）**
   - まず失敗するテストを書く
   - 最小限の実装に対するテストとする
   - コンパイルエラーも失敗の一種
   - **重要**: 失敗を確認せずに次に進まない

2. **Green（グリーンフェーズ）**
   - テストを通すための最小限のコードを書く
   - ベタ書き、ハードコーディングもOK
   - とにかくテストを通すことだけに集中
   - **重要**: 必要以上の実装をしない

3. **Refactor（リファクタフェーズ）**
   - テストが通っている状態を維持しながらコードを改善
   - 重複を除去し、設計を改善
   - テストコード自体もリファクタリング対象
   - **重要**: 新しい機能は追加しない

### TDDの原則
- **テストファースト**: 実装前に必ずテストを書く
- **小さなステップ**: 1つのテスト = 1つの振る舞い
- **三角測量**: 2つ以上の具体例から一般化を導く
- **明白な実装**: 確信がある場合は最初から正しい実装を書いてもよい

### TDDのアンチパターン
- ❌ すべてのテストを先に書いてから実装を始める
- ❌ privateメソッドを直接テストする
- ❌ テストのためだけに実装を変更する
- ❌ モックを使いすぎる
- ❌ 実装の詳細に依存したテストを書く

## 2. テストクラスの構成

### 基本ルール
- **1クラス1テストクラス（厳守）**: `UserService`に対して`UserServiceTest`のみ
- **テストクラスの分離禁止**: すべて同一テストクラス内に含める
- **@Nestedクラスで階層化**: メソッドや機能単位で整理

### 構成例
```kotlin
class UserServiceTest {
    @Nested
    @DisplayName("listUsers")
    inner class ListUsersTest {
        @Test
        @DisplayName("ユーザーが存在する場合、リストを返す")
        fun shouldReturnUserList() = runTest {
            // テストコード
        }
    }
    
    @Nested
    @DisplayName("createUser")
    inner class CreateUserTest {
        @Test
        @DisplayName("新規ユーザーの場合、作成される")
        fun shouldCreateNewUser() = runTest {
            // テストコード
        }
    }
}
```

### モック管理
- 全体共通のモック: クラスレベルの@BeforeEach/@AfterEachで管理
- 特定inner class専用のモック: そのinner class内で管理

## 3. テスト記述スタイル

### Given-When-Then構造
```kotlin
@Test
@DisplayName("テストケース名")
fun testMethodName() = runTest {
    // Given - 前提条件を箇条書きで明確に記載
    val request = createRequest()
    
    // When - 実行する操作
    val result = service.execute(request)
    
    // Then - 期待される結果
    result shouldBe expectedValue
}
```

### コメントルール
- **許可されるコメント**: Given-When-Then、@DisplayNameのみ
- **禁止されるコメント**: 実装詳細、検証内容の説明、TODOなど
- **すべての説明はGiven-When-Thenに集約**

### suspend関数のテスト
```kotlin
// ✅ 良い例：単一式関数として記述
@Test
@DisplayName("suspend関数のテスト")
fun testSuspendFunction() = runTest {
    // テストコード
}

// ❌ 悪い例：ブロック形式
@Test
@DisplayName("suspend関数のテスト")
fun testSuspendFunction() {
    runTest {
        // テストコード
    }
}
```

## 4. テストの命名と文書化

### @DisplayName
- 「〜の場合、〜する」形式で前提条件と期待値を明確に記載
- 抽象的な表現（「正常に終了する」など）は避ける

### @ParameterizedTest
```kotlin
@ParameterizedTest(name = "{1}")
@DisplayName("メソッドの動作確認")
@CsvSource(
    "true, 引数がtrueの場合、trueが返却される",
    "false, 引数がfalseの場合、falseが返却される"
)
```

## 5. アサーション

### 基本ルール
- **shouldBe優先**: 値の一致確認は`shouldBe`を使用
- **内容も検証**: 件数だけでなく具体的な値も検証
- **登録・更新・削除ではリクエスト検証必須**: coVerifyでパラメータを確認

### 禁止アサーション
- `true shouldBe true`（常に成功するため無意味）
- `"test" shouldBe "test"`（リテラル比較は無意味）

## 6. テストパターン

### 検索系関数
- **必須ケース**: データあり、データ0件、エラー
- **統合すべきケース**: 同条件の複数データパターン
- **分離すべきケース**: エラー、特殊条件、境界値

### エラーハンドリング
- メソッド固有のエラー: 各メソッドでテスト
- 共通エラー: 専用@Nestedクラスで網羅的にテスト
- 重複回避: 共通エラーを専用セクションでテスト済みなら個別メソッドでは省略可

### privateメソッド
- publicメソッド経由でテスト
- 複雑な共通処理は専用@Nestedクラスで詳細テスト
- リフレクションは最終手段

## 7. テストの網羅性

### 必須要件
- すべてのpublicメソッドをテスト（companion object含む）
- エラーハンドリングの網羅（メソッド固有のエラーはすべて）
- 分岐の網羅（if/when文のすべての分岐）

## 8. テスト実行と検証

### 自動実行（ユーザーの指示不要）
1. **新規テストクラス作成時**
   - コンパイルチェック → テスト実行
   
2. **関数単位でのテスト実装時**
   - 1関数のテスト実装 → 即座にコンパイル・実行
   - エラーがあれば修正して再実行
   - PASSしたら次の関数へ

### 手動実行（ユーザー要求時のみ）
- 既存テストの軽微な修正では検証不要
- ロジック変更時はユーザーが明示的に要求

## 9. エラー解決の禁止事項

### テストコード削除禁止
- コンパイルエラーでもテストコードを削除しない
- エラーの根本原因を特定して修正
- テストのスキップ（@Disabled）も禁止
- 空のテストへの置き換えも禁止

## 10. ベストプラクティス

### コード品質
- コメントは必要最小限（Given-When-Then以外は削除）
- UUID文字列は`UUID.randomUUID()`使用
- 未使用importは削除
- @ParameterizedTestを積極活用
- 「〜が正常に生成される」→「〜が生成される」に簡潔化

### テスト最適化
```kotlin
afterEach {
    unmockkAll()  // 各テスト後にモッククリア
}
```

## 付録: TDD実践例

```kotlin
// Step 1: Red - 失敗するテストを書く
@Test
@DisplayName("1 + 1 = 2である")
fun testOnePlusOne() {
    val calculator = Calculator()
    calculator.add(1, 1) shouldBe 2  // Calculatorもaddメソッドも存在しない
}

// Step 2: Green - 最小限の実装
class Calculator {
    fun add(a: Int, b: Int): Int = 2  // ベタ書きでOK
}

// Step 3: Red - 次の失敗するテストを追加
@Test
@DisplayName("2 + 3 = 5である")
fun testTwoPlusThree() {
    val calculator = Calculator()
    calculator.add(2, 3) shouldBe 5  // このテストは失敗する
}

// Step 4: Green - 一般化した実装
class Calculator {
    fun add(a: Int, b: Int): Int = a + b  // 三角測量により一般化
}
```

検索キーワード: tdd, test-driven-development, red-green-refactor, junit, kotest, nested-class, given-when-then, parametrized-test, mockk, kotlin, testing-guidelines