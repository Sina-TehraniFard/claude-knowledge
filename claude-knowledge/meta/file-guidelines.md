# ファイル作成ガイドライン

Claude CodeがナレッジファイルをAI最適化するための実用ガイドライン。

## 命名規則

### 必須形式
```
{category}-{function}-{detail}.md
backend-auth-implementation.md
frontend-component-guidelines.md
database-migration-procedure.md
```

### 制約
- 小文字英数字+ハイフン
- 最大50文字

## ファイル構造（全ファイル共通）

### 1. ヘッダー（必須）
```markdown
関連ファイル:
- path/to/related-file.md
- path/to/another-file.md
```

### 2. 内容構造（必須）
```markdown
# タイトル

## 概要
3-5行で要点

## 詳細
### 具体的な実装手順
### 設定例
### コード例

## 実装例
言語指定コードブロック

## 関連事項
他ファイル参照
```

### 3. 検索キーワード（必須）
ファイル末尾に検索用キーワードを列挙
```
検索キーワード: kotlin, spring, authentication, jwt, security
```

## Claude Code読み込みルール

### 必須読み込み条件
以下のキーワードがユーザリクエストに含まれる場合、該当ファイルを自動読み込み:
- "実装" → `/claude-knowledge/function/implementation/`内全ファイル
- "テスト" → `/claude-knowledge/function/testing/`内全ファイル  
- "認証" → `auth-`で始まる全ファイル
- "データベース" → `database-`で始まる全ファイル

## 品質制約

### ファイル内容要件
- **具体的な実装コード**を必ず含む
- **具体的な設定例**を必ず含む
- **具体的な手順**を必ず含む
- 抽象的な説明のみは禁止

### ファイルサイズ
- 最大200行
- 最大行数が足りない場合はファイルを分割する
- 最小50行