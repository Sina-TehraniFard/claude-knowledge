関連ファイル:
- testing-junit-guidelines.md
- testing-junit-circular-mocking.md
- testing.md

# テストディレクトリ

## 概要
JUnitテスト実装方針とベストプラクティスの収集ディレクトリ

## 詳細
### テストフレームワーク
- JUnit5: テストフレームワーク
- Kotest: アサーションライブラリ
- MockK: モックライブラリ
- Kotlin Test: Kotlin専用テストユーティリティ

### 必須参照ファイル
1. **testing-junit-guidelines.md**: JUnitテスト実装の統一規約
2. **testing-junit-circular-mocking.md**: 循環モック回避ガイドライン
3. **testing.md**: TDD実践方法とテストクラス構成

### テスト規約のポイント
- Given-When-Then構造の必須遵守
- 英語メソッド名 + 日本語@DisplayNameの併用
- Kotestアサーションの統一使用
- テスト対象クラス自体のモック禁止

## 実装例
### テスト作業フロー
1. テスト実装前にガイドラインを読み込み
2. Given-When-Then構造でテストコード作成
3. コンパイルエラー確認実行
4. テスト実行で品質保証

### コマンド例
```bash
# テスト実行
./gradlew test

# カバレッジレポート生成
./gradlew test jacocoTestReport

# 特定クラスのテスト実行
./gradlew test --tests UserServiceTest
```

## 関連事項
### 関連ディレクトリ
- ./claude-knowledge/function/implementation/: 実装ガイドライン
- ./claude-knowledge/development/: 開発環境・ワークフロー

### 品質保証指標
- テストカバレッジ: 80%以上
- テスト実行時間: 5分以内
- テスト失敗時の即座修正

検索キーワード: junit, testing, kotest, mockk, given-when-then, tdd, circular-mocking, kotlin, test-guidelines, assertion