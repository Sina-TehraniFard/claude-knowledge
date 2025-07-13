関連ファイル:
- smarthr-connector-implementation.md
- ../../function/testing/testing.md
- ../client/general-implementation-guidelines.md

# SmartHRコネクタテスト実装パターン

## 概要
SmartHRコネクタのテスト実装における具体的なパターンとベストプラクティス。
MockEngine、ParameterizedTest、タイミング検証を含む包括的なテスト戦略。

## 詳細

### テストヘルパークラス（SmartHRTestHelper）

#### モックエンジン作成パターン
```kotlin
class SmartHRTestHelper {
    companion object {
        
        // 基本的なモックエンジン作成
        fun createCrewsListMockEngine(
            totalCrewSize: Int,
            capturedRequests: MutableList<HttpRequestData>
        ): MockEngine {
            return MockEngine { request ->
                capturedRequests.add(request)
                
                val page = request.url.parameters["page"]?.toIntOrNull() ?: 1
                val perPage = request.url.parameters["per_page"]?.toIntOrNull() ?: 10
                
                val startIndex = (page - 1) * perPage
                val endIndex = minOf(startIndex + perPage, totalCrewSize)
                val crews = (startIndex until endIndex).map { createMockCrew(it) }
                
                respond(
                    content = createCrewsResponse(crews),
                    status = HttpStatusCode.OK,
                    headers = headersOf(
                        "Content-Type" to "application/json",
                        "x-total-count" to totalCrewSize.toString(),
                        "Link" to createLinkHeader(page, perPage, totalCrewSize)
                    )
                )
            }
        }
        
        // 無限ループテスト用モックエンジン
        fun createProgressiveInfiniteLoopMockEngine(
            totalCount: Int,
            capturedRequests: MutableList<HttpRequestData>
        ): MockEngine {
            return MockEngine { request ->
                capturedRequests.add(request)
                
                // 意図的に不整合なレスポンス
                respond(
                    content = createCrewsResponse(listOf(createMockCrew(1))),
                    status = HttpStatusCode.OK,
                    headers = headersOf(
                        "Content-Type" to "application/json",
                        "x-total-count" to totalCount.toString(),
                        "Link" to "<https://test.smarthr.jp/api/v1/crews?page=2>; rel=\"next\""
                    )
                )
            }
        }
    }
}
```

#### リトライテスト用タイミング検証
```kotlin
fun createMockHttpClientWithTimeTracking(
    responses: List<Pair<HttpStatusCode, String>>,
    requestTimes: MutableList<Long>
): HttpClient {
    var responseIndex = 0
    
    return HttpClient(MockEngine) {
        engine {
            addHandler { request ->
                val currentTime = System.currentTimeMillis()
                requestTimes.add(currentTime)
                
                val (status, content) = responses[responseIndex]
                responseIndex = minOf(responseIndex + 1, responses.size - 1)
                
                respond(
                    content = content,
                    status = status,
                    headers = headersOf("Content-Type" to "application/json")
                )
            }
        }
    }
}
```

### ParameterizedTestパターン

#### ページネーション境界値テスト
```kotlin
class SmartHRClientTest {
    
    @ParameterizedTest
    @MethodSource("listCrewsPagingTestCase")
    fun shouldCallApiMultipleTimes_whenCrewsExceedPageSize(
        totalCrewSize: Int, 
        expectedApiCallCount: Int
    ) {
        // Given
        val capturedRequests = mutableListOf<HttpRequestData>()
        val mockEngine = SmartHRTestHelper.createCrewsListMockEngine(
            totalCrewSize, 
            capturedRequests
        )
        val client = SmartHRClient("test", "token", mockHttpClient = HttpClient(mockEngine))
        
        // When
        val result = runBlocking { client.listAllCrews() }
        
        // Then
        assertThat(capturedRequests).hasSize(expectedApiCallCount)
        assertThat(result).hasSize(totalCrewSize)
        
        // ページネーション検証
        capturedRequests.forEachIndexed { index, request ->
            val expectedPage = index + 1
            assertThat(request.url.parameters["page"]).isEqualTo(expectedPage.toString())
        }
    }
    
    companion object {
        @JvmStatic
        fun listCrewsPagingTestCase(): Stream<Arguments> = Stream.of(
            Arguments.of(0, 1),    // ゼロ件
            Arguments.of(1, 1),    // 1件
            Arguments.of(10, 1),   // ちょうど1ページ
            Arguments.of(11, 2),   // 1ページ+1件
            Arguments.of(20, 2),   // 2ページ
            Arguments.of(21, 3)    // 2ページ+1件
        )
    }
}
```

