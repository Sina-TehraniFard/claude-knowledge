# コーディング規約・設計パターンガイド

## 役割と責任範囲
**このディレクトリの対象領域**：
- プログラミング言語固有のコーディング規約（Kotlin、TypeScript、SQL等）
- API設計パターン・アーキテクチャガイドライン
- エラーハンドリング・例外処理の実装方針
- データモデル・ドメインロジック設計パターン
- セキュリティ実装のベストプラクティス
- パフォーマンス最適化の実装手法

**対象外（他ディレクトリの責任範囲）**：
- 開発環境・ツール設定 → `development/`
- テスト実装・戦略 → `function/testing/`
- 外部システム連携仕様 → `integrations/`

## 概要
コード実装時の統一規約・ガイドライン収集ディレクトリ。全実装作業で最優先で参照する必須規約。

## 詳細
### 対象技術スタック
- Kotlin/Spring Boot: バックエンド実装
- Vue3/TypeScript: フロントエンド実装
- PostgreSQL: データベース設計・実装
- JUnit5/Mockito: テスト実装

### 管理対象ファイル例
- **general-implementation-guidelines.md**: 全言語共通の実装規約
- **kotlin-coding-standards.md**: Kotlin固有のコーディング規約
- **typescript-patterns.md**: TypeScript/Vue3の実装パターン
- **api-design-guidelines.md**: REST API設計・実装規約
- **error-handling-patterns.md**: 例外処理・エラーハンドリング手法
- **security-implementation.md**: セキュリティ実装のベストプラクティス
- **database-design-patterns.md**: データモデル・SQL実装規約
- **performance-optimization.md**: パフォーマンス最適化手法

### コーディング・設計パターン例
#### 実装作業フロー
1. 要件分析・設計パターン選択
2. 言語固有のガイドライン確認
3. API設計・データモデル設計
4. 実装・コードレビュー・リファクタリング

#### 品質保証フロー
1. コーディング規約チェック
2. エラーハンドリング実装確認  
3. セキュリティ脆弱性チェック
4. パフォーマンス影響評価

### 品質保証項目
- 日本語ルールの遵守
- エラーハンドリングの適切な実装
- API設計の一貫性
- セキュリティベストプラクティス

## 関連事項
### 関連ディレクトリ
- ./claude-knowledge/function/testing/: テスト実装方針
- ./claude-knowledge/development/: 開発環境・ワークフロー
- ./claude-knowledge/integrations/: SaaS連携・インテグレーション

### アプリケーション領域
- バックエンド実装（Kotlin/Spring Boot）
- フロントエンド実装（Vue3/TypeScript）
- API設計・実装
- データベース設計・実装
- セキュリティ実装

検索キーワード: implementation, guidelines, kotlin, typescript, spring-boot, vue3, coding-standards, japanese-rules, error-handling, api-design