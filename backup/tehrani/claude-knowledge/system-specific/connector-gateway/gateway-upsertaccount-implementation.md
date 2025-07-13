# ConnectorGateway upsertAccount実装ガイド

タグ: #技術/Kotlin #機能/アカウント管理 #用途/実装ガイド #重要度/高

## 概要

YESOD ConnectorGatewayにおけるupsertAccountメソッドの実装パターンと必須要素を解説する。upsertAccountはアカウントの作成と更新を一つのメソッドで行う重要な機能である。

## 詳細

### 基本実装フロー

upsertAccountの実装は以下の基本フローに従う：

1. **リクエストからエンティティを取得**
   ```kotlin
   val entity = request.entity
   ```

2. **属性マッピングの実行**
   ```kotlin
   val attributeMappings = connection.listAttributeMappings(excludePassword).map { it.toV1() }
   val mapping = EntityExpressionMapping(context, attributeMappings, parameters).extract(entity)
   val userMapping = mapping["user"] as? Map<String, Any?>
       ?: throw IllegalArgumentException("属性Mapping情報にuserが見つかりません")
   ```

3. **既存アカウントの検索**
   - メールアドレスまたはユーザー名をキーとして検索
   - 各SaaSのAPIクライアントを使用

4. **条件分岐による処理**
   - アカウントが存在しない場合：新規作成
   - アカウントが存在する場合：更新

5. **レスポンスの返却**
   ```kotlin
   return ConnectorResponse(null, UpsertAccountResponse(...))
   ```

### 必須要素

#### 1. メソッドシグネチャ
```kotlin
override suspend fun upsertAccount(request: UpsertAccountRequest): ConnectorResponse<UpsertAccountResponse>
```

#### 2. エンティティと属性マッピング
- `request.entity`から`ReadableEntity`を取得
- `EntityExpressionMapping`を使用して属性を抽出
- 属性マッピングが見つからない場合は`IllegalArgumentException`をスロー

#### 3. アカウント検索ロジック
- メールアドレスベース（Google Workspace、Okta）
- ユーザー名ベース（SCIMv2）
- ユーザープリンシパル名ベース（Azure AD）

#### 4. レスポンスメッセージ
- 新規作成: `"OK - アカウントを新規作成しました。ID: {id}"`
- 更新: `"OK - 既存のアカウントが見つかったため、アカウントを更新しました。ID: {id}"`
- 特殊ケース（削除済み復元）: `"OK - 削除されたアカウントを復元しました。ID: {id}"`

### エラーハンドリング

#### 1. 属性マッピングエラー
```kotlin
?: throw IllegalArgumentException("属性Mapping情報にuserが見つかりません")
```

#### 2. API例外の処理
```kotlin
runCatching {
    // API呼び出し
}.fold(
    onSuccess = { /* 成功処理 */ },
    onFailure = { e ->
        when {
            e is ApiException && e.responseStatusCode == 404 -> {
                // Not Found処理
            }
            e is ApiException && e.responseStatusCode == 409 -> {
                // Conflict処理（既に存在）
            }
            else -> throw e
        }
    }
)
```

### パスワード処理の重要ポイント

1. **新規作成時**: パスワードを含む（`removePassword = false`）
2. **更新時**: パスワードを除外（`removePassword = true`）
3. **レスポンス**: 新規作成時のみ`accountRawPassword`に値を設定

## 実装例

### Azure AD実装例（削除済みユーザーの復元機能付き）

