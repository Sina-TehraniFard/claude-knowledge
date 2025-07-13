関連ファイル:
- ./claude-knowledge/meta/file-guidelines.md
- ./claude-knowledge/function/testing/testing-junit-guidelines.md
- ./claude-knowledge/development/backend-kotlin-conventions.md
- ./claude-knowledge/development/frontend-vue-conventions.md

# 全実装作業統一規約

## 概要
YESODプロジェクトにおける全実装作業の統一規約。バックエンド・フロントエンド・API・データベース実装時の必須ルール。

## 詳細
### 言語・文字列ルール
日本語使用の原則:
- **ユーザー向けメッセージ**: 必ず日本語で記述する
- **コメント**: 基本的に日本語で記述する
- **例外**: 英語指定がある場合のみ英語を使用

命名規則:
- **変数・メソッド**: キャメルケース（英語）
- **クラス**: パスカルケース（英語）
- **定数**: スネークケース（英語）
- **コメント・メッセージ**: 日本語

### エラーハンドリング規約
エラーメッセージは日本語で記述し、ユーザー向けとシステム向けメッセージを分離する。ログ出力は適切なレベルで実行する。

### API設計規約
レスポンス構造:
- エラーメッセージは日本語
- 成功メッセージも日本語
- フィールド名は英語、値は日本語

### データベース設計規約
コメント記述:
- テーブル・カラムコメントは日本語
- インデックス名は英語

## 実装例
### Kotlinバックエンド実装例
```kotlin
class UserService {
    /**
     * ユーザー情報を取得する
     * @param userId ユーザーID
     * @return ユーザー情報、存在しない場合はnull
     */
    fun getUser(userId: Long): User? {
        // ユーザーが存在しない場合のエラーメッセージ
        throw UserNotFoundException("指定されたユーザーが見つかりません")
    }
}

try {
    userService.createUser(user)
} catch (e: ValidationException) {
    // ユーザー向けメッセージ
    logger.warn("ユーザー作成時のバリデーションエラー: ${e.message}")
    throw UserCreationException("ユーザー情報に不備があります")
} catch (e: Exception) {
    // システム向けログ
    logger.error("予期しないエラーが発生しました", e)
    throw SystemException("システムエラーが発生しました")
}
```

### Vue3フロントエンド実装例
```vue
<template>
  <div>
    <!-- ユーザー情報表示 -->
    <h1>{{ userInfo.name }}さん</h1>
    <p v-if="loading">読み込み中...</p>
    <p v-if="error">{{ errorMessage }}</p>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

// ユーザー情報の状態管理
const userInfo = ref<User | null>(null)
const loading = ref(false)
const errorMessage = ref('')

/**
 * ユーザー情報を取得する
 */
const fetchUser = async (userId: number) => {
  try {
    loading.value = true
    const response = await userApi.getUser(userId)
    userInfo.value = response.data
  } catch (error) {
    errorMessage.value = 'ユーザー情報の取得に失敗しました'
  } finally {
    loading.value = false
  }
}
</script>
```

### APIレスポンス例
```json
{
  "success": true,
  "message": "ユーザー作成に成功しました",
  "data": {
    "userId": 123,
    "userName": "田中太郎"
  }
}

{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "入力値に不備があります",
    "details": [
      {
        "field": "email",
        "message": "メールアドレスの形式が正しくありません"
      }
    ]
  }
}
```

### SQLデータベース例
```sql
CREATE TABLE users (
    id BIGINT PRIMARY KEY COMMENT 'ユーザーID',
    email VARCHAR(255) NOT NULL COMMENT 'メールアドレス',
    name VARCHAR(100) NOT NULL COMMENT 'ユーザー名',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '作成日時'
) COMMENT 'ユーザー情報テーブル';
```

## 関連事項
### 関連ガイドライン
- kotlin-implementation-idiompriority.md: Kotlinイディオム優先実装
- testing-junit-guidelines.md: テスト実装規約
- gateway-upsertaccount-implementation.md: ゲートウェイ実装パター

### 品質保証チェックポイント
- 日本語メッセージの適切な使用
- エラーハンドリングの実装
- APIレスポンスの一貫性
- コメントの適切な記述

