関連ファイル:
- ../client/general-implementation-guidelines.md
- ../connector-gateway/yesod-connector-patterns.md
- ../../function/implementation/CLAUDE.md

# SmartHRコネクタ実装詳細

## 概要
YesodシステムにおけるSmartHRコネクタの具体的な実装パターンと設計思想。
OAuth2認証、レートリミット、無限ループ防止機能を含む企業向けSaaS連携の標準実装。

## 詳細

### APIクライアント実装（SmartHRClient.kt）

#### 基本構造
```kotlin
class SmartHRClient(
    domain: String,
    apiAccessToken: String
) : OAuth2HttpClient() {
    
    init {
        require(domain.isNotBlank()) { ERROR_MESSAGE_DOMAIN_REQUIRED }
        require(apiAccessToken.isNotBlank()) { ERROR_MESSAGE_TOKEN_REQUIRED }
    }
    
    // SmartHR固有設定
    private val customSecondLevelDomain = ".smarthr.jp"
    private val rateLimitPerSecond = 10
}
```

#### レートリミット実装
```kotlin
private val requestTimes = ConcurrentLinkedQueue<Long>()
private val rateLimitMutex = Mutex()

private suspend fun waitForRateLimit() = rateLimitMutex.withLock {
    val now = System.currentTimeMillis()
    val oneSecondAgo = now - 1000
    
    // 過去1秒のリクエスト履歴管理
    while (requestTimes.isNotEmpty()) {
        val oldestRequest = requestTimes.peek() ?: break
        if (oldestRequest < oneSecondAgo) {
            requestTimes.poll()
        } else {
            break
        }
    }
    
    // SmartHR API制限（10回/秒）判定と待機
    val waitTime = if (requestTimes.size >= RATE_LIMIT_PER_SECOND) {
        val oldestRequest = requestTimes.peek()
        oldestRequest?.let { (it + 1000) - now } ?: 0L
    } else 0L
    
    if (waitTime > 0) {
        logger.info("Rate limit reached. Waiting ${waitTime}ms")
        delay(waitTime)
    }
    
    requestTimes.offer(now)
}
```

#### リトライ戦略
```kotlin
private val retry = ExponentialBackoffRetry(
    maxAttempts = 3,
    initialDelay = 1000,
    factor = 2.0,
    jitter = 500L,
    shouldRetry = { e ->
        when (e) {
            is ClientRequestException -> e.response.status == HttpStatusCode.TooManyRequests
            is ServerResponseException -> e.response.status in listOf(
                HttpStatusCode.InternalServerError,
                HttpStatusCode.ServiceUnavailable
            )
            else -> false
        }
    }
)
```

### ページネーション実装

#### 無限ループ防止機能
```kotlin
private fun determineHasNextPage(
    httpResponse: HttpResponse,
    currentPage: Int,
    perPage: Int,
    responseSize: Int,
    totalRetrievedItems: Int
): Boolean {
    val totalCount = httpResponse.headers[HEADER_TOTAL_COUNT]?.toIntOrNull()
    
    // 無限ループ防止: 取得済みアイテム数が総数を超えた場合
    if (totalCount != null && totalRetrievedItems > totalCount) {
        logger.error("無限ループを検出しました。取得停止します。")
        return false
    }
    
    // rel="next"判定
    val linkHeader = httpResponse.headers[HEADER_LINK]
    if (linkHeader != null) {
        val hasRelNext = linkHeader.contains(HEADER_REL_NEXT)
        if (hasRelNext && totalCount != null && totalRetrievedItems >= totalCount) {
            logger.error("無限ループを検出しました。Linkヘッダーにnextがありますが総数に達しています。")
            return false
        }
        return hasRelNext
    }
    
    // フォールバック: レスポンスサイズとページサイズでの判定
    return responseSize >= perPage && totalRetrievedItems < (totalCount ?: Int.MAX_VALUE)
}
```

### ゲートウェイパターン実装

#### SmartHRConnectorGateway
```kotlin
class SmartHRConnectorGateway(
    context: ContextData,
    connection: Connection,
    authentication: Authentication,
    parameters: Map<String, Any>,
    _client: SmartHRClient? = null // テスト用依存性注入
) : ConnectorGateway(...) {
    
    override suspend fun initialize(): ConnectorGateway {
        val customDomain = connection.connector.customDomain
            ?: throw IllegalArgumentException("SmartHRドメインが設定されていません")
        val domain = "$customDomain$customSecondLevelDomain"
        
        val credentialsAuth = authentication as CredentialsAuthentication
        val apiAccessToken = credentialsAuth.credentials.jsonToMap().getValue("accessToken") as String
        
        client = SmartHRClient(domain, apiAccessToken)
        client.initialize()
        
        return this
    }
}
```

