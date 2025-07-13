# YESODシステム固有ナレッジ

このディレクトリには、YESODシステムに固有の技術仕様・実装詳細・業務ナレッジを保存します。

## 目的

- **システム固有情報の分離**: 汎用的なClaude設定と明確に分離して管理
- **再利用性の確保**: `.gitignore`で`system-specific/*`を除外することで、他システムでもClaude設定を再利用可能
- **チーム固有知識の蓄積**: プロジェクト特有の実装方針・制約・ノウハウを文書化

## ディレクトリ構成

### client/
APIクライアント・実装に関するYESOD固有の情報
- **general-implementation-guidelines.md**: YESOD固有の実装ガイドライン
- **kotlin-implementation-idiompriority.md**: YESOD Kotlinコーディング規約

### connector-gateway/
ConnectorGateway・SaaS連携に関するYESOD固有の情報
- **gateway-upsertaccount-implementation.md**: Gateway実装パターン
- **yesod-connector-patterns.md**: YESODコネクター開発パターン

## 保存すべき情報

- **YESODアーキテクチャの詳細**: システム設計・構成
- **プロジェクト固有の実装方針**: YESOD特有のルール・制約
- **業務ロジックの仕様**: ドメイン知識・ビジネスルール
- **データモデルの詳細**: YESODのEAVパターン・マルチテナント設計
- **API仕様書**: YESOD固有のAPI設計・エンドポイント
- **デプロイ・運用手順**: 本番環境・ステージング環境の運用
- **トラブルシューティング情報**: YESOD固有の問題・解決策

## 汎用設定との関係

- **汎用設定**: `claude-knowledge/` 直下（architecture/, function/, meta/ など）
- **システム固有**: `claude-knowledge/system-specific/` 配下
- **Claude参照順**: 汎用設定 → システム固有情報

## 他システムでの再利用方法

1. `claude-knowledge/` 全体をコピー
2. `.gitignore`で`system-specific/*`が除外される
3. 新システムの固有情報を`system-specific/`に追加
4. 汎用部分はそのまま利用可能