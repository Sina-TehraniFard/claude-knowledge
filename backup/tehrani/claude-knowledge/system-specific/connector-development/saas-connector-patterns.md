関連ファイル:
- ../smarthr/smarthr-connector-implementation.md
- ../connector-gateway/yesod-connector-patterns.md
- ../../function/implementation/CLAUDE.md

# SaaSコネクタ開発の共通パターン

## 概要
Yesodシステムで企業向けSaaSサービスとの連携を行うコネクタ開発の標準的なパターンとベストプラクティス。
SmartHRコネクタの実装から抽出した再利用可能な設計パターンと実装手法。

## 詳細

### アーキテクチャパターン

#### レイヤー構造
```
┌─────────────────────────────────────┐
│ Frontend (Vue.js + TypeScript)      │
│ - Connector Registration            │
│ - Attribute Mapping                 │
│ - Authentication UI                 │
└─────────────────────────────────────┘
                    │
┌─────────────────────────────────────┐
│ ConnectorGateway                    │
│ - Business Logic                    │
│ - Data Transformation               │
│ - Error Handling                    │
└─────────────────────────────────────┘
                    │
┌─────────────────────────────────────┐
│ API Client                          │
│ - HTTP Communication                │
│ - Authentication                    │
│ - Rate Limiting                     │
│ - Retry Logic                       │
└─────────────────────────────────────┘
```

### APIクライアント実装パターン

#### 基本構造テンプレート
```kotlin
class {ServiceName}Client(
    domain: String,
    credentials: Map<String, String>
) : OAuth2HttpClient() {
    
    init {
        // 必須パラメータの検証
        require(domain.isNotBlank()) { "Domain is required" }
        require(credentials.isNotEmpty()) { "Credentials are required" }
    }
    
    // サービス固有の設定
    private val baseUrl = "https://$domain"
    private val rateLimitPerSecond = 10 // サービス固有
    private val maxRetryAttempts = 3
    
    // 共通機能
    private val rateLimitManager = RateLimitManager(rateLimitPerSecond)
    private val retryManager = ExponentialBackoffRetry(maxRetryAttempts)
}
```

#### レートリミット共通実装
```kotlin
class RateLimitManager(private val requestsPerSecond: Int) {
    private val requestTimes = ConcurrentLinkedQueue<Long>()
    private val mutex = Mutex()
    
    suspend fun waitForRateLimit() = mutex.withLock {
        val now = System.currentTimeMillis()
        val oneSecondAgo = now - 1000
        
        // 古いリクエストを削除
        while (requestTimes.isNotEmpty() && requestTimes.peek() < oneSecondAgo) {
            requestTimes.poll()
        }
        
        // レート制限チェック
        if (requestTimes.size >= requestsPerSecond) {
            val oldestRequest = requestTimes.peek()
            val waitTime = oldestRequest?.let { (it + 1000) - now } ?: 0L
            if (waitTime > 0) {
                delay(waitTime)
            }
        }
        
        requestTimes.offer(now)
    }
}
```

#### リトライ戦略共通実装
```kotlin
class ExponentialBackoffRetry(
    private val maxAttempts: Int = 3,
    private val initialDelay: Long = 1000,
    private val factor: Double = 2.0,
    private val jitter: Long = 500L
) {
    suspend fun <T> execute(
        shouldRetry: (Exception) -> Boolean = ::defaultShouldRetry,
        action: suspend () -> T
    ): T {
        var lastException: Exception? = null
        
        repeat(maxAttempts) { attempt ->
            try {
                return action()
            } catch (e: Exception) {
                lastException = e
                
                if (attempt == maxAttempts - 1 || !shouldRetry(e)) {
                    throw e
                }
                
                val delay = calculateDelay(attempt)
                delay(delay)
            }
        }
        
        throw lastException ?: IllegalStateException("Unexpected retry state")
    }
    
    private fun calculateDelay(attempt: Int): Long {
        val exponentialDelay = (initialDelay * factor.pow(attempt)).toLong()
        val jitterAmount = Random.nextLong(-jitter, jitter + 1)
        return maxOf(0L, exponentialDelay + jitterAmount)
    }
    
    private fun defaultShouldRetry(e: Exception): Boolean {
        return when (e) {
            is ClientRequestException -> e.response.status == HttpStatusCode.TooManyRequests
            is ServerResponseException -> e.response.status in listOf(
                HttpStatusCode.InternalServerError,
                HttpStatusCode.BadGateway,
                HttpStatusCode.ServiceUnavailable,
                HttpStatusCode.GatewayTimeout
            )
            else -> false
        }
    }
}
```

### ページネーション実装パターン