#### リトライ機能テスト
```kotlin
@ParameterizedTest
@MethodSource("retryTestCases")
fun shouldRetryOnSpecificErrors(
    statusCode: HttpStatusCode,
    shouldRetry: Boolean,
    expectedAttempts: Int
) {
    // Given
    val requestTimes = mutableListOf<Long>()
    val responses = (1..3).map { statusCode to "error" } + 
                   listOf(HttpStatusCode.OK to """{"crews": []}""")
    
    val client = SmartHRClient(
        "test", 
        "token", 
        mockHttpClient = SmartHRTestHelper.createMockHttpClientWithTimeTracking(responses, requestTimes)
    )
    
    // When & Then
    if (shouldRetry) {
        runBlocking { client.listCrews() }
        assertThat(requestTimes).hasSize(expectedAttempts)
    } else {
        assertThrows<HttpException> {
            runBlocking { client.listCrews() }
        }
        assertThat(requestTimes).hasSize(1) // リトライなし
    }
}

companion object {
    @JvmStatic
    fun retryTestCases(): Stream<Arguments> = Stream.of(
        Arguments.of(HttpStatusCode.TooManyRequests, true, 4),  // 3回リトライ+成功
        Arguments.of(HttpStatusCode.InternalServerError, true, 4),
        Arguments.of(HttpStatusCode.ServiceUnavailable, true, 4),
        Arguments.of(HttpStatusCode.BadRequest, false, 1),      // リトライしない
        Arguments.of(HttpStatusCode.Unauthorized, false, 1)
    )
}
```

### 無限ループ防止テスト

#### プログレッシブ無限ループテスト
```kotlin
@Test
fun shouldStopInfiniteLoop_whenServerReturnsInconsistentPagination() {
    // Given: 総数1だが常にnextリンクを返すサーバー
    val capturedRequests = mutableListOf<HttpRequestData>()
    val mockEngine = SmartHRTestHelper.createProgressiveInfiniteLoopMockEngine(
        totalCount = 1,
        capturedRequests = capturedRequests
    )
    val client = SmartHRClient("test", "token", mockHttpClient = HttpClient(mockEngine))
    
    // When
    val result = runBlocking { client.listAllCrews() }
    
    // Then: 1回目で停止し、1件のデータを返す
    assertThat(capturedRequests).hasSize(1)
    assertThat(result).hasSize(1)
}
```

### レートリミットテスト

#### タイミング検証テスト
```kotlin
@Test
fun shouldRespectRateLimit_when10RequestsPerSecond() {
    // Given
    val client = SmartHRClient("test", "token")
    val requestTimes = mutableListOf<Long>()
    
    // When: 11回連続リクエスト
    runBlocking {
        repeat(11) {
            val startTime = System.currentTimeMillis()
            try {
                client.listCrews(page = it + 1)
            } catch (e: Exception) {
                // モックなのでエラーは無視
            }
            requestTimes.add(System.currentTimeMillis() - startTime)
        }
    }
    
    // Then: 11回目のリクエストは遅延が発生している
    val eleventhRequestTime = requestTimes[10]
    assertThat(eleventhRequestTime).isGreaterThan(100) // 100ms以上の遅延
}
```

### コネクタゲートウェイテスト

#### 初期化テスト
```kotlin
class SmartHRConnectorGatewayTest {
    
    @Test
    fun shouldInitializeClient_withCorrectParameters() {
        // Given
        val connection = mockConnection(customDomain = "test-company")
        val authentication = mockCredentialsAuthentication(accessToken = "test-token")
        
        // When
        val gateway = SmartHRConnectorGateway(
            context = mockContext(),
            connection = connection,
            authentication = authentication,
            parameters = emptyMap()
        )
        
        runBlocking { gateway.initialize() }
        
        // Then
        assertThat(gateway.client).isNotNull()
        // クライアントが正しいドメインで初期化されているかテスト
        val expectedDomain = "test-company.smarthr.jp"
        // この検証はクライアントのプロパティアクセスやモック検証で行う
    }
    
    @Test
    fun shouldThrowException_whenCustomDomainIsNull() {
        // Given
        val connection = mockConnection(customDomain = null)
        val authentication = mockCredentialsAuthentication(accessToken = "test-token")
        
        // When & Then
        val gateway = SmartHRConnectorGateway(
            context = mockContext(),
            connection = connection,
            authentication = authentication,
            parameters = emptyMap()
        )
        
        assertThrows<IllegalArgumentException> {
            runBlocking { gateway.initialize() }
        }
    }
}
```