検索キーワード: implementation, guidelines, japanese, kotlin, vue3, typescript, spring-boot, api-design, error-handling, database, sql, coding-standards
    {
      "@type": "CreativeWork",
      "name": "言語・文字列ルール",
      "description": "日本語使用の原則と文字列定数の言語ルール",
      "text": "日本語使用の原則:\n- **ユーザー向けメッセージ**: 必ず日本語で記述する\n- **コメント**: 基本的に日本語で記述する\n- **例外**: 英語指定がある場合のみ英語を使用\n\n```kotlin\n// ✅ 正しい例\nclass UserService {\n    /**\n     * ユーザー情報を取得する\n     * @param userId ユーザーID\n     * @return ユーザー情報、存在しない場合はnull\n     */\n    fun getUser(userId: Long): User? {\n        // ユーザーが存在しない場合のエラーメッセージ\n        throw UserNotFoundException(\"指定されたユーザーが見つかりません\")\n    }\n}\n```\n\n```typescript\n// ✅ 正しい例\nexport class UserValidator {\n  /**\n   * ユーザー入力を検証する\n   */\n  validateUser(user: User): ValidationResult {\n    if (!user.email) {\n      return {\n        isValid: false,\n        message: \"メールアドレスは必須です\"\n      }\n    }\n    // バリデーション処理\n    return { isValid: true }\n  }\n}\n```\n\n文字列定数の言語ルール:\n```kotlin\n// ✅ 正しい例\nobject Messages {\n    const val LOGIN_SUCCESS = \"ログインに成功しました\"\n    const val LOGIN_FAILED = \"ログインに失敗しました\"\n    const val USER_NOT_FOUND = \"ユーザーが見つかりません\"\n}\n```"
    },
    {
      "@type": "CreativeWork",
      "name": "コード品質ルール",
      "description": "命名規則とエラーハンドリングの規約",
      "text": "命名規則:\n- **変数・メソッド**: キャメルケース（英語）\n- **クラス**: パスカルケース（英語）\n- **定数**: スネークケース（英語）\n- **コメント・メッセージ**: 日本語\n\n```kotlin\n// ✅ 正しい例\nclass UserRepository {\n    private val userDao: UserDao\n    \n    /**\n     * ユーザーを検索する\n     */\n    fun findUserById(userId: Long): User? {\n        // データベースからユーザーを取得\n        return userDao.selectById(userId)\n    }\n}\n```\n\nエラーハンドリング:\n- エラーメッセージは日本語で記述\n- ユーザー向けとシステム向けメッセージを分離\n- ログ出力は適切なレベルで実行\n\n```kotlin\n// ✅ 正しい例\ntry {\n    userService.createUser(user)\n} catch (e: ValidationException) {\n    // ユーザー向けメッセージ\n    logger.warn(\"ユーザー作成時のバリデーションエラー: ${e.message}\")\n    throw UserCreationException(\"ユーザー情報に不備があります\")\n} catch (e: Exception) {\n    // システム向けログ\n    logger.error(\"予期しないエラーが発生しました\", e)\n    throw SystemException(\"システムエラーが発生しました\")\n}\n```"
    },
    {
      "@type": "CreativeWork", 
      "name": "API設計ルール",
      "description": "レスポンス構造とエラーレスポンスの規約",
      "text": "レスポンス構造:\n- エラーメッセージは日本語\n- 成功メッセージも日本語\n- フィールド名は英語、値は日本語\n\n```json\n{\n  \"success\": true,\n  \"message\": \"ユーザー作成に成功しました\",\n  \"data\": {\n    \"userId\": 123,\n    \"userName\": \"田中太郎\"\n  }\n}\n```\n\nエラーレスポンス:\n```json\n{\n  \"success\": false,\n  \"error\": {\n    \"code\": \"VALIDATION_ERROR\",\n    \"message\": \"入力値に不備があります\",\n    \"details\": [\n      {\n        \"field\": \"email\",\n        \"message\": \"メールアドレスの形式が正しくありません\"\n      }\n    ]\n  }\n}\n```"
    },
    {
      "@type": "CreativeWork",
      "name": "データベース設計ルール",
      "description": "コメント記述とテーブル定義の規約",
      "text": "コメント記述:\n- テーブル・カラムコメントは日本語\n- インデックス名は英語\n\n```sql\n-- ✅ 正しい例\nCREATE TABLE users (\n    id BIGINT PRIMARY KEY COMMENT 'ユーザーID',\n    email VARCHAR(255) NOT NULL COMMENT 'メールアドレス',\n    name VARCHAR(100) NOT NULL COMMENT 'ユーザー名',\n    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '作成日時'\n) COMMENT 'ユーザー情報テーブル';\n```"
    },
    {
      "@type": "CreativeWork",
      "name": "フロントエンド実装ルール",
      "description": "Vue3コンポーネントの実装規約",
      "text": "Vue3コンポーネント:\n```vue\n<template>\n  <div>\n    <!-- ユーザー情報表示 -->\n    <h1>{{ userInfo.name }}さん</h1>\n    <p v-if=\"loading\">読み込み中...</p>\n    <p v-if=\"error\">{{ errorMessage }}</p>\n  </div>\n</template>\n\n<script setup lang=\"ts\">\nimport { ref } from 'vue'\n\n// ユーザー情報の状態管理\nconst userInfo = ref<User | null>(null)\nconst loading = ref(false)\nconst errorMessage = ref('')\n\n/**\n * ユーザー情報を取得する\n */\nconst fetchUser = async (userId: number) => {\n  try {\n    loading.value = true\n    const response = await userApi.getUser(userId)\n    userInfo.value = response.data\n  } catch (error) {\n    errorMessage.value = 'ユーザー情報の取得に失敗しました'\n  } finally {\n    loading.value = false\n  }\n}\n</script>\n```"
    },
    {
      "@type": "CreativeWork",
      "name": "実装例",
      "description": "バックエンドとフロントエンドの具体的な実装例",
      "text": "バックエンド実装例:\n```kotlin\n@RestController\n@RequestMapping(\"/api/users\")\nclass UserController(\n    private val userService: UserService\n) {\n    /**\n     * ユーザー一覧を取得する\n     */\n    @GetMapping\n    fun getUsers(): ResponseEntity<ApiResponse<List<User>>> {\n        return try {\n            val users = userService.getAllUsers()\n            ResponseEntity.ok(ApiResponse.success(\n                data = users,\n                message = \"ユーザー一覧を取得しました\"\n            ))\n        } catch (e: Exception) {\n            ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)\n                .body(ApiResponse.error(\"ユーザー一覧の取得に失敗しました\"))\n        }\n    }\n}\n```\n\nフロントエンド実装例:\n```typescript\n// ユーザー管理サービス\nexport class UserService {\n  /**\n   * ユーザー一覧を取得する\n   */\n  async getUsers(): Promise<User[]> {\n    try {\n      const response = await api.get('/users')\n      return response.data\n    } catch (error) {\n      throw new Error('ユーザー一覧の取得に失敗しました')\n    }\n  }\n}\n```"
    }
  ]
}