#### 汎用ページネーションハンドラー
```kotlin
abstract class PaginationHandler<T> {
    
    data class PageInfo(
        val hasNext: Boolean,
        val totalCount: Int?,
        val currentPage: Int
    )
    
    abstract suspend fun fetchPage(page: Int, perPage: Int): Pair<List<T>, PageInfo>
    abstract fun extractPageInfo(response: HttpResponse, items: List<T>, currentPage: Int, perPage: Int): PageInfo
    
    suspend fun fetchAll(
        perPage: Int = 50,
        maxPages: Int = 100, // 無限ループ防止
        onProgress: (List<T>, PageInfo) -> Unit = { _, _ -> }
    ): List<T> {
        val allItems = mutableListOf<T>()
        var currentPage = 1
        var totalRetrieved = 0
        
        while (currentPage <= maxPages) {
            val (items, pageInfo) = fetchPage(currentPage, perPage)
            allItems.addAll(items)
            totalRetrieved += items.size
            
            onProgress(items, pageInfo)
            
            // 無限ループ防止チェック
            if (!pageInfo.hasNext || 
                (pageInfo.totalCount != null && totalRetrieved >= pageInfo.totalCount) ||
                items.isEmpty()) {
                break
            }
            
            currentPage++
        }
        
        return allItems
    }
}
```

### 認証パターン

#### OAuth2認証基盤
```kotlin
abstract class OAuth2HttpClient {
    protected lateinit var httpClient: HttpClient
    
    protected fun createHttpClient(accessToken: String): HttpClient {
        return HttpClient(CIO) {
            install(ContentNegotiation) {
                json(Json {
                    ignoreUnknownKeys = true
                    coerceInputValues = true
                })
            }
            
            install(Auth) {
                bearer {
                    loadTokens { BearerTokens(accessToken, "") }
                }
            }
            
            install(Logging) {
                logger = Logger.DEFAULT
                level = LogLevel.INFO
            }
        }
    }
}
```

#### 認証情報管理
```kotlin
sealed class AuthenticationStrategy {
    data class ApiKey(val key: String) : AuthenticationStrategy()
    data class BearerToken(val token: String) : AuthenticationStrategy()
    data class BasicAuth(val username: String, val password: String) : AuthenticationStrategy()
    data class OAuth2(val accessToken: String, val refreshToken: String? = null) : AuthenticationStrategy()
}

class AuthenticationManager(private val strategy: AuthenticationStrategy) {
    
    fun configureClient(clientBuilder: HttpClientConfig<*>) {
        when (strategy) {
            is AuthenticationStrategy.ApiKey -> {
                clientBuilder.defaultRequest {
                    header("X-API-Key", strategy.key)
                }
            }
            is AuthenticationStrategy.BearerToken -> {
                clientBuilder.install(Auth) {
                    bearer {
                        loadTokens { BearerTokens(strategy.token, "") }
                    }
                }
            }
            is AuthenticationStrategy.BasicAuth -> {
                clientBuilder.install(Auth) {
                    basic {
                        credentials {
                            BasicAuthCredentials(strategy.username, strategy.password)
                        }
                    }
                }
            }
            is AuthenticationStrategy.OAuth2 -> {
                clientBuilder.install(Auth) {
                    bearer {
                        loadTokens { 
                            BearerTokens(strategy.accessToken, strategy.refreshToken ?: "") 
                        }
                    }
                }
            }
        }
    }
}
```

### ゲートウェイパターン実装

#### 抽象ゲートウェイクラス
```kotlin
abstract class SaaSConnectorGateway(
    protected val context: ContextData,
    protected val connection: Connection,
    protected val authentication: Authentication,
    protected val parameters: Map<String, Any>
) : ConnectorGateway(context, connection, authentication, parameters) {
    
    protected abstract val serviceName: String
    protected abstract val defaultDomain: String
    
    protected abstract fun createClient(): Any
    protected abstract fun extractCredentials(): Map<String, String>
    protected abstract fun validateConfiguration()
    
    override suspend fun initialize(): ConnectorGateway {
        validateConfiguration()
        createClient()
        return this
    }
    
    protected fun getCustomDomain(): String {
        return connection.connector.customDomain 
            ?: throw IllegalArgumentException("${serviceName}ドメインが設定されていません")
    }
    
    protected fun getCredentials(): Map<String, String> {
        val credentialsAuth = authentication as? CredentialsAuthentication
            ?: throw IllegalArgumentException("認証情報が正しく設定されていません")
        
        return credentialsAuth.credentials.jsonToMap().mapValues { it.value.toString() }
    }
}
```

### フロントエンド実装パターン

#### コネクタ登録テンプレート
```typescript
// Connector.ts
export const AC_CONNECTORS_UUID_DICT = {
    // 既存のコネクタ
    serviceX: OptionId('new-uuid-here'.uuidToBase64()),
    // ...
}

// 認証タイプ別グループ化
export const OAUTH2_CONNECTORS = [
    AC_CONNECTORS_UUID_DICT.serviceX,
    // OAuth2を使用するコネクタ
]

export const API_KEY_CONNECTORS = [
    // APIキーを使用するコネクタ
]

export const PASSWORDLESS_ASSETS = [
    AC_CONNECTORS_UUID_DICT.serviceX,
    // パスワードレス認証をサポートするコネクタ
]
```