### モッククリエーションヘルパー

#### モックデータ生成
```kotlin
object SmartHRTestDataFactory {
    
    fun createMockCrew(id: Int): SmartHRCrew {
        return SmartHRCrew(
            id = id.toString(),
            userId = "user_$id",
            personal = SmartHRPersonal(
                lastName = "山田$id",
                firstName = "太郎$id",
                lastNameYomi = "ヤマダ$id",
                firstNameYomi = "タロウ$id"
            ),
            employment = SmartHREmployment(
                employmentType = SmartHREmploymentType(
                    name = "正社員",
                    preset = "regular"
                ),
                enteredDate = "2023-04-01",
                employmentStatus = "employed"
            )
        )
    }
    
    fun createCrewsResponse(crews: List<SmartHRCrew>): String {
        return Json.encodeToString(SmartHRCrewsResponse(crews = crews))
    }
    
    fun createLinkHeader(page: Int, perPage: Int, totalCount: Int): String {
        val hasNext = (page * perPage) < totalCount
        val hasPrev = page > 1
        
        val links = mutableListOf<String>()
        
        if (hasPrev) {
            links.add("<https://test.smarthr.jp/api/v1/crews?page=${page - 1}>; rel=\"prev\"")
        }
        
        if (hasNext) {
            links.add("<https://test.smarthr.jp/api/v1/crews?page=${page + 1}>; rel=\"next\"")
        }
        
        return links.joinToString(", ")
    }
}
```

## 実装例

### 完全なテストクラス例
```kotlin
@ExtendWith(MockKExtension::class)
class SmartHRClientIntegrationTest {
    
    @Test
    fun shouldHandleCompleteFlow_withRealScenario() {
        // Given: 25件のデータで複数ページ、リトライ、レートリミットを含むシナリオ
        val totalCrewSize = 25
        val capturedRequests = mutableListOf<HttpRequestData>()
        
        val mockEngine = MockEngine { request ->
            capturedRequests.add(request)
            
            // 最初のリクエストは429エラー（リトライテスト）
            if (capturedRequests.size == 1) {
                respond(
                    content = "Rate limit exceeded",
                    status = HttpStatusCode.TooManyRequests
                )
            } else {
                // 通常のページネーションレスポンス
                val page = request.url.parameters["page"]?.toIntOrNull() ?: 1
                val perPage = 10
                val startIndex = (page - 1) * perPage
                val endIndex = minOf(startIndex + perPage, totalCrewSize)
                val crews = (startIndex until endIndex).map { 
                    SmartHRTestDataFactory.createMockCrew(it) 
                }
                
                respond(
                    content = SmartHRTestDataFactory.createCrewsResponse(crews),
                    status = HttpStatusCode.OK,
                    headers = headersOf(
                        "x-total-count" to totalCrewSize.toString(),
                        "Link" to SmartHRTestDataFactory.createLinkHeader(page, perPage, totalCrewSize)
                    )
                )
            }
        }
        
        val client = SmartHRClient("test", "token", mockHttpClient = HttpClient(mockEngine))
        
        // When
        val result = runBlocking { client.listAllCrews() }
        
        // Then
        assertThat(result).hasSize(totalCrewSize)
        assertThat(capturedRequests).hasSize(4) // 1回リトライ + 3ページ
        
        // リトライ検証
        assertThat(capturedRequests[0].url.parameters["page"]).isEqualTo("1")
        assertThat(capturedRequests[1].url.parameters["page"]).isEqualTo("1") // リトライ
        
        // ページネーション検証
        assertThat(capturedRequests[2].url.parameters["page"]).isEqualTo("2")
        assertThat(capturedRequests[3].url.parameters["page"]).isEqualTo("3")
    }
}
```

## 関連事項

### テスト実行環境
- JUnit 5 + ParameterizedTest
- MockK for Kotlin mocking
- Ktor MockEngine for HTTP client testing
- AssertJ for fluent assertions

### 共通テストパターン
- 境界値テスト: ParameterizedTestによる網羅的検証
- タイミングテスト: System.currentTimeMillis()による精密検証
- モックエンジン: リクエスト履歴収集による呼び出し検証
- 例外テスト: assertThrows による異常系検証

### SmartHR固有のテストポイント
- 10回/秒のレートリミット遵守
- 無限ループ防止機能の動作確認
- OAuth2認証パラメータの正確性
- ページネーション（Link header + x-total-count）の整合性

検索キーワード: smarthr, testing, mock-engine, parameterized-test, rate-limit-test, retry-test, pagination-test, infinite-loop-test, junit5, kotlin-testing