### モデルクラス設計

#### ドメインモデル分離パターン
```kotlin
// メインモデル
@Serializable
@JsonIgnoreProperties(ignoreUnknown = true)
data class SmartHRCrew(
    val id: String,
    @SerialName("user_id")
    val userId: String? = null,
    val personal: SmartHRPersonal? = null,
    val employment: SmartHREmployment? = null,
    val customFields: List<SmartHRCustomField>? = null
)

// 分離されたドメインモデル
data class SmartHREmployment(
    val employmentType: SmartHREmploymentType? = null,
    val enteredDate: String? = null,
    val employmentStatus: String? = null
)

data class SmartHRPersonal(
    val lastName: String? = null,
    val firstName: String? = null,
    val lastNameYomi: String? = null,
    val firstNameYomi: String? = null
)
```

### フロントエンド実装

#### コネクタUUID設定
```typescript
// Connector.ts
export const AC_CONNECTORS_UUID_DICT = {
    smartHr: OptionId('75f90c4a-82a3-41b0-a055-65cad63d6cb4'.uuidToBase64()),
    // ...他のコネクタ
}

// パスワードレス認証対象
export const PASSWORDLESS_ASSETS = [
    AC_CONNECTORS_UUID_DICT.smartHr,
    // ...他のパスワードレスコネクタ
]
```

#### 属性マッピング設定
```javascript
// ConnectionPasswordSetting.vue
if (connectorUUID === AC_CONNECTORS_UUID_DICT.smartHr) {
  return [
    {
      attributeKey: 'user.emp_status',
      attributeExpression: 'user.enrollment',
    },
    {
      attributeKey: 'user.last_name',
      attributeExpression: 'user.familyNameLocalPreferred',
    },
    {
      attributeKey: 'user.first_name',
      attributeExpression: 'user.givenNameLocalPreferred',
    },
    // ...その他の属性マッピング
  ];
}
```

## 実装例

### 完全なAPI呼び出し例
```kotlin
suspend fun listCrews(page: Int = 1, perPage: Int = 10): SmartHRCrewsResponse {
    waitForRateLimit() // レートリミット対応
    
    return retry.execute {
        val response = httpClient.get("$baseUrl/api/v1/crews") {
            parameter("page", page)
            parameter("per_page", perPage)
        }
        
        if (response.status.isSuccess()) {
            response.body<SmartHRCrewsResponse>()
        } else {
            throw HttpException(response.status, response.bodyAsText())
        }
    }
}
```

### テスト実装パターン
```kotlin
@ParameterizedTest
@MethodSource("listCrewsPagingTestCase")
fun shouldCallApiMultipleTimes_whenCrewsExceedPageSize(
    totalCrewSize: Int, 
    expectedApiCallCount: Int
) {
    val capturedRequests = mutableListOf<HttpRequestData>()
    val mockEngine = SmartHRTestHelper.createCrewsListMockEngine(
        totalCrewSize, 
        capturedRequests
    )
    
    val client = SmartHRClient("test", "token", mockHttpClient = HttpClient(mockEngine))
    
    // 実行とアサーション
    val result = runBlocking { client.listAllCrews() }
    
    assertThat(capturedRequests).hasSize(expectedApiCallCount)
    assertThat(result).hasSize(totalCrewSize)
}
```

## 関連事項

### 設定ファイル更新
- Cloud Build: Kanikoバージョン v1.9.1 を使用（安定版）
- 国際化: 日英両対応での`accessToken`追加
- ドキュメント: `docs/specifications/features/connectors/smarthr/` 構造

### 他コネクタとの共通パターン
- OAuth2HttpClient継承による認証基盤
- ExponentialBackoffRetryによるリトライ機能
- ConnectorGatewayパターンの活用
- MockEngineベースのテスト基盤

### SmartHR固有設定
- APIエンドポイント: `/api/v1/crews`
- レート制限: 10回/秒
- ドメイン形式: `{customDomain}.smarthr.jp`
- 認証: Bearer Token (OAuth2)

検索キーワード: smarthr, connector, oauth2, rate-limit, retry, pagination, infinite-loop-prevention, kotlin, vue, typescript, gateway-pattern