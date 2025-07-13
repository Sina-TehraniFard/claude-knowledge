関連ファイル:
- ./claude-knowledge/meta/file-guidelines.md
- ./claude-knowledge/resource/backend/kotlin-style-guide.md

# Kotlinイディオム優先実装ガイド

## 概要
外部リソースの参考時に適用する実装原則。参考するのはロジックのみで、実装方法は必ずKotlinの設計思想とイディオムに従う。

## 詳細
### 基本実装原則
外部リソースからはロジックのみを参考とし、実装方法は必ずKotlinの設計思想に従う。

基本原則:
1. 外部リソースの書き方に依存しない
2. Kotlinらしい書き方を強制適用
3. コードの一貫性を最優先
4. 保守性を重視した実装

### Kotlinイディオム要素
必須適用要素:

#### 1. Null安全性の活用
```kotlin
// 悪い例（他言語的）
if (user != null) {
    return user.name
}
return null

// 良い例（Kotlinらしい）
return user?.name
```

#### 2. 拡張関数の使用
```kotlin
// 悪い例（他言語的）
class StringUtils {
    fun isValidEmail(email: String): Boolean {
        return email.contains("@")
    }
}

// 良い例（Kotlinらしい）
fun String.isValidEmail(): Boolean = contains("@")
```

#### 3. データクラスの活用
```kotlin
// 悪い例（他言語的）
class User {
    private var name: String = ""
    private var email: String = ""
    
    fun getName(): String = name
    fun setName(name: String) { this.name = name }
    // getter/setter続く...
}

// 良い例（Kotlinらしい）
data class User(val name: String, val email: String)
```

#### 4. when式の使用
```kotlin
// 悪い例（他言語的）
if (status == "ACTIVE") {
    return "有効"
} else if (status == "INACTIVE") {
    return "無効"
} else {
    return "不明"
}

// 良い例（Kotlinらしい）
return when (status) {
    "ACTIVE" -> "有効"
    "INACTIVE" -> "無効"
    else -> "不明"
}
```

#### 5. スコープ関数の適切な使用
```kotlin
// 悪い例（他言語的）
val user = User()
user.name = "太郎"
user.email = "taro@example.com"
user.validate()
return user

// 良い例（Kotlinらしい）
return User().apply {
    name = "太郎"
    email = "taro@example.com"
    validate()
}
```

## 実装例
### 例外処理パターン
```kotlin
// 悪い例（Java的）
try {
    val result = riskyOperation()
    return result
} catch (e: Exception) {
    return null
}

// 良い例（Kotlinらしい）
fun riskyOperation(): String? = runCatching {
    // 処理
}.getOrNull()
```

### コレクション操作パターン
```kotlin
// 悪い例（手続き的）
val result = mutableListOf<String>()
for (user in users) {
    if (user.isActive) {
        result.add(user.name)
    }
}

// 良い例（関数型）
val result = users
    .filter { it.isActive }
    .map { it.name }
```

### ダブルバン（!!）演算子の使用禁止（社内規約）
YESODプロジェクトでは、Kotlinのnull安全性を最大限活用し、実行時エラーを防ぐため、ダブルバン（!!）演算子の使用を社内規約により完全に禁止する。

禁止理由:
1. NullPointerExceptionの実行時発生リスク
2. Kotlinのnull安全性の設計思想に反する
3. コードレビューでの見落としリスク
4. 保守性の低下
5. 社内コード品質基準の統一

#### 代替手法（必須）
```kotlin
// ✖️ 禁止例
val name = user!!.name
val value = list.get(0)!!

// ✅ 推奨例1: 安全呼び出し
val name = user?.name

// ✅ 推奨例2: エルビス演算子
val name = user?.name ?: "デフォルト名"

// ✅ 推奨例3: let使用
user?.let { userObj ->
    val name = userObj.name
    // 処理続行
}

// ✅ 推奨例4: requireNotNull（事前条件確認）
val name = requireNotNull(user) { "ユーザーがnullです" }.name

// ✅ 推奨例5: checkNotNull（契約違反検出）
val name = checkNotNull(user) { "契約違反: userはnullであってはならない" }.name

// ✅ 推奨例6: getOrNull使用
val value = list.getOrNull(0)
```

## 関連事項
### 品質保証指針
品質確認項目:

1. null安全性チェック
- `?.`演算子の活用確認
- `!!`演算子の使用禁止確認（社内規約）
- `let`、`run`等でのnull処理確認
- `requireNotNull`、`checkNotNull`の適切な使用