```kotlin
override suspend fun upsertAccount(request: UpsertAccountRequest): ConnectorResponse<UpsertAccountResponse> {
    val yesodMemberEntity = request.entity
    val userDto = userDtoFromMember(yesodMemberEntity, true)
    val azureUser = azureClient.findUserById(userDto.userPrincipalName)
    
    val upsertedAccount = if (azureUser == null) {
        // 削除済みユーザーの検索と復元を試みる
        val azureDeletedUser = azureClient.listAllDeletedUsers(
            attributes = listOf("id", "userPrincipalName", "displayName", "accountEnabled"),
            filter = "endswith(userPrincipalName,'${userDto.userPrincipalName}') and displayName eq '${userDto.displayName}'",
            count = true,
            headers = mapOf("ConsistencyLevel" to "eventual")
        ).singleOrNull { user -> user.userPrincipalName == user.id.replace("-", "") + userDto.userPrincipalName }
        
        if (azureDeletedUser != null) {
            // 削除からの復元
            val accountId = checkNotNull(azureDeletedUser.id)
            azureClient.restoreDeletedItem(accountId)
            UpsertAccountResponse(
                message = "OK - 削除されたアカウントを復元しました。ID: ${azureDeletedUser.id}",
                accountResponse = azureDeletedUser.toAccountResponse(entityId = yesodMemberEntity.entityId),
                accountRawPassword = null
            )
        } else {
            // 新規作成
            val dto = userDtoFromMember(yesodMemberEntity, false)
            val creatingUser = AzureAdAttributeMapper().mapUserFromDto(dto)
            creatingUser.accountEnabled = true
            val createdUser = azureClient.createUser(creatingUser)
            UpsertAccountResponse(
                message = "OK - アカウントを新規作成しました。ID: ${createdUser.id}",
                accountResponse = createdUser.toAccountResponse(entityId = yesodMemberEntity.entityId),
                accountRawPassword = dto.password
            )
        }
    } else {
        // 更新
        val accountId = checkNotNull(azureUser.id)
        val dto = userDtoFromMember(yesodMemberEntity, true)
        val updatingUser = AzureAdAttributeMapper().mapUserFromDto(dto)
        updatingUser.id = accountId
        updatingUser.accountEnabled = true
        azureClient.updateUser(accountId, updatingUser)
        UpsertAccountResponse(
            message = "OK - 既存のアカウントが見つかったため、アカウントを更新しました。ID: $accountId",
            accountResponse = updatingUser.toAccountResponse(entityId = yesodMemberEntity.entityId),
            accountRawPassword = null
        )
    }
    
    return ConnectorResponse(null, upsertedAccount)
}
```

### SCIMv2実装例（拡張ポイント付き）

```kotlin
override suspend fun upsertAccount(request: UpsertAccountRequest): ConnectorResponse<UpsertAccountResponse> {
    val entity = request.entity
    val attributeMappings = connection.listAttributeMappings(true).map { it.toV1() }
    val mapping = EntityExpressionMapping(context, attributeMappings, parameters).extract(entity)
    val user = mapping["user"] as? Map<String, Any?>
        ?: throw IllegalArgumentException("属性Mapping情報にuserが見つかりません")
    
    val userName = user["userName"] as? String
        ?: throw IllegalArgumentException("属性Mapping情報にuserNameが見つかりません")
    
    val existingUser = findUserByUsername(userName)
    
    return if (existingUser == null) {
        createNewUser(request, user)
    } else {
        updateExistingUser(request, existingUser, user)
    }
}

private suspend fun createNewUser(
    request: UpsertAccountRequest,
    user: Map<String, Any?>
): ConnectorResponse<UpsertAccountResponse> {
    beforeCreateUser(request, user)
    // 新規作成処理
    val createdUser = scimClient.createUser(user)
    return ConnectorResponse(null, UpsertAccountResponse(
        message = "OK - アカウントを新規作成しました。ID: ${createdUser.id}",
        accountResponse = createdUser.toAccountResponse(request.entity.entityId),
        accountRawPassword = user["password"] as? String
    ))
}

private suspend fun updateExistingUser(
    request: UpsertAccountRequest,
    existingUser: ScimUser,
    user: Map<String, Any?>
): ConnectorResponse<UpsertAccountResponse> {
    beforeUpdateUser(request, existingUser, user)
    // 更新処理（パスワードを除外）
    val updateUser = user.filterKeys { it != "password" }
    val updatedUser = scimClient.updateUser(existingUser.id, updateUser)
    return ConnectorResponse(null, UpsertAccountResponse(
        message = "OK - 既存のアカウントが見つかったため、アカウントを更新しました。ID: ${updatedUser.id}",
        accountResponse = updatedUser.toAccountResponse(request.entity.entityId),
        accountRawPassword = null
    ))
}
```

## 関連事項

### 関連クラス・インターフェース
- `ConnectorGateway`: 基底抽象クラス
- `UpsertAccountRequest`: リクエストデータクラス
- `UpsertAccountResponse`: レスポンスデータクラス
- `EntityExpressionMapping`: 属性マッピング処理クラス
- `ReadableEntity`: エンティティインターフェース

### 関連メソッド
- `updateAccounts`: 複数アカウントの一括更新
- `deactivateAccount`: アカウントの無効化
- `resetAccountPassword`: パスワードリセット

### SmartHR実装時の注意点
1. SmartHR APIの特性に合わせた実装が必要
2. 従業員番号をキーとした検索が一般的
3. 部署・役職などの関連情報も同時に更新する場合がある
4. APIレート制限に注意

### テスト実装の推奨事項
1. 新規作成・更新の両パスをテスト
2. 属性マッピングエラーのテスト
3. API例外処理のテスト
4. パスワード処理の確認

検索キーワード: connector-gateway, upsert-account, kotlin, smarthr, azure-ad, scim, implementation, account-management, entity-mapping, oauth