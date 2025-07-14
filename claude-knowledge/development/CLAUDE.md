# 開発環境・ツール・プロセス設定ガイド

## 役割と責任範囲
**このディレクトリの対象領域**：
- 開発環境の構築・設定（Docker、IDE、ツール類）
- 開発プロセス・ワークフロー（Git運用、ブランチ戦略、レビュー）  
- 開発効率化・自動化（CI/CD、スクリプト、ホットリロード）
- トラブルシューティング・デバッグ環境設定

**対象外（他ディレクトリの責任範囲）**：
- コーディング規約・設計パターン → `function/implementation/`
- テスト実装・戦略 → `function/testing/`
- 外部システム連携仕様 → `integrations/`

## 詳細
### 開発環境必須ソフトウェア
- Docker Compose: コンテナオーケストレーション
- Git: バージョン管理
- Gradle: バックエンドビルド
- Node.js: フロントエンドビルド


### 開発原則
- Dockerベース統一環境
- フィーチャーブランチワークフロー
- 必須コードレビュー
- 既存パターン再利用優先

### 環境・プロセス設定例
#### 開発環境構築フロー
1. Docker Compose環境起動
2. 依存サービス確認・設定
3. IDE設定・プラグイン導入
4. ローカル設定ファイル準備

#### ブランチ運用フロー  
1. feature/機能名 でブランチ作成
2. 実装・テスト実行
3. プルリクエスト作成
4. コードレビュー・マージ

### 環境構築フロー
1. Docker Compose起動
2. 依存サービス確認
3. アプリケーション起動

## 関連事項
- ./claude-knowledge/function/implementation/: 実装ガイドライン
- ./claude-knowledge/integrations/: 外部連携仕様

検索キーワード: docker, environment, workflow, feature-branch, code-review, setup, development, debugging, connector