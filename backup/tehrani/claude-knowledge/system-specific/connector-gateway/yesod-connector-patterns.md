# YESODのSaaSコネクター開発パターン

## 概要
YESODプロジェクトにおけるSaaSコネクター開発の標準実装パターン。SmartHRコネクター実装から抽出したシステム固有の設計・実装ガイドライン。

## YESODアーキテクチャ構成

### コネクターゲートウェイ層
- YESODドメインモデルへの変換
- ConnectorGateway基底クラスの継承
- ビジネスロジックの実装
- エラーハンドリング

### YESOD固有認証実装
#### APIトークン認証（YESOD方式）
```kotlin
val credentialsAuth = authentication as CredentialsAuthentication
val apiToken = credentialsAuth.credentials.jsonToMap().getValue("accessToken") as String
```

#### カスタムドメイン対応（YESOD仕様）
```kotlin
val customDomain = connection.connector.customDomain
    ?: throw IllegalArgumentException("ドメインが設定されていません")
val domain = "$customDomain$customSecondLevelDomain"
```

### YESOD基底クラス実装例
```kotlin
// YESODのConnectorGateway継承
class SaaSConnectorGateway(
    context: ContextData,
    connection: Connection,
    authentication: Authentication,
    parameters: Map<String, Any>
) : ConnectorGateway(context, connection, authentication, parameters) {
    override suspend fun listAccounts(): ConnectorResponse<List<AccountResponse>> {
        // YESOD固有の実装
    }
}
```

### YESOD実装チェックリスト
必須実装項目:
- [ ] ConnectorGateway実装
- [ ] YESODドメインモデル変換
- [ ] ContextData, Connection, Authentication対応
- [ ] AccountResponse, AccountExternalId変換
- [ ] ConnectionSubscriber統合

### 非同期処理とジョブ管理（YESOD固有）
PubSubパターンによる非同期実行:

#### ConnectionSubscriber統合
- importAccountsオペレーション実装
- バルク処理対応
- エラーハンドリングとリトライ

#### ジョブ管理
```kotlin
// ConnectionSubscriberでの実装
when (operation) {
    "importAccounts" -> {
        val gateway = createGateway(connection)
        val response = gateway.listAccounts()
        saveAccounts(response.data)
    }
}
```

## SmartHRコネクター実装例
具体的なYESODコネクター実装例として、SmartHRコネクターの設計パターンを参照。

## 関連ファイル
- smarthr-connector-implementation.md: SmartHR固有実装詳細
- ./claude-knowledge/architecture/connection-domain-design.md: YESOD接続ドメイン設計
- ./claude-knowledge/function/implementation/api-client-guidelines.md: 汎用APIクライアント実装

検索キーワード: yesod-connector, smarthr, connector-gateway, connection-subscriber, domain-model, authentication, context-data