2. 関数型プログラミング活用
- `map`、`filter`、`flatMap`の活用
- `fold`、`reduce`の適切な使用
- 不変データ構造の優先

3. コードの簡潔性
- 1行で表現できる処理の確認
- 冗長なgetter・setterの排除
- 適切なデフォルト引数の使用

4. 型安全性
- sealed classの活用
- inline classの使用検討
- 型推論の活用

検索キーワード: kotlin, idiom, null-safety, functional-programming, data-class, extension-function, scope-function, when-expression, best-practices, coding-standards
    {
      "@type": "CreativeWork",
      "name": "基本実装原則",
      "description": "外部リソース参考時の実装方針とKotlinイディオム優先の基本ルール",
      "text": "外部リソースからはロジックのみを参考とし、実装方法は必ずKotlinの設計思想に従う。\n\n基本原則:\n1. 外部リソースの書き方に依存しない\n2. Kotlinらしい書き方を強制適用\n3. コードの一貫性を最優先\n4. 保守性を重視した実装\n\n適用範囲:\n- 他言語のコード例を参考にする場合\n- 外部ライブラリの実装例を参考にする場合\n- 技術記事のサンプルコードを参考にする場合\n- 過去の実装から移植する場合"
    },
    {
      "@type": "CreativeWork",
      "name": "Kotlinイディオム要素",
      "description": "優先適用すべきKotlinの設計思想と言語機能",
      "text": "必須適用要素:\n\n1. Null安全性の活用\n```kotlin\n// 悪い例（他言語的）\nif (user != null) {\n    return user.name\n}\nreturn null\n\n// 良い例（Kotlinらしい）\nreturn user?.name\n```\n\n2. 拡張関数の使用\n```kotlin\n// 悪い例（他言語的）\nclass StringUtils {\n    fun isValidEmail(email: String): Boolean {\n        return email.contains(\"@\")\n    }\n}\n\n// 良い例（Kotlinらしい）\nfun String.isValidEmail(): Boolean = contains(\"@\")\n```\n\n3. データクラスの活用\n```kotlin\n// 悪い例（他言語的）\nclass User {\n    private var name: String = \"\"\n    private var email: String = \"\"\n    \n    fun getName(): String = name\n    fun setName(name: String) { this.name = name }\n    // getter/setter続く...\n}\n\n// 良い例（Kotlinらしい）\ndata class User(val name: String, val email: String)\n```\n\n4. when式の使用\n```kotlin\n// 悪い例（他言語的）\nif (status == \"ACTIVE\") {\n    return \"有効\"\n} else if (status == \"INACTIVE\") {\n    return \"無効\"\n} else {\n    return \"不明\"\n}\n\n// 良い例（Kotlinらしい）\nreturn when (status) {\n    \"ACTIVE\" -> \"有効\"\n    \"INACTIVE\" -> \"無効\"\n    else -> \"不明\"\n}\n```\n\n5. スコープ関数の適切な使用\n```kotlin\n// 悪い例（他言語的）\nval user = User()\nuser.name = \"太郎\"\nuser.email = \"taro@example.com\"\nuser.validate()\nreturn user\n\n// 良い例（Kotlinらしい）\nreturn User().apply {\n    name = \"太郎\"\n    email = \"taro@example.com\"\n    validate()\n}\n```"
    },
    {
      "@type": "CreativeWork",
      "name": "実装変換パターン",
      "description": "他言語的な実装をKotlinイディオムに変換する具体的パターン",
      "text": "変換パターン集:\n\n1. 例外処理パターン\n```kotlin\n// 悪い例（Java的）\ntry {\n    val result = riskyOperation()\n    return result\n} catch (e: Exception) {\n    return null\n}\n\n// 良い例（Kotlinらしい）\nfun riskyOperation(): String? = runCatching {\n    // 処理\n}.getOrNull()\n```\n\n2. コレクション操作パターン\n```kotlin\n// 悪い例（手続き的）\nval result = mutableListOf<String>()\nfor (user in users) {\n    if (user.isActive) {\n        result.add(user.name)\n    }\n}\n\n// 良い例（関数型）\nval result = users\n    .filter { it.isActive }\n    .map { it.name }\n```\n\n3. 設定クラスパターン\n```kotlin\n// 悪い例（Builder的）\nclass ApiConfig {\n    private var baseUrl: String = \"\"\n    private var timeout: Long = 0\n    \n    fun setBaseUrl(url: String): ApiConfig {\n        this.baseUrl = url\n        return this\n    }\n    \n    fun setTimeout(timeout: Long): ApiConfig {\n        this.timeout = timeout\n        return this\n    }\n}\n\n// 良い例（Kotlinらしい）\ndata class ApiConfig(\n    val baseUrl: String = \"\",\n    val timeout: Long = 5000L\n)\n```\n\n4. 条件分岐パターン\n```kotlin\n// 悪い例（他言語的）\nif (user.type.equals(\"ADMIN\")) {\n    return AdminPermission()\n} else if (user.type.equals(\"USER\")) {\n    return UserPermission()\n} else {\n    throw IllegalArgumentException(\"Unknown type\")\n}\n\n// 良い例（Kotlinらしい）\nreturn when (user.type) {\n    UserType.ADMIN -> AdminPermission()\n    UserType.USER -> UserPermission()\n    else -> error(\"Unknown type: ${user.type}\")\n}\n```"
    },
    {
      "@type": "CreativeWork",
      "name": "ダブルバン（!!）演算子の使用禁止",
      "description": "YESOD社内規約によるダブルバン演算子の完全禁止ルール",
      "text": "ダブルバン（!!）演算子の使用禁止（社内規約）:\n\nYESODプロジェクトでは、Kotlinのnull安全性を最大限活用し、実行時エラーを防ぐため、ダブルバン（!!）演算子の使用を社内規約により完全に禁止する。\n\n禁止理由:\n1. NullPointerExceptionの実行時発生リスク\n2. Kotlinのnull安全性の設計思想に反する\n3. コードレビューでの見落としリスク\n4. 保守性の低下\n5. 社内コード品質基準の統一\n\n例外なし規約:\n- 本番コード、テストコード問わず全面禁止\n- 外部ライブラリ呼び出し時も代替手法を使用\n- レガシーコード修正時は必ず!!を除去\n- コードレビューで発見時は必ず修正指摘\n\n代替手法（必須）:\n```kotlin\n// ❌ 禁止例\nval name = user!!.name\nval value = list.get(0)!!\n\n// ✅ 推奨例1: 安全呼び出し\nval name = user?.name\n\n// ✅ 推奨例2: エルビス演算子\nval name = user?.name ?: \"デフォルト名\"\n\n// ✅ 推奨例3: let使用\nuser?.let { userObj ->\n    val name = userObj.name\n    // 処理続行\n}\n\n// ✅ 推奨例4: requireNotNull（事前条件確認）\nval name = requireNotNull(user) { \"ユーザーがnullです\" }.name\n\n// ✅ 推奨例5: checkNotNull（契約違反検出）\nval name = checkNotNull(user) { \"契約違反: userはnullであってはならない\" }.name\n\n// ✅ 推奨例6: getOrNull使用\nval value = list.getOrNull(0)\n```\n\n違反時の対応:\n- 即座にコード修正\n- 修正理由の記録\n- 再発防止策の検討"
    },
    {
      "@type": "CreativeWork",
      "name": "品質保証指針",
      "description": "Kotlinイディオム適用の品質確認方法と継続的改善",
      "text": "品質確認項目:\n\n1. null安全性チェック\n- `?.`演算子の活用確認\n- `!!`演算子の使用禁止確認（社内規約）\n- `let`、`run`等でのnull処理確認\n- `requireNotNull`、`checkNotNull`の適切な使用\n\n2. 関数型プログラミング活用\n- `map`、`filter`、`flatMap`の活用\n- `fold`、`reduce`の適切な使用\n- 不変データ構造の優先\n\n3. コードの簡潔性\n- 1行で表現できる処理の確認\n- 冗長なgettersetterの排除\n- 適切なデフォルト引数の使用\n\n4. 型安全性\n- sealed classの活用\n- inline classの使用検討\n- 型推論の活用\n\n継続的改善:\n- 定期的なコードレビューでイディオム適用状況を確認\n- 新しいKotlin機能の積極的な導入検討\n- チーム内でのベストプラクティス共有\n- ktlintやdetektによる静的解析の活用\n\nNG実装の早期発見:\n- Java的な書き方の検出\n- 手続き型プログラミングの過度な使用\n- null安全性を無視した実装\n- ダブルバン（!!）演算子の使用（社内規約違反）\n- Kotlinの言語機能を活用しない冗長な実装"
    }
  ]
}