#### 属性マッピング設定パターン
```typescript
// ConnectionPasswordSetting.vue
function getDefaultAttributeMapping(connectorUUID: string) {
    if (connectorUUID === AC_CONNECTORS_UUID_DICT.serviceX) {
        return [
            // 基本属性
            {
                attributeKey: 'user.id',
                attributeExpression: 'user.externalId',
            },
            {
                attributeKey: 'user.email',
                attributeExpression: 'user.email',
            },
            // 名前関連
            {
                attributeKey: 'user.last_name',
                attributeExpression: 'user.familyName',
            },
            {
                attributeKey: 'user.first_name',
                attributeExpression: 'user.givenName',
            },
            // ステータス
            {
                attributeKey: 'user.status',
                attributeExpression: 'user.accountStatus',
            }
        ];
    }
    // デフォルト
    return [];
}
```

#### 国際化対応パターン
```yaml
# i18n.yml
connector:
  credential:
    # 基本認証方式
    apiKey: API Key / APIキー
    accessToken: Access Token / アクセストークン
    clientId: Client ID / クライアントID
    clientSecret: Client Secret / クライアントシークレット
    
    # サービス固有
    subdomain: Subdomain / サブドメイン
    tenantId: Tenant ID / テナントID
    organizationId: Organization ID / 組織ID
```

### テストパターン

#### 共通テストベースクラス
```kotlin
abstract class SaaSConnectorTestBase<T : Any> {
    
    protected abstract fun createClient(mockHttpClient: HttpClient): T
    protected abstract fun createMockSuccessResponse(): String
    protected abstract fun createMockErrorResponse(): String
    
    @Test
    fun shouldHandleSuccessfulResponse() {
        // Given
        val mockEngine = MockEngine { 
            respond(
                content = createMockSuccessResponse(),
                status = HttpStatusCode.OK,
                headers = headersOf("Content-Type" to "application/json")
            )
        }
        val client = createClient(HttpClient(mockEngine))
        
        // When & Then
        // 具体的なテストは子クラスで実装
    }
    
    @ParameterizedTest
    @ValueSource(ints = [429, 500, 502, 503, 504])
    fun shouldRetryOnRetryableErrors(statusCode: Int) {
        // リトライ可能エラーのテスト
    }
    
    @ParameterizedTest
    @ValueSource(ints = [400, 401, 403, 404])
    fun shouldNotRetryOnClientErrors(statusCode: Int) {
        // リトライしないエラーのテスト
    }
}
```

## 実装例

### 完全なコネクタ実装例
```kotlin
// 1. APIクライアント
class ExampleSaaSClient(
    domain: String,
    accessToken: String
) : OAuth2HttpClient() {
    
    private val baseUrl = "https://$domain.example.com"
    private val rateLimitManager = RateLimitManager(requestsPerSecond = 100)
    private val retryManager = ExponentialBackoffRetry()
    
    suspend fun listUsers(): List<ExampleUser> {
        rateLimitManager.waitForRateLimit()
        
        return retryManager.execute {
            val response = httpClient.get("$baseUrl/api/v1/users")
            response.body<ExampleUsersResponse>().users
        }
    }
}

// 2. ゲートウェイ
class ExampleSaaSConnectorGateway(
    context: ContextData,
    connection: Connection,
    authentication: Authentication,
    parameters: Map<String, Any>
) : SaaSConnectorGateway(context, connection, authentication, parameters) {
    
    override val serviceName = "ExampleSaaS"
    override val defaultDomain = ".example.com"
    
    private lateinit var client: ExampleSaaSClient
    
    override fun createClient() {
        val domain = getCustomDomain()
        val credentials = getCredentials()
        val accessToken = credentials["accessToken"] ?: 
            throw IllegalArgumentException("Access token is required")
        
        client = ExampleSaaSClient("$domain$defaultDomain", accessToken)
    }
    
    override fun extractCredentials(): Map<String, String> = getCredentials()
    override fun validateConfiguration() {
        getCustomDomain()
        getCredentials()
    }
}
```

## 関連事項

### 設定管理パターン
- Cloud Build: 安定版ツールの使用（Kaniko v1.9.1）
- 環境変数: サービス固有設定の外部化
- ドキュメント: 階層構造による整理（docs/specifications/features/connectors/{service}/）

### 監視・運用パターン
- ログ出力: 構造化ログによる運用性向上
- メトリクス: リクエスト数、エラー率、レスポンス時間の収集
- アラート: レート制限到達、連続エラー発生の通知

### セキュリティパターン
- 認証情報: 暗号化された設定での管理
- 通信: HTTPS必須、証明書検証
- ログ: 認証情報のマスキング

検索キーワード: saas-connector, api-client, oauth2, rate-limiting, retry-pattern, pagination, gateway-pattern, frontend-integration, testing-patterns, kotlin, vue